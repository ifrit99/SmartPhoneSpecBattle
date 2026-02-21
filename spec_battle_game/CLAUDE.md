# SmartPhoneSpecBattle - CLAUDE.md

## 言語設定

すべての応答・説明・質問・確認事項・提案・エラーの解説は**日本語**で行うこと。
コード内のコメントも日本語で記述すること（特別な指示がない限り）。
専門用語はそのまま英語を使用してよいが、説明は日本語で補足すること。
このルールはセッションをまたいでも常に適用すること。

## プロジェクト概要
スマートフォンのデバイススペック（OSバージョン、メモリ、ストレージ、バッテリー残量など）を解析し、その情報に基づいて世界に1体だけのキャラクターを生成して戦わせる、Flutter製の対戦RPGゲーム。

## 技術スタック
- **Framework**: Flutter (Dart)
- **State Management**: `setState` + `AnimatedBuilder` (シンプル構成)
- **Local Storage**: `shared_preferences`
- **Device Info**: `device_info_plus` (Native / Web差分吸収あり), `package_info_plus`, `battery_plus`
- **Sound**: `audioplayers` (効果音再生、シングルトン `SoundService` で管理)

## ディレクトリ構造
- `lib/data/`: データ取得層 (デバイス情報取得API, ローカルストレージ管理, `SoundService`)
- `lib/domain/`: ドメインモデルとロジック (キャラクター、スキルステータス効果モデル、各種列挙型、バトルエンジン)
- `lib/presentation/`: UI層 (画面Screen群、カスタムWidget群)
- `assets/sounds/`: WAV形式の効果音ファイル (battle_start / attack / skill / defend / heal / victory / defeat / button)
- `test/domain/`: ドメイン層のユニットテスト

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
- [Phase 2-D] サウンドエフェクト追加（`audioplayers` パッケージ導入、`SoundService` 作成、バトル開始・攻撃・スキル・防御・回復・勝利・敗北・ボタン音の実装、ミュートトグルボタン追加）
- [コード品質] `Skill` モデルに `isDrain` フラグ追加・`battle_engine.dart` のスキル名ハードコード除去
- [コード品質] `main.dart` に `WidgetsBindingObserver` を追加し `SoundService.dispose()` をライフサイクルに接続
- [テスト] `test/domain/` にユニットテスト追加（`element_type_test.dart` / `experience_test.dart` / `battle_engine_test.dart`、計21ケース）
- [Phase 3-1] CPU敵キャラクター生成機能（`enemy_generator.dart` 新設）: `EnemyDifficulty` enum・架空デバイスカタログ16種・`EnemyProfile` モデル・`EnemyGenerator` クラスを実装。バトル前の敵プレビューボトムシートを `home_screen.dart` に追加（難易度バッジ・架空デバイス情報・ステータス表示）。
- [バトル拡張] クリティカルヒットシステム実装（SPD差・属性有利時に25%確率で1.5倍ダメージ、通常攻撃・攻撃スキル両対応）
- [ドキュメント] `docs/SPECIFICATION.md`（558行の詳細仕様書）・`docs/TODO.md`（タスク管理）を追加

### 実装中の機能（未完成・途中のもの）
- 特になし

### 未着手の機能（推奨実装順序）? 
#### Phase 3（基盤拡張）
- [Phase 3-2] **キャラクター図鑑・対戦履歴**: `collection_screen.dart` を新設し、ローカルストレージに戦った敵のデータや自分のキャラの育成履歴を保存・閲覧できるようにするコレクション要素の追加。← **次に着手推奨**（Phase 4の土台になる）
- [Phase 3-3] **タイトル画面の追加**: `title_screen.dart` を新設し、アプリ起動時の導入（ロゴ表示、タップスタート、BGM再生）を整える。

#### Phase 4（ゲームループ拡張・収益化準備）— 詳細は `PHASE4_SPEC_DRAFT.md` 参照
- [Phase 4-1] **エミュレートガチャ（仮想スペック生成）**: ゲーム内通貨で「過去の名機」「架空の最新端末」のスペックカードを引き、自分以外のキャラを獲得するコレクション＆マネタイズの軸。
- [Phase 4-2] **QR/URLフレンドスキャン対戦**: 自キャラのデータをQRコード化してSNSシェア → 読み込んだ相手と非同期バトル。サーバーレス設計（QR内にパラメータ埋め込み）。
- [Phase 4-3] **動的スペックシステム（デイリー環境補正）**: バッテリー（実装済み）に加え、空き容量・時間帯・曜日でステータスが日々変動し、毎日のログイン動機を作る。
- [Phase 4-4] **パーツ換装・オーバークロック**: 装備アイテムや使い捨て強化パッチでキャラを限界突破させるハクスラ要素。
- [Phase 4-5] **AIフレーバーテキスト生成**: Gemini API等でスペック情報から「二つ名」「性格」「フレーバーテキスト」を動的生成し、キャラへの愛着を強化。

## 既知の問題・課題
- `flutter test` 実行時に `objective_c` パッケージのネイティブビルドが失敗する（原因: Xcode Command Line Tools が x86_64 版のまま Apple Silicon 環境に入っている）。テストコード自体は `flutter analyze` 通過済みで問題なし。修正方法: `sudo rm -rf /Library/Developer/CommandLineTools && sudo xcode-select --install`

## ⚗️ 現在の作業状態（引継ぎ情報）
- **最終更新**: 2026-02-21
- **直近でやっていた作業**: VPS側Claude Codeからの引き継ぎ。スキル攻撃へのクリティカルヒット判定追加、TODO.mdの完了項目更新、flutter analyze通過確認。Phase 4仕様案をCLAUDE.mdに反映。
- **次にやること**: Phase 3-2（図鑑・対戦履歴）→ Phase 3-3（タイトル画面）→ Phase 4（エミュレートガチャ・QR対戦等）の順で進めるのを推奨。
- **未解決の問題**: `flutter test` が Xcode Command Line Tools のアーキテクチャ不一致で失敗する（上記「既知の問題」参照）
