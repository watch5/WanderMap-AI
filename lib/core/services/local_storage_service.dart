import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/places/models/place.dart';

/// SharedPreferences を使ったローカルストレージサービス
class LocalStorageService {
  static const _placesKey = 'saved_places';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 全場所を取得
  Future<List<Place>> getPlaces() async {
    final prefs = await _preferences;
    final jsonString = prefs.getString(_placesKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
    return jsonList
        .map((e) => Place.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 場所を保存（全リストを上書き）
  Future<void> savePlaces(List<Place> places) async {
    final prefs = await _preferences;
    final jsonString = json.encode(places.map((e) => e.toJson()).toList());
    await prefs.setString(_placesKey, jsonString);
  }

  /// 場所を追加
  Future<void> addPlace(Place place) async {
    final places = await getPlaces();
    places.add(place);
    await savePlaces(places);
  }

  /// 場所を更新
  Future<void> updatePlace(Place place) async {
    final places = await getPlaces();
    final index = places.indexWhere((p) => p.id == place.id);
    if (index != -1) {
      places[index] = place;
      await savePlaces(places);
    }
  }

  /// 場所を削除
  Future<void> deletePlace(String id) async {
    final places = await getPlaces();
    places.removeWhere((p) => p.id == id);
    await savePlaces(places);
  }
}
