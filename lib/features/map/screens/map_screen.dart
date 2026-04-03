import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../ai_concierge/widgets/ai_concierge_sheet.dart';
import '../../places/models/place.dart';
import '../../places/providers/places_provider.dart';
import '../../places/widgets/place_bottom_sheet.dart';
import '../providers/location_provider.dart';
import '../widgets/marker_helper.dart';

/// メインのマップ画面
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;

  static const _defaultPosition = LatLng(
    AppConstants.defaultLat,
    AppConstants.defaultLng,
  );

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Set<Marker> _buildMarkers(List<Place> places) {
    return places.map((place) {
      final snippet = place.visited
          ? '${place.genre ?? '訪問済み'}${place.rating > 0 ? ' ★${place.rating.toStringAsFixed(1)}' : ''}'
          : '行きたい${place.genre != null ? ' (${place.genre})' : ''}';
      return Marker(
        markerId: MarkerId(place.id),
        position: LatLng(place.latitude, place.longitude),
        icon: MarkerHelper.getMarkerIcon(
          visited: place.visited,
          genre: place.genre,
        ),
        infoWindow: InfoWindow(
          title: place.title,
          snippet: snippet,
        ),
        onTap: () => _onMarkerTapped(place),
      );
    }).toSet();
  }

  /// マーカータップ時: シートの高さ分だけ上にオフセットしてカメラ移動→シート表示
  Future<void> _onMarkerTapped(Place place) async {
    final screenHeight = MediaQuery.of(context).size.height;
    // ボトムシートが画面の ~35% を占めるので、マーカーを上方に見せるオフセット
    final offsetY = screenHeight * 0.15;

    final target = LatLng(place.latitude, place.longitude);
    final screenCoord = await _mapController?.getScreenCoordinate(target);

    if (screenCoord != null && _mapController != null) {
      final adjustedCoord = ScreenCoordinate(
        x: screenCoord.x,
        y: (screenCoord.y + offsetY).round(),
      );
      final newTarget = await _mapController!.getLatLng(adjustedCoord);
      await _mapController!.animateCamera(
        CameraUpdate.newLatLng(newTarget),
      );
    }

    if (!mounted) return;
    await _showPlaceSheet(place: place);
  }

  Future<void> _showPlaceSheet({
    Place? place,
    double? latitude,
    double? longitude,
  }) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => PlaceBottomSheet(
        latitude: place?.latitude ?? latitude ?? _defaultPosition.latitude,
        longitude:
            place?.longitude ?? longitude ?? _defaultPosition.longitude,
        existingPlace: place,
      ),
    );
  }

  void _showAiConcierge() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AiConciergeSheet(),
    );
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final position = await ref.read(currentLocationProvider.future);
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: AppConstants.defaultZoom,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('位置情報を取得できませんでした: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(currentLocationProvider);
    final placesAsync = ref.watch(placesProvider);
    final theme = Theme.of(context);

    final markers = placesAsync.whenOrNull(
          data: (places) => _buildMarkers(places),
        ) ??
        <Marker>{};

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // フルスクリーン Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: locationAsync.whenOrNull(
                    data: (pos) => LatLng(pos.latitude, pos.longitude),
                  ) ??
                  _defaultPosition,
              zoom: AppConstants.defaultZoom,
            ),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            padding: EdgeInsets.zero,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onLongPress: (latLng) {
              _showPlaceSheet(
                latitude: latLng.latitude,
                longitude: latLng.longitude,
              );
            },
          ),

          // SafeArea 対応のオーバーレイ UI
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildHeader(theme),
                  const Spacer(),
                  _buildActionButtons(theme),
                ],
              ),
            ),
          ),

          // ローディング表示
          if (placesAsync.isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 0,
              right: 0,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('読み込み中...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.explore, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              AppConstants.appName,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            ref.watch(placesProvider).whenOrNull(
                      data: (places) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${places.length} スポット',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color:
                                theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ) ??
                const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AI コンシェルジュ
        FloatingActionButton(
          heroTag: 'ai',
          onPressed: _showAiConcierge,
          backgroundColor: theme.colorScheme.tertiaryContainer,
          foregroundColor: theme.colorScheme.onTertiaryContainer,
          child: const Icon(Icons.auto_awesome),
        ),
        const SizedBox(height: 12),
        // 現在地
        FloatingActionButton.small(
          heroTag: 'location',
          onPressed: _goToCurrentLocation,
          child: const Icon(Icons.my_location),
        ),
        const SizedBox(height: 12),
        // 場所追加
        FloatingActionButton(
          heroTag: 'add',
          onPressed: () async {
            final center = await _mapController?.getLatLng(
              ScreenCoordinate(
                x: (MediaQuery.of(context).size.width / 2).round(),
                y: (MediaQuery.of(context).size.height / 2).round(),
              ),
            );
            if (center != null) {
              _showPlaceSheet(
                latitude: center.latitude,
                longitude: center.longitude,
              );
            }
          },
          child: const Icon(Icons.add_location_alt),
        ),
      ],
    );
  }
}
