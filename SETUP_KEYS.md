# WanderMap AI — API キー設定ガイド

このアプリを動作させるには **Google Maps API キー** と **Gemini API キー** の2つが必要です。

---

## 1. Google Maps API キーの取得

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. プロジェクトを作成または選択
3. 「APIとサービス」→「ライブラリ」から以下を有効化:
   - **Maps SDK for Android**
   - **Maps SDK for iOS**
4. 「APIとサービス」→「認証情報」→「認証情報を作成」→「APIキー」
5. 作成されたキーをコピー

## 2. Gemini API キーの取得

1. [Google AI Studio](https://aistudio.google.com/app/apikey) にアクセス
2. 「Create API key」でキーを作成
3. 作成されたキーをコピー

---

## 3. キーの設定（3箇所）

### A. `.env`（Dart側 — Gemini + 共通）

プロジェクトルートの `.env` ファイルを編集:

```
GEMINI_API_KEY=ここにGemini APIキーを貼り付け
GOOGLE_MAPS_API_KEY=ここにGoogle Maps APIキーを貼り付け
```

### B. `android/local.properties`（Android側 — Google Maps）

`android/local.properties` ファイルに以下の行を追加:

```properties
MAPS_API_KEY=ここにGoogle Maps APIキーを貼り付け
```

> ※ `sdk.dir` や `flutter.sdk` の行はそのまま残してください。

### C. `ios/Flutter/Keys.xcconfig`（iOS側 — Google Maps）

`ios/Flutter/Keys.xcconfig` ファイルを編集:

```
MAPS_API_KEY=ここにGoogle Maps APIキーを貼り付け
```

---

## 4. 確認

設定後、以下のコマンドでアプリを起動:

```bash
flutter run
```

地図が正しく表示され、AI コンシェルジュが応答すれば設定完了です。

---

## セキュリティに関する注意

- `.env`、`android/local.properties`、`ios/Flutter/Keys.xcconfig` は `.gitignore` に登録済みです。**Git にコミットされません。**
- API キーを公開リポジトリにプッシュしないよう注意してください。
- 本番運用ではキーにアプリ制限（パッケージ名・バンドルID）を設定することを推奨します。
