import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// カスタムマーカーを生成するユーティリティ
class MarkerHelper {
  MarkerHelper._();

  /// 「行きたい」マーカーの色（赤系）
  static const wantToGoHue = BitmapDescriptor.hueRed;

  /// 「訪問済み」マーカーの色（緑系）
  static const visitedHue = BitmapDescriptor.hueGreen;

  /// マーカーアイコンを取得する
  static BitmapDescriptor getMarkerIcon({required bool visited}) {
    return BitmapDescriptor.defaultMarkerWithHue(
      visited ? visitedHue : wantToGoHue,
    );
  }

  /// カスタム描画マーカーを生成（アイコン付き）
  static Future<BitmapDescriptor> createCustomMarker({
    required bool visited,
    required double devicePixelRatio,
  }) async {
    const size = 120.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final bgColor = visited
        ? const Color(0xFF2E7D32) // 緑
        : const Color(0xFFC62828); // 赤

    // 円形背景
    final bgPaint = Paint()..color = bgColor;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      bgPaint,
    );

    // 白い枠
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 2,
      borderPaint,
    );

    // アイコン描画
    final icon = visited ? Icons.check : Icons.favorite;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 56,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return getMarkerIcon(visited: visited);
    }

    return BitmapDescriptor.bytes(byteData.buffer.asUint8List());
  }
}
