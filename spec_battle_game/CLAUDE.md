# SmartPhoneSpecBattle - CLAUDE.md

## プロジェクト概要
スマートフォンのデバイススペック（OSバージョン、メモリ、ストレージ、バッテリー残量など）を解析し、その情報に基づいて世界に1体だけのキャラクターを生成して戦わせる、Flutter製の対戦RPGゲーム。

## 技術スタック
- **Framework**: Flutter (Dart)
- **State Management**: `setState` + `AnimatedBuilder` (シンプル構成)
- **Local Storage**: `shared_preferences`
- **Device Info**: `device_info_plus` (Native / Web差分吸収あり), `package_info_plus`, `battery_plus`

## ディレクトリ構造
- `lib/data/`: データ取得層 (デバイス情報取得API, ローカルストレージ管理など)
- `lib/domain/`: ドメインモデルとロジック (キャラクター、スキルステータス効果モデル、各種列挙型、バトルエンジン)
- `lib/presentation/`: UI層 (画面Screen群、カスタムWidget群)

## よく使うコマンド
- 依存関係のインストール: `flutter pub get`
- アプリの実行: `flutter run`
- コードの静的解析: `flutter analyze`
- テストの実行: `flutter test`

## コーディング規約
- ファイル名・ディレクトリ名: スネークケース (例: `device_info_service.dart`)
- クラス名: パスカルケース (例: `DeviceInfoService`)
- 変数名・メソッド名: キャメルケース
- アーキテクチャ構成: `data`, `domain`, `presentation` の3層レイヤー構造を採用。
- コメント: 処理内容がわかるようにコード内に**日本語でコメント**を残す。

## 現在の実装状況
### 完了済み機能
- デバイススペックからのキャラクター自動生成ロジック
- 属性相性を考慮したターン制オートバトル（基本機能）
- [Phase 2-A] バトルアニメーション強化（ダメージ数値ポップアップ、スキルエフェクト全体化、HPバーのアニメーション化、ターン数表示）
- [Phase 2-B] スキルシステム拡充（StatusEffectモデルによるバフ・デバフ管理、各属性3種の固有スキル追加）
- [Phase 2-C] バッテリー残量のリアルタイム取得（`battery_plus`）と、キャラクターの素早さ(SPD)へのステータス補正反映

### 実装中の機能（未完成・途中のもの）
- 特になし（Phase 2-Cまで完了し区切りがついた状態）

### 未着手の機能（会話で言及されたが未実装のもの）
- [Phase 2-D] サウンドエフェクト追加 (`audioplayers` パッケージの導入、`SoundService` の作成、各種アクションへの効果音トリガー追加)

## 既知の問題・課題
- 不明（直近の検証では `flutter analyze` などは全て通過しており、目立ったバグの報告はありません）

## ⚠️ 現在の作業状態（引継ぎ情報）
- **最終更新**: 2026-02-20
- **直近でやっていた作業**: Phase 2-Cの「バッテリー残量リアルタイム反映」およびその関連UI実装。加えてAndroid版のビルドエラー修正（Gradle/AGP設定更新）。
- **次にやること**: Phase 2-D の実装（サウンド・効果音の追加対応）。
- **未解決の問題**: 不明
