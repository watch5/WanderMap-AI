import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/location_service.dart';

/// LocationService のプロバイダー
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// 現在地を取得する FutureProvider
final currentLocationProvider = FutureProvider<Position>((ref) async {
  final service = ref.read(locationServiceProvider);
  return service.getCurrentPosition();
});
