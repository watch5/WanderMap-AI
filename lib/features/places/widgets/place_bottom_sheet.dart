import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/services/gemini_service.dart';
import '../../places/models/place.dart';
import '../../places/providers/places_provider.dart';

/// 場所の追加・編集用ボトムシート
class PlaceBottomSheet extends ConsumerStatefulWidget {
  const PlaceBottomSheet({
    super.key,
    required this.latitude,
    required this.longitude,
    this.existingPlace,
  });

  final double latitude;
  final double longitude;
  final Place? existingPlace;

  @override
  ConsumerState<PlaceBottomSheet> createState() => _PlaceBottomSheetState();
}

class _PlaceBottomSheetState extends ConsumerState<PlaceBottomSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late bool _visited;
  late int _rating;
  late List<String> _aiTags;
  File? _selectedImage;
  bool _saving = false;
  bool _analyzingPhoto = false;

  bool get _isEditing => widget.existingPlace != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingPlace;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _visited = existing?.visited ?? false;
    _rating = existing?.rating ?? 0;
    _aiTags = List<String>.from(existing?.aiTags ?? []);
    if (existing?.imagePath != null) {
      final f = File(existing!.imagePath!);
      if (f.existsSync()) _selectedImage = f;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  // ドラッグハンドル
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // タイトル
                  Text(
                    _isEditing ? 'スポットを編集' : '新しいスポット',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '緯度: ${widget.latitude.toStringAsFixed(5)}, '
                    '経度: ${widget.longitude.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 写真エリア
                  _buildImagePicker(theme),
                  const SizedBox(height: 16),

                  // AIタグ
                  if (_aiTags.isNotEmpty) ...[
                    _buildAiTags(theme),
                    const SizedBox(height: 16),
                  ],

                  // タイトル入力
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'スポット名',
                      hintText: '例: お気に入りのカフェ',
                      prefixIcon: Icon(Icons.place),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // メモ入力
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'メモ',
                      hintText: '例: 静かで落ち着いた雰囲気',
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 20),

                  // 訪問済み / 行きたいトグル
                  _buildVisitedToggle(theme),
                  const SizedBox(height: 16),

                  // 評価（訪問済みの場合のみ）
                  if (_visited) ...[
                    _buildRatingSelector(theme),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 8),

                  // アクションボタン
                  Row(
                    children: [
                      if (_isEditing)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _deletePlace,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('削除'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      if (_isEditing) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _savePlace,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(_isEditing ? Icons.save : Icons.add),
                          label: Text(_isEditing ? '更新' : '追加'),
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── 写真ピッカー ────────────────────────

  Widget _buildImagePicker(ThemeData theme) {
    return GestureDetector(
      onTap: _analyzingPhoto ? null : _pickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 180,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 1.5,
          ),
          image: _selectedImage != null
              ? DecorationImage(
                  image: FileImage(_selectedImage!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _analyzingPhoto
            ? _buildAnalyzingOverlay(theme)
            : _selectedImage == null
                ? _buildEmptyImagePlaceholder(theme)
                : _buildImageOverlay(theme),
      ),
    );
  }

  Widget _buildEmptyImagePlaceholder(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_a_photo_outlined,
          size: 40,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 8),
        Text(
          '写真を追加',
          style: theme.textTheme.bodyMedium?.copyWith(
            color:
                theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'AIが自動でタグとメモを提案します',
          style: theme.textTheme.bodySmall?.copyWith(
            color:
                theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildImageOverlay(ThemeData theme) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          radius: 18,
          backgroundColor:
              theme.colorScheme.surface.withValues(alpha: 0.85),
          child: Icon(
            Icons.edit,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzingOverlay(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: theme.colorScheme.inversePrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'AI が写真を分析中...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── AIタグ ────────────────────────────

  Widget _buildAiTags(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome,
                size: 16, color: theme.colorScheme.tertiary),
            const SizedBox(width: 6),
            Text(
              'AI タグ',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _aiTags.map((tag) {
            return Chip(
              label: Text(tag),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              backgroundColor:
                  theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
              labelStyle: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
              side: BorderSide.none,
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () {
                setState(() => _aiTags.remove(tag));
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── 画像選択＋AI分析 ──────────────────────

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('カメラで撮影'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('ギャラリーから選択'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      // アプリのドキュメントディレクトリに保存
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          'place_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
      final savedFile = await File(picked.path).copy(
        p.join(appDir.path, fileName),
      );

      setState(() => _selectedImage = savedFile);

      // AIで写真を分析
      await _analyzePhoto(savedFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('写真の選択に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _analyzePhoto(File imageFile) async {
    setState(() => _analyzingPhoto = true);

    try {
      final gemini = GeminiService();
      final analysis = await gemini.analyzePlacePhoto(imageFile);

      if (!mounted) return;

      setState(() {
        if (analysis.tags.isNotEmpty) {
          _aiTags = analysis.tags;
        }
        if (analysis.note.isNotEmpty && _notesController.text.isEmpty) {
          _notesController.text = analysis.note;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI分析に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _analyzingPhoto = false);
    }
  }

  // ── 訪問済み/行きたい ──────────────────────

  Widget _buildVisitedToggle(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleOption(
              label: '行きたい',
              icon: Icons.favorite,
              selected: !_visited,
              color: const Color(0xFFC62828),
              onTap: () => setState(() => _visited = false),
            ),
          ),
          Expanded(
            child: _ToggleOption(
              label: '訪問済み',
              icon: Icons.check_circle,
              selected: _visited,
              color: const Color(0xFF2E7D32),
              onTap: () => setState(() => _visited = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('評価', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            return IconButton(
              onPressed: () => setState(() => _rating = starIndex),
              icon: Icon(
                starIndex <= _rating ? Icons.star : Icons.star_border,
                color: starIndex <= _rating
                    ? Colors.amber
                    : theme.colorScheme.onSurfaceVariant,
                size: 32,
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── 保存 / 削除 ────────────────────────

  Future<void> _savePlace() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('スポット名を入力してください')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final notifier = ref.read(placesProvider.notifier);

      if (_isEditing) {
        final updated = widget.existingPlace!.copyWith(
          title: title,
          notes: _notesController.text.trim(),
          visited: _visited,
          rating: _visited ? _rating : 0,
          imagePath: _selectedImage?.path,
          aiTags: _aiTags,
        );
        await notifier.updatePlace(updated);
      } else {
        final newPlace = Place(
          title: title,
          latitude: widget.latitude,
          longitude: widget.longitude,
          notes: _notesController.text.trim(),
          visited: _visited,
          rating: _visited ? _rating : 0,
          imagePath: _selectedImage?.path,
          aiTags: _aiTags,
        );
        await notifier.addPlace(newPlace);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deletePlace() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('スポットを削除'),
        content: const Text('このスポットを削除しますか？この操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(placesProvider.notifier)
          .deletePlace(widget.existingPlace!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// トグルオプション（行きたい / 訪問済み）
class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
