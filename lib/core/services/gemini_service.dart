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

  /// 訪問済みの場所とユーザーの現在地を基に、次に行くべきグルメスポットを提案する
  Future<String> suggestNextPlaces({
    required List<Place> visitedPlaces,
    required double currentLat,
    required double currentLng,
  }) async {
    if (visitedPlaces.isEmpty) {
      return 'まだ訪問済みのお店がありません。お店を追加して「訪問済み」にマークすると、AIがあなたの味覚に合ったおすすめを提案します！';
    }

    final placesDescription = visitedPlaces.map((p) {
      final ratingStr = p.rating > 0 ? '（評価: ${p.rating.toStringAsFixed(1)}/5.0）' : '';
      final genreStr = p.genre != null ? '[${p.genre}]' : '';
      final priceStr = p.priceRange != null ? p.priceRange!.symbol : '';
      final notesStr = p.notes.isNotEmpty ? 'メモ: ${p.notes}' : '';
      return '- $genreStr ${p.title}$ratingStr $priceStr $notesStr';
    }).join('\n');

    final prompt = '''
あなたはミシュラン級の味覚を持つグルメAIコンシェルジュです。
ユーザーの食の好みを深く分析し、次に訪れるべきグルメスポットを提案してください。

【ユーザーの飲食履歴】
$placesDescription

【ユーザーの現在位置】
緯度: $currentLat, 経度: $currentLng

【指示】
- ユーザーの味の好みや傾向を分析してください（例：辛いもの好き、和食中心、コスパ重視など）。
- 現在位置の近くで、ユーザーの味覚に合いそうなお店のジャンルや料理を2〜3件提案してください。
- 各提案には以下を含めてください：
  ・おすすめの料理ジャンルまたは具体的な料理名
  ・なぜその料理がユーザーに合うのか、食の好みに基づく理由
  ・予想価格帯
- 食通ならではの視点で、ありきたりでない提案を心がけてください。
- 回答は日本語で、グルメ通の友人のような親しみやすいトーンで書いてください。
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

  /// 料理写真を分析してタグ・メモ・ジャンルを自動生成する
  Future<PlacePhotoAnalysis> analyzePlacePhoto(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final mimeType = imageFile.path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    const prompt = '''
あなたは一流のフードライター兼料理評論家です。この写真を分析してください。

【指示】
以下の JSON 形式のみで回答してください。それ以外のテキストは不要です。
{
  "tags": ["#タグ1", "#タグ2", "#タグ3"],
  "note": "この料理/お店について食欲をそそる1文の説明",
  "genre": "ジャンル名"
}

- tags: 写真に写っている料理やお店の特徴を表すタグを3〜5つ（例: #つけ麺, #濃厚スープ, #自家製麺, #大盛り）
- note: 写真から感じ取れる美味しさの魅力を簡潔に表現した1文（日本語、40文字程度、食欲をそそる表現で）
- genre: 以下のジャンルから最も近いものを1つ選んでください：カフェ, ラーメン, 寿司, 焼肉, イタリアン, フレンチ, 中華, 和食, カレー, パン屋, スイーツ, 居酒屋, バー, ファストフード, その他

料理や食べ物の写真でない場合は、genre を "その他" にしてください。
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
  const PlacePhotoAnalysis({
    required this.tags,
    required this.note,
    this.genre,
  });

  final List<String> tags;
  final String note;
  final String? genre;

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
      final genre = parsed['genre'] as String?;

      return PlacePhotoAnalysis(tags: tags, note: note, genre: genre);
    } catch (_) {
      return PlacePhotoAnalysis(tags: [], note: text.trim());
    }
  }
}
