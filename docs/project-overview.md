# プロジェクト概要

## プロジェクト名
SmartPhoneSpecBattle（スマホスペックバトル）

## 目的
スマートフォンのデバイススペック（OSバージョン・CPU・RAM・ストレージ・画面サイズ等）を解析し、その情報から一意のステータスを持つキャラクターを生成して戦わせる対戦型モバイルRPG。
不可視なデバイス情報を「キャラ化」することで、「自分のスマホがどんな強さか？」という好奇心を刺激し、他者のデバイスと競わせる遊びを提供する。

## このプロジェクトで大事にすること
- **シンプル第一**: 変更・依存は最小限（過剰設計NG）。
- **3層レイヤー構造の維持**: `data` / `domain` / `presentation` の境界を崩さない。
- **ドメイン層はUI非依存**: `battle_engine.dart` などは純粋Dartで完結。
- **個人開発のスピード感**: 重い運用ルールは敷かず、`docs/TODO.md` と本レイヤーで文脈を継承する。
- **Less is More & Progressive Disclosure**: 文書は小さく分割し、必要な時だけ読む。

## 現在の主要機能
- タイトル / ホーム / キャラクター生成 / バトル / リザルト画面
- CPU敵の自動生成（`enemy_generator.dart`）、敵デバイス名は架空ブランド
- キャラクター図鑑・対戦履歴（`CollectionScreen`）
- ガチャ（仮想スペック生成、レアリティ付き）
- URL共有によるフレンド対戦（QR非対応、Web MVP）
- 初回オンボーディング・初回バトル完了後案内
- デイリーログイン報酬・バトル報酬（CPU対戦のみ）
- BGM/SE再生（Web版はdocument.createElement方式で安定化）

## 非目標（今やらない）
- Androidリリースビルド / Play Store公開（MVP優先のためWebに集約）
- iOSリリース
- QRコード画像スキャン・カメラ読み取り
- サーバーサイド・オンラインランキング
- 大規模状態管理ライブラリ（Riverpod/Bloc等）導入
- 実在デバイス名の表示（商標・法務リスクのため架空ブランド化済み）

## 技術方針
- **Framework**: Flutter（Dart SDK >=3.0.0 <4.0.0）
- **状態管理**: `StatefulWidget` + `setState`、高頻度更新は `AnimatedBuilder`
- **永続化**: `shared_preferences`
- **サウンド**: `audioplayers`（Web SEは `document.createElement('audio')` で補強）
- **プラットフォーム差分**: 条件付きインポート（`platform_info_native.dart` / `platform_info_stub.dart` 等）
- **バトル計算**: 事前計算→UIで再生する「再生型」
- **検証**: `flutter analyze` + `flutter test`（Dockerコンテナで実行可）

## 今の課題
- `fix/review-followups` ブランチのPR化 → マージが未完了（50ターン決着・BattleResultService分離・テスト拡充）
- GitHub Pages デプロイ後のOGP/URL対戦フロー最終確認が残タスク
- Mac環境では `objective_c` ネイティブビルド問題で `flutter test` がローカル失敗する場合がある（Docker回避）
- ステータス生成ロジック（`character_generator.dart`）のバランスは数値調整の余地あり（仮置き）
