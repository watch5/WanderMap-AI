import 'package:geolocator/geolocator.dart';

/// 位置情報サービス
class LocationService {
  /// 位置情報の権限を確認し、現在地を取得する
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('位置情報サービスが無効です。設定から有効にしてください。');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('位置情報の権限が拒否されました。');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('位置情報の権限が永続的に拒否されています。設定から許可してください。');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }
}
