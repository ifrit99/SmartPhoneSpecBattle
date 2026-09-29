# ADR: UX 壁時計計測ループ

- 日付: 2026-09-29
- 状態: Accepted（docs + 最小ハーネス。閾値は未設定）
- 対象: `cold_to_title` / `home_to_pwr_sheet` / `ranking_optin_done`

## Context

起動〜タイトル、ホーム〜戦闘力シート、世界ランキング参加トグルの待ち時間が「黒い画面のまま固まった」ように見えることがある。改善の前に、ユーザーが体感する壁時計を固定点で測るループが必要。

本プロダクトに Claude API はない。LLM 向けの eval / hillclimb は Skill 側の話であり、ここでは使わない。測るのは製品 UX の壁時計だけ（Anthropic の measure→improve：推測やプロキシ指標ではなく、ユーザーが待つ時間を先に測ってから改善する）。

## Decision

### 固定メトリクス

| ID | 開始 | 終了 | 何を見るか |
|---|---|---|---|
| `cold_to_title` | `main` 入場時点の壁時計（`Stopwatch`）。Web の `performance.timeOrigin` / `navigationStart` は既存 interop が無く今回は見送り | `TitleScreen` の初回 post-frame（`WidgetsBinding.instance.addPostFrameCallback` を1回）。ロゴ / TAP 演出（約 1.4s の意図的 UX）は待たない | 黒画面のまま固まった検出。タイトル Widget が1フレーム描かれたか |
| `home_to_pwr_sheet` | `PowerRatingCard` の `onTap` → `PowerRankingSheet.show` | `PowerRankingSheet` の初回 post-frame。そのフレームには `🌏 世界ランキング（今週）` を出す `_WorldRankingOptInSection` が入っている | シートが開いて世界ランキング節が見えるまで |
| `ranking_optin_done` | `_WorldRankingOptInSectionState._setOptIn` 入場（`_busy` 早期 return の後） | `finally` で `_busy=false` を settle したあと、成功 UI またはエラーフォールバック UI の post-frame | 参加トグルが操作可能に戻るまで。成功/失敗どちらでも閉じる |

### ハーネス

- 実装: `lib/data/ux_timing.dart`
- 記録: `kDebugMode || kProfileMode` のときだけ `Stopwatch` で mark
- release: no-op（本番 pages.dev の JS にはログを出さない）
- 埋め込みは上記3経路のみ。F6 PR-C・見た目改修・Firebase rules は触らない

### ラチェット

1. `docs/perf/baselines.json` の `threshold_ms` が `null` / 未設定なら **measure-only**。CI は fail しない
2. 閾値を下げるのは、改善が master にマージされ、pages.dev で人間が確認したあとだけ
3. フレーク（±20%）や単発の悪化では自動ラチェットしない。取り直す
4. CI の任意ステップはログのみ。計測ファイルが無い、または閾値が未設定なら exit 0

### 人間確認（pages.dev / iPhone）

手順の正本は `docs/perf/README.md`。優先はメトリクス 1 と 3。2 は推奨。release には mark が無いので、人間は壁時計（画面録画のタイムスタンプまたは秒時計）で測る。debug/profile の `[UxTiming] <id> <ms>ms` はローカル反復用。

## Consequence

- 黒画面固まりと参加トグル待ちを、同じ名前でローカル（debug/profile）と pages.dev（人間の壁時計）から参照できる
- 閾値が空の間は CI が緑のままなので、未計測を失敗にしない
- Web 起動を `navigationStart` まで含める計測は後続。今回の `cold_to_title` は Dart `main` 以降

## Out of scope

F6 PR-C、ビジュアル再設計、Firebase rules、マージ、オンデマンド課金。
