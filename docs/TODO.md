# SPEC BATTLE — TODO

バージョン: 0.1.0
最終更新: 2026-02-27

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
- **現在の位置づけ**: Phase 4-2 のバックエンド/ロジック部分が完了。次はUI層（QRコード表示・カメラ読み取り画面）の実装へ。

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
- `QrBattleService`: エンコード/デコード、ゲスト敵生成、ディープリンクURL生成/解析
- `IntegrityException`: 不正データ検知用の専用例外クラス
- v1後方互換性を維持（チェックサムなしの旧データもデコード可能）
- ユニットテスト: CharacterCodec 25件 + QrBattleService 14件 = 計39件追加

---

## 🤖 Antigravity側への引き継ぎ事項（Phase 4-2 UI実装）

### 次に実装すべき内容: QR/URL対戦のUI層
以下のUI画面をローカル環境で実装してください。ロジック層は完成済みです。

1. **QRコード表示画面**:
   - `QrBattleService.encodePlayerCharacter()` または `encodeGachaCharacter()` で取得したBase64url文字列を `qr_flutter` でQR化して表示
   - 共有ボタン（URL共有）: `QrBattleService.generateShareUrl()` でディープリンクURLを生成

2. **QRコード読み取り画面**:
   - カメラでQRを読み取り、`QrBattleService.decodeAsGuest()` でゲスト敵を生成
   - `IntegrityException` をキャッチして「不正なデータです」等のエラー表示
   - 成功時は `QrBattleGuest.battleCharacter` を `BattleEngine` に渡してバトル画面へ遷移

3. **ディープリンク受信ハンドラ**:
   - `QrBattleService.extractFromUrl()` でURLからデータ抽出 → デコード → バトル画面へ

### 主要ファイル
- `lib/domain/services/qr_battle_service.dart` — QR対戦サービス（エンコード/デコード/URL処理）
- `lib/domain/services/character_codec.dart` — キャラクターバイナリコーデック（v2チェックサム付き）
- `lib/domain/models/decoded_character.dart` — デコード結果ラッパー

### 依存パッケージ（UI実装時に追加が必要）
- `qr_flutter` — QRコード表示
- `mobile_scanner` 等 — カメラ読み取り

---

## 既知の問題・課題
- **ユニットテスト環境構築エラー**: `flutter test` 実行時に `objective_c` パッケージのネイティブビルドが失敗する（Xcode Command Line Tools のアーキテクチャ不一致問題）。
  - ※テストコード自体は `flutter analyze` を問題なく通過しているため、ローカルマシンの環境設定起因の保留事項。
  - ※この問題を回避するため、今回Linux環境としてDockerコンテナ構成を用意しました。ローカルにDockerがインストールされている環境であれば、`docker compose exec flutter-dev flutter test` でクリーンにテスト検証を実行可能です。
