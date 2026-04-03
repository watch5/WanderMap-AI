import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../features/places/models/place.dart';

/// Gemini API との通信サービス
class GeminiService {
  GenerativeModel? _model;

  GenerativeModel get _gemini {
    if (_model != null) return _model!;

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_gemini_api_key_here') {
      throw Exception('GEMINI_API_KEY が .env に設定されていません。');
    }

    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.8,
        maxOutputTokens: 1024,
      ),
    );
    return _model!;
  }

  /// 訪問済みの場所とユーザーの現在地を基に、次に行くべき場所を提案する
  Future<String> suggestNextPlaces({
    required List<Place> visitedPlaces,
    required double currentLat,
    required double currentLng,
  }) async {
    if (visitedPlaces.isEmpty) {
      return 'まだ訪問済みの場所がありません。場所を追加して「訪問済み」にマークすると、AIがおすすめを提案します！';
    }

    final placesDescription = visitedPlaces.map((p) {
      final ratingStr = p.rating > 0 ? '（評価: ${p.rating}/5）' : '';
      final notesStr = p.notes.isNotEmpty ? 'メモ: ${p.notes}' : '';
      return '- ${p.title}$ratingStr $notesStr';
    }).join('\n');

    final prompt = '''
あなたは地元を熟知した旅行コンシェルジュです。
ユーザーが過去に訪れた場所の情報を基に、次に訪れるべきおすすめの場所を2〜3件提案してください。

【ユーザーの訪問履歴】
$placesDescription

【ユーザーの現在位置】
緯度: $currentLat, 経度: $currentLng

【指示】
- ユーザーの好みや傾向を分析してください（例：静かなカフェが好き、自然が好き等）。
- 現在位置の近くで、ユーザーの好みに合いそうな場所のカテゴリや種類を2〜3件提案してください。
- 各提案には、なぜおすすめするのか簡潔な理由を添えてください。
- 回答は日本語で、親しみやすいトーンで書いてください。
- マークダウン形式は使わず、プレーンテキストで回答してください。
''';

    try {
      final response = await _gemini.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null || text.isEmpty) {
        return 'AIからの応答が空でした。しばらくしてからもう一度お試しください。';
      }
      return text;
    } on GenerativeAIException catch (e) {
      throw Exception('AI エラー: ${e.message}');
    } catch (e) {
      throw Exception('ネットワークエラーが発生しました: $e');
    }
  }

  /// 写真を分析してタグとメモを自動生成する
  Future<PlacePhotoAnalysis> analyzePlacePhoto(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final mimeType = imageFile.path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    const prompt = '''
あなたは食べ物と旅行の専門家です。この写真を分析してください。

【指示】
以下の JSON 形式のみで回答してください。それ以外のテキストは不要です。
{
  "tags": ["#タグ1", "#タグ2", "#タグ3"],
  "note": "この場所/食べ物について魅力的な1文の説明"
}

- tags: 写真に写っている場所や食べ物を表すタグを3つ（例: #カフェ, #ラーメン, #海辺, #おしゃれ）
- note: 写真から感じ取れる魅力を簡潔に表現した1文（日本語、30文字程度）
''';

    try {
      final response = await _gemini.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, bytes),
        ]),
      ]).timeout(const Duration(seconds: 30));

      final text = response.text;
      if (text == null || text.isEmpty) {
        return PlacePhotoAnalysis.empty();
      }

      return PlacePhotoAnalysis.fromResponseText(text);
    } on GenerativeAIException catch (e) {
      throw Exception('AI 画像分析エラー: ${e.message}');
    } catch (e) {
      throw Exception('画像分析に失敗しました: $e');
    }
  }
}

/// 写真分析の結果
class PlacePhotoAnalysis {
  const PlacePhotoAnalysis({required this.tags, required this.note});

  final List<String> tags;
  final String note;

  factory PlacePhotoAnalysis.empty() {
    return const PlacePhotoAnalysis(tags: [], note: '');
  }

  factory PlacePhotoAnalysis.fromResponseText(String text) {
    try {
      // JSON 部分を抽出（余分なテキストが付く場合への対応）
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch == null) return PlacePhotoAnalysis.empty();

      final Map<String, dynamic> parsed =
          json.decode(jsonMatch.group(0)!) as Map<String, dynamic>;

      final tags = (parsed['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final note = parsed['note'] as String? ?? '';

      return PlacePhotoAnalysis(tags: tags, note: note);
    } catch (_) {
      return PlacePhotoAnalysis(tags: [], note: text.trim());
    }
  }
}
