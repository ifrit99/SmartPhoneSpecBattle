# SPEC BATTLE — TODO

バージョン: 0.1.0
最終更新: 2026-02-22

---

## 状態サマリー
- **完了済み**:
  - Phase 1 MVP (ドメインモデル、各種画面UI、バトルエンジン本実装)
  - Phase 2 (各種UX演出：ダメージポップアップ、クリティカル、バッテリー連携によるSPD補正、効果音)
  - Phase 3-1 (CPU敵キャラ自動生成: `enemy_generator.dart`)
  - Phase 3-2 (キャラクター図鑑・対戦履歴: `CollectionScreen`)
  - Phase 3-3 (タイトル画面: `title_screen.dart`)
  - 重大なバグ修正、及びユニットテスト群の追加
- **現在の位置づけ**: Phase 3 が完了し、Phase 4 の新機能（ガチャ・QR対戦等）へ移行する段階。

---

## ~~Phase 3 後半~~ ✅ 全完了

### ~~1. キャラクター図鑑・対戦履歴 (Phase 3-2)~~ ✅ 完了
- `CollectionScreen` の実装
- 過去に遭遇・撃破した架空の端末（敵キャラクター）のリスト表示
- `shared_preferences` で対戦成績（勝利数・遭遇リスト等）をデータ永続化

### ~~2. タイトル画面の追加 (Phase 3-3)~~ ✅ 完了
- `title_screen.dart` を新設し、アプリ起動時の演出を強化。
- 実装内容:
  - `main.dart` の初期ルートをホーム画面からタイトル画面へ変更。
  - ロゴ（グラデーション＋アイコン）のフェードイン＋スケールアニメーション。
  - 背景に浮遊パーティクルエフェクト。
  - 「TAP TO START」の点滅表示、タップでフェード遷移してホーム画面へ。
  - ボタン操作音（`SoundService.playButton()`）連動。
  - ※BGM再生は専用のBGMアセット追加後に対応予定（Antigravity側タスク）。

---

## 次に実装すべき機能（Phase 4）

### 1. エミュレートガチャ（仮想スペック生成）
- ゲーム内通貨を用いてランダムなスペックキャラを生成するガチャ機能。

### 2. QR/URLフレンドスキャン対戦
- `qr_flutter` 等を用いてキャラクターデータをQR化し、他端末で読み込んで非同期対戦する機能。

---

## Antigravity側への引き継ぎ事項（Phase 3-3 後続）

以下のタスクはUI確認・アセット追加が中心のため、Antigravity が担当する。

### タスクA: タイトル画面の視覚確認とUI微調整
- **対象ファイル**: `lib/presentation/screens/title_screen.dart`
- **確認ポイント**:
  1. エミュレータまたは実機でアプリを起動し、タイトル画面が表示されることを確認。
  2. ロゴのフェードイン＋弾性スケールアニメーション（0→1.2秒）の滑らかさ。
  3. 背景パーティクル（紫色の浮遊ドット30個）の見た目と速度感。
  4. 「TAP TO START」の点滅テキスト（1.5秒周期）の視認性。
  5. タップ後のフェード遷移（600ms）でホーム画面へ正しく移動すること。
- **調整が必要になりうる箇所**:
  - パーティクルの数・サイズ・速度（`_TitleScreenState.initState` 内の生成パラメータ）
  - ロゴアイコンのサイズ・色（`_buildLogo()` メソッド内）
  - アニメーションのタイミング（`_startSequence()` 内の `Future.delayed` の値）

### タスクB: タイトルBGMの追加
- **目的**: タイトル画面表示中にループBGMを再生し、ホーム画面遷移時にフェードアウトする。
- **作業手順**:
  1. BGM素材（`.mp3` or `.ogg`）を `assets/sounds/` に追加（例: `title_bgm.mp3`）。
  2. `pubspec.yaml` の `assets` セクションにファイルを追記。
  3. `lib/data/sound_service.dart` に以下を追加:
     - BGM用の `AudioPlayer` インスタンス（ループ再生対応）
     - `playTitleBgm()` — BGMをループ再生開始するメソッド
     - `stopBgm()` — BGMを停止（フェードアウト付きが望ましい）するメソッド
  4. `title_screen.dart` の `initState` で `SoundService().playTitleBgm()` を呼び出し、`_onTap()` 内で `SoundService().stopBgm()` を呼び出す。
- **参考**: 既存の効果音は `_play()` メソッドで `AssetSource` を使用している（`sound_service.dart:36`）。BGMは別途ループ設定（`AudioPlayer.setReleaseMode(ReleaseMode.loop)`）が必要。

---

## 既知の問題・課題
- **ユニットテスト環境構築エラー**: `flutter test` 実行時に `objective_c` パッケージのネイティブビルドが失敗する（Xcode Command Line Tools のアーキテクチャ不一致問題）。
  - ※テストコード自体は `flutter analyze` を問題なく通過しているため、ローカルマシンの環境設定起因の保留事項。
