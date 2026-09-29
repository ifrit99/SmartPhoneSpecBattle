# UX 壁時計の測り方（pages.dev / iPhone）

閾値の正本は `baselines.json`。今はすべて `null`（measure-only）。方針は `docs/adr/ux-perf-loop.md`。

本番 `https://smartphonespecbattle.pages.dev/` は release ビルドなので `UxTiming` は no-op。iPhone では秒時計か画面録画のタイムスタンプで測る。debug/profile のコンソール出力 `[UxTiming] <metric> <ms>ms` はローカル反復用。

優先: **1 `cold_to_title`** と **3 `ranking_optin_done`**。**2 `home_to_pwr_sheet`** は推奨。

## 共通

1. iPhone Safari で `https://smartphonespecbattle.pages.dev/` を開く（可能ならプライベート）
2. 画面録画を開始するか、秒時計を手元に置く
3. 1回の操作につき1回測る。±20% のブレや単発の悪化は取り直し（自動ラチェットしない）
4. 数値はメモして比較する。このディレクトリの閾値は、改善マージ + この手順での確認後にだけ下げる

## 1. `cold_to_title`（必須）

黒画面のまま固まった検出。ロゴフェードや「TAP TO START」点滅（約 1.4s の意図的演出）は **終了条件に含めない**。

1. Safari のアドレス欄に URL を入れて開く（またはタブを閉じて開き直す）
2. **開始**: 画面が白/黒のまま遷移し始めた瞬間（アドレス確定 / リロード）
3. **終了**: タイトル画面の骨格（夜景プレースホルダまたは `SPEC BATTLE` ロゴの領域）が最初に見えたフレーム。ロゴが伸び切る・TAP が点滅し始めるまで待たない
4. タイトルが出る前に数秒以上黒いままなら、このメトリクスの悪化として記録する

## 2. `home_to_pwr_sheet`（推奨）

1. タイトルをタップしてホームへ進む（同意ダイアログが出たら進める）
2. **開始**: `SPEC POWER` カード（`PowerRatingCard`）をタップした瞬間
3. **終了**: 下からシートが開き、見出し「🌏 世界ランキング（今週）」が見えた瞬間
4. シートは開いたが世界ランキング節がまだ無い場合は終了としない

## 3. `ranking_optin_done`（必須）

1. 戦闘力シートを開いた状態で「🌏 世界ランキング（今週）」を表示する
2. **開始**: 「参加して実際の順位を見る」または参加中スイッチを操作した瞬間
3. **終了**: 操作が終わって UI が落ち着いた直後
   - 成功: 「参加中」スイッチ、または未参加ボタンに戻った状態
   - 失敗: 「参加に失敗しました…」 / 「削除に失敗しました…」が出た状態
4. スピナー相当（ボタン/スイッチ disable）が解けたフレームを終了にする。成功もエラーも同じメトリクス

## ローカル（debug / profile）

```text
[UxTiming] cold_to_title 123ms
[UxTiming] home_to_pwr_sheet 45ms
[UxTiming] ranking_optin_done 800ms
```

`flutter run --profile`（または debug）で上記3操作を行う。release / pages.dev には出ない。
