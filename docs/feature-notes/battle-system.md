# 機能メモ: バトルシステム

## 機能の目的
プレイヤーとCPU/ゲスト敵が自動で戦い、結果を再生型アニメーションで可視化する。
ユーザー操作はごく少なく、「自分のスマホスペックから生まれたキャラがどう戦うか」を見る体験が中核。

## 現状の理解
- 計算は `BattleEngine` が事前に全ターン分を算出し、`BattleResult`（ログ配列＋結果）を返す。
- `BattleScreen` は `Future.delayed` で1エントリずつログを再生し、UIは「再生型」になっている。
- アクションは `attack` / `defend` / `skill` の3種。
- 50ターン経過しても決着がつかない場合、`BattleEngine` が以下の優先度で勝敗を決める（`fix/review-followups`）:
  1. HP割合が高い方の勝ち
  2. 同率ならHP絶対値が高い方の勝ち
  3. それも同じなら敵の勝ち
- バトル終了後の「経験値 / コイン / 図鑑 / 初回バトル報酬 / デイリー報酬」反映は `BattleResultService` に集約（UIはResultScreenのみ）。
- バトル報酬はCPU対戦時のみ付与（QR/フレンド対戦では付与しない）— PR #12 の方針。

## 関連しそうなファイルや処理
- `lib/domain/services/battle_engine.dart` — 純粋Dartのバトル計算ロジック
- `lib/domain/services/battle_result_service.dart` — 結果反映（経験値・コイン・図鑑・報酬）
- `lib/domain/models/character.dart` / `stats.dart` / `skill.dart` / `status_effect.dart`
- `lib/domain/enums/element_type.dart` / `effect_type.dart` — 属性相性・状態異常
- `lib/presentation/screens/battle_screen.dart` — ログ再生UI
- `lib/presentation/screens/result_screen.dart` — 結果描画・`BattleResultService` 呼び出し
- `lib/presentation/widgets/pixel_character.dart` / `damage_popup.dart` / `skill_effect_overlay.dart`
- `test/domain/battle_engine_test.dart` / `battle_result_service_test.dart`

## 今後見直しそうな点
- バランス調整: 50ターン到達率が高い組み合わせがあるかは未確認（仮置き）。計算上、両者HP割合が均衡する可能性について要観察。
- スキル効果量 / 状態異常の期待値のログ可視化（現状は文字ログのみ）。
- ゲスト敵（QR/URL経由）に対してバトル結果保存/図鑑反映ルールをどうするか（現状はCPUのみ報酬）。
- アニメーション再生速度のユーザー調整機能（スキップ・倍速）は未実装（仮置き）。
