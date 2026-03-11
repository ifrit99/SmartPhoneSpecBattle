# SPEC BATTLE — TODO

バージョン: 0.1.0
最終更新: 2026-03-10

---

## 状態サマリー
- **完了済み**:
  - Phase 1 MVP (ドメインモデル、各種画面UI、バトルエンジン本実装)
  - Phase 2 (各種UX演出：ダメージポップアップ、クリティカル、バッテリー連携によるSPD補正、効果音)
  - Phase 3-1 (CPU敵キャラ自動生成: `enemy_generator.dart`)
  - Phase 3-2 (キャラクター図鑑・対戦履歴: `CollectionScreen`)
  - Phase 3-3 (タイトル画面: `title_screen.dart`)
  - セキュリティ強化・環境分離のためのDocker開発環境（Dockerfile, docker-compose.yml等）の構築
  - 重大なバグ修正、及びユニットテスト群の追加
  - Phase 4-1 エミュレートガチャ（ガチャロジック・UI・ブラウザテスト）
  - Phase 4-2 QR/URL対戦 ロジック層（チェックサム検証・QrBattleService・テスト）
  - **Phase 4-2 Web MVP対応**（QR→URL共有専用に改修、`flutter build web` 通過）
- **現在の位置づけ**: **Web版MVPリリースに向けて作業中**。ブラウザ結合テスト → デプロイが残タスク。

---

## Web MVP 残タスク

### ✅ 完了: ビルド基盤 + UI改修（`feature/web-mvp` ブランチ）

| 項目 | 状態 |
|------|------|
| `flutter build web` 通過 | ✅ |
| `flutter analyze` エラー0 | ✅ |
| `flutter test` 全140件パス | ✅ |
| QRスキャン画面 → URL入力画面（`UrlInputScreen`）に改修 | ✅ |
| QR表示画面 → URL共有画面（`ShareScreen`）に改修 | ✅ |
| QRメニュー → フレンド対戦メニュー（`FriendBattleMenuScreen`）に改修 | ✅ |
| ゲストプレビュー画面の `UnimplementedError` 解消 | ✅ |
| `main.dart` で `Uri.base` パースによるURL起動対戦対応 | ✅ |
| `ServiceLocator` に `qrBattleService` 登録 | ✅ |
| ホーム画面に「Friend」ボタン追加 | ✅ |
| 不要パッケージ除去（`qr_flutter`, `mobile_scanner`, `share_plus`, `app_links`） | ✅ |

### 🔶 進行中: ブラウザ結合テスト

- [ ] `flutter run -d chrome` で全画面フローを確認
  - タイトル → ホーム → Friend → URLシェア → URL入力 → プレビュー → バトル
  - `?battle=<encoded>` 付きURLで直接開いて対戦遷移するか確認
- [ ] audioplayers のWeb動作確認（BGM・SE再生）
- [ ] バグ修正（発見次第対応）

### 🔲 未着手: デプロイ

- [ ] GitHub Pages または Firebase Hosting にデプロイ
- [ ] `QrBattleService.baseUrl` にデプロイ先URLを設定
- [ ] OGPメタタグ・favicon設定（SNS共有時のプレビュー表示用）
- [ ] 最終動作確認

---

## 方針変更の経緯

Android版MVPリリースを目指していたが、以下の理由でWeb版に方針転換:
- MacBookのディスク容量不足で `flutter build appbundle --release` が困難
- VPS（960MB RAM）ではGradle/Kotlinビルドがメモリ不足で不可
- Android実機の確保が困難

**除外したタスク**:
- QRコードカメラ読み取り（`mobile_scanner` — Web非対応）
- QRコード画像表示（`qr_flutter` — URLコピー/共有で代替）
- Androidリリースビルド・Play Store公開
- Deep Link対応（`app_links` — MVP後に検討）

---

## ~~Phase 3 後半~~ ✅ 全完了

### ~~1. キャラクター図鑑・対戦履歴 (Phase 3-2)~~ ✅ 完了
- `CollectionScreen` の実装
- 過去に遭遇・撃破した架空の端末（敵キャラクター）のリスト表示
- `shared_preferences` で対戦成績（勝利数・遭遇リスト等）をデータ永続化

### ~~2. タイトル画面の追加 (Phase 3-3)~~ ✅ 完了
- `title_screen.dart` を新設し、アプリ起動時の演出を強化。

---

## ~~Phase 4~~ 進行中

### ~~1. エミュレートガチャ（仮想スペック生成システム）~~ ✅ 完了
- ゲーム内通貨を用いてランダムなスペックキャラを生成するガチャ機能。

### ~~2. QR/URLフレンドスキャン対戦 (Phase 4-2) — ロジック層~~ ✅ 完了
- `CharacterCodec` v2: HMAC-SHA256ベースの4バイトチェックサム付与による改ざん検知
- `QrBattleService`: エンコード/デコード、ゲスト敵生成、Web共有URL生成
- `IntegrityException`: 不正データ検知用の専用例外クラス
- v1後方互換性を維持（チェックサムなしの旧データもデコード可能）
- ユニットテスト: CharacterCodec 25件 + QrBattleService 12件 = 計37件

### ~~3. Phase 4-2 UI層 — Web MVP対応~~ ✅ 完了
- QR系4画面をURL共有専用に改修（カメラ/QR表示を除去）
- `main.dart` で `Uri.base` パースによるURL起動対戦対応（`kIsWeb`）
- `web/index.html`, `web/manifest.json` 追加

---

## 主要ファイル一覧

### ロジック層
- `lib/domain/services/qr_battle_service.dart` — URL対戦サービス（エンコード/デコード/URL生成）
- `lib/domain/services/character_codec.dart` — キャラクターバイナリコーデック（v2チェックサム付き）
- `lib/domain/models/decoded_character.dart` — デコード結果ラッパー

### UI層（Web MVP）
- `lib/presentation/screens/qr_menu_screen.dart` — フレンド対戦メニュー（`FriendBattleMenuScreen`）
- `lib/presentation/screens/qr_display_screen.dart` — URL共有画面（`ShareScreen`）
- `lib/presentation/screens/qr_scan_screen.dart` — URL入力画面（`UrlInputScreen`）
- `lib/presentation/screens/qr_guest_preview_screen.dart` — ゲストプレビュー画面

---

## 既知の問題・課題
- **ユニットテスト環境構築エラー（Mac）**: `flutter test` 実行時に `objective_c` パッケージのネイティブビルドが失敗する場合がある（Xcode Command Line Tools のアーキテクチャ不一致問題）。Docker環境では問題なし。
