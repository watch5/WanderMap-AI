import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 価格帯
enum PriceRange {
  low('\$', '¥〜1,000'),
  medium('\$\$', '¥1,000〜3,000'),
  high('\$\$\$', '¥3,000〜'),
  premium('\$\$\$\$', '¥10,000〜');

  const PriceRange(this.symbol, this.label);
  final String symbol;
  final String label;

  static PriceRange? fromString(String? value) {
    if (value == null) return null;
    return PriceRange.values.cast<PriceRange?>().firstWhere(
          (e) => e!.name == value,
          orElse: () => null,
        );
  }
}

/// グルメジャンルの定義
class FoodGenre {
  FoodGenre._();

  static const List<String> presets = [
    'カフェ',
    'ラーメン',
    '寿司',
    '焼肉',
    'イタリアン',
    'フレンチ',
    '中華',
    '和食',
    'カレー',
    'パン屋',
    'スイーツ',
    '居酒屋',
    'バー',
    'ファストフード',
    'その他',
  ];
}

/// グルメスポットのデータモデル
class Place {
  Place({
    String? id,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.notes = '',
    this.visited = false,
    this.rating = 0.0,
    this.priceRange,
    this.genre,
    this.imagePath,
    this.aiTags = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final double latitude;
  final double longitude;
  final String notes;
  final bool visited;
  final double rating; // 0.0-5.0
  final PriceRange? priceRange;
  final String? genre;
  final String? imagePath;
  final List<String> aiTags;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// コピー用ファクトリ
  Place copyWith({
    String? title,
    double? latitude,
    double? longitude,
    String? notes,
    bool? visited,
    double? rating,
    PriceRange? priceRange,
    bool clearPriceRange = false,
    String? genre,
    bool clearGenre = false,
    String? imagePath,
    bool clearImage = false,
    List<String>? aiTags,
    DateTime? updatedAt,
  }) {
    return Place(
      id: id,
      title: title ?? this.title,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      visited: visited ?? this.visited,
      rating: rating ?? this.rating,
      priceRange: clearPriceRange ? null : (priceRange ?? this.priceRange),
      genre: clearGenre ? null : (genre ?? this.genre),
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      aiTags: aiTags ?? this.aiTags,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// JSON からの変換（後方互換: 旧 int rating も対応）
  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String,
      title: json['title'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      notes: json['notes'] as String? ?? '',
      visited: json['visited'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      priceRange: PriceRange.fromString(json['priceRange'] as String?),
      genre: json['genre'] as String?,
      imagePath: json['imagePath'] as String?,
      aiTags: (json['aiTags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// JSON への変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'visited': visited,
      'rating': rating,
      'priceRange': priceRange?.name,
      'genre': genre,
      'imagePath': imagePath,
      'aiTags': aiTags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Place && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
