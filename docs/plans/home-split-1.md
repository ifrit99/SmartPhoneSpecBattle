# Plan: F4 ホーム画面分割（第1PR）
Created: 2026-09-01
Status: IN_PROGRESS

## 要件
`docs/phase5_brushup_spec.md` §2-5。`home_screen.dart` をカード単位で段階分割する。挙動変更なし。要件の追加なし（§2-5の転記のみ）。

## 仕様（§2-5 転記）

- 分割先: `lib/presentation/widgets/home/`。カード単位で1ファイル（例: `daily_mission_card.dart`, `season_pass_card.dart`, `rival_road_card.dart`, `power_rating_card.dart`, `next_action_card.dart` 等、現行ホームの機能カードすべて）。
- 設計原則: 各カードは **Stateless**。表示データとコールバックをコンストラクタで受け取り、状態・永続化は従来どおり `HomeScreen` が保持する（状態管理方式を変えない）。
- 進め方: 1PRあたり2〜4カードの段階分割。各PRで `flutter analyze` / `flutter test` / スクリーンショット比較（変化なしを確認）。
- 完了定義: `home_screen.dart` ≦ 800行。

本PR（home-split-1）は段階分割の第1PR。2〜4カードのみ抽出する。完了定義（800行以下）は後続PRを合わせた目標であり、本PR単体では達成しない。

## テスト基準（§4-2 分割後ホームカード）
- [ ] 各カードが入力データを正しく描画する
- [ ] コールバックが発火する（分割PRごとに追加）

## 完了条件
- [ ] flutter analyze: エラー0
- [ ] flutter test: 全パス

## 制約
- 見た目・挙動は変えない。
- 残カード、F6、Firebase、agmsg は対象外。

---
## Generator ログ
- 第1PRとして `RecordCard` / `DailyRewardCard` / `NextActionCard` の3枚を `lib/presentation/widgets/home/` へ抽出。いずれも Stateless。表示データとコールバックはコンストラクタ経由。状態・永続化は `HomeScreen` のまま。
- 残カードは抽出せず、`home_screen.dart` の800行化は後続PRの完了定義として残す。

---
## 評価
（Evaluator が検証結果を追記）
