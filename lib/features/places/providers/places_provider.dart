import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_storage_service.dart';
import '../models/place.dart';

/// LocalStorageService のプロバイダー
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

/// 場所リストの状態管理
final placesProvider =
    AsyncNotifierProvider<PlacesNotifier, List<Place>>(PlacesNotifier.new);

class PlacesNotifier extends AsyncNotifier<List<Place>> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  Future<List<Place>> build() async {
    return _storage.getPlaces();
  }

  /// 場所を追加
  Future<void> addPlace(Place place) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _storage.addPlace(place);
      return _storage.getPlaces();
    });
  }

  /// 場所を更新
  Future<void> updatePlace(Place place) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _storage.updatePlace(place);
      return _storage.getPlaces();
    });
  }

  /// 場所を削除
  Future<void> deletePlace(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _storage.deletePlace(id);
      return _storage.getPlaces();
    });
  }
}

/// 訪問済みの場所だけを取得するプロバイダー
final visitedPlacesProvider = Provider<AsyncValue<List<Place>>>((ref) {
  return ref.watch(placesProvider).whenData(
        (places) => places.where((p) => p.visited).toList(),
      );
});

/// 行きたい場所だけを取得するプロバイダー
final wantToGoPlacesProvider = Provider<AsyncValue<List<Place>>>((ref) {
  return ref.watch(placesProvider).whenData(
        (places) => places.where((p) => !p.visited).toList(),
      );
});
