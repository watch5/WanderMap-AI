import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/gemini_service.dart';
import '../../map/providers/location_provider.dart';
import '../../places/providers/places_provider.dart';

/// GeminiService のプロバイダー
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

/// AI 提案の状態
final aiSuggestionProvider =
    AsyncNotifierProvider<AiSuggestionNotifier, String?>(
  AiSuggestionNotifier.new,
);

class AiSuggestionNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  /// AI に提案を依頼する
  Future<void> fetchSuggestions() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final gemini = ref.read(geminiServiceProvider);

      // 訪問済みの場所を取得
      final placesState = ref.read(placesProvider);
      final allPlaces = placesState.valueOrNull ?? [];
      final visitedPlaces = allPlaces.where((p) => p.visited).toList();

      // 現在地を取得（失敗時はデフォルト位置を使用）
      double lat = AppConstants.defaultLat;
      double lng = AppConstants.defaultLng;

      try {
        final location = await ref.read(currentLocationProvider.future);
        lat = location.latitude;
        lng = location.longitude;
      } catch (_) {
        // デフォルト位置を使用
      }

      return gemini.suggestNextPlaces(
        visitedPlaces: visitedPlaces,
        currentLat: lat,
        currentLng: lng,
      );
    });
  }
}
