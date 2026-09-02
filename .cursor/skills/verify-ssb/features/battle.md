# CPU battle

The main loop: pick an enemy, pick a tactic, pick a support command, watch (or skip) the auto-battle, take rewards. Files: `home_screen.dart` (`_startBattle`, `_EnemyPreviewSheet`), `battle_screen.dart`, `result_screen.dart`.

## Sub-features

- **Start from home:** `バトル開始` (and first-run banner `はじめてのバトル！`, which calls the same `_startBattle`).
- **Enemy preview sheet:** title `挑戦者が現れた！`, difficulty badge `EASY` / `NORMAL` / `HARD` / `BOSS`, enemy `Lv.`, HP/ATK/DEF/SPD, device name + `RAM` / `空き`, insight card, `戦術を選択`.
- **Tactics** (`battle_tactic.dart` labels): `バランス`, `オーバークロック`, `ファイアウォール`, `バースト`. Recommended tactic is pre-selected. Reward chips show `Coin x1.0` / `Coin x1.2` / `Coin x1.1`.
- **Preview actions:** `キャンセル` (dismiss) and `バトル！` (commit tactic, push `BattleScreen`).
- **Support picker** (battle screen, before logs): `サポートコマンドを選択` with `支援なし`, `攻撃支援`, `防御支援` (`BattleSupportCommand` labels). Battle does not start until one is tapped.
- **During battle:** speed cycle button label `x1` → `x1.5` → `x2` → `x3`; skip `スキップ ▶▶`. Overlay mute chips `BGM` and `SE` (GestureDetectors, top-right). Log lines include `--- ターン N ---`, `戦術: …`, `サポート: …`.
- **Done:** skip or playback end → `リザルトへ` (green on win, coral on loss).
- **Result:** headline `🎉 勝利！` or `💀 敗北…`. CPU-only: `もう一戦`, optional `ガチャ`, `Xで結果を呟く`, `ホームに戻る`. First battle: dialog `はじめてのバトル完了！` with `ガチャを引く` / `フレンドに共有` / `あとで`. Daily battle gem popup `デイリーバトル報酬！`. Mission card `ミッション達成！` / `受取へ`.

Friend/URL battles share `BattleScreen` but **do not** grant CPU coins (`isCpuBattle: false`). Prove those in [friend-battle.md](friend-battle.md).

## How to get to it (user POV)

1. Reach home ([home.md](home.md)).
2. Scroll to `バトル開始` (or tap `はじめてのバトル！` on a fresh profile).
3. Read the sheet `挑戦者が現れた！`. Optionally tap a tactic chip. Tap `バトル！` (not another `バトル開始`).
4. On the battlefield, tap `支援なし` (fastest) or a support.
5. Tap `スキップ ▶▶` unless the bug is animation/timing.
6. Tap `リザルトへ`. Wait until save completes (`Xで結果を呟く` enables after `_saved`).
7. Leave via `ホームに戻る`, or `もう一戦` (CPU → preview again).

High-difficulty from home challenge card is a **different** entry that still lands on the same preview/battle/result chain; use it only when the change is HARD/BOSS/rival-road.

## Driving it with Playwright

```text
await page.getByRole('button', { name: 'バトル開始' }).scrollIntoViewIfNeeded();
await page.getByRole('button', { name: 'バトル開始' }).click();
await page.getByText('挑戦者が現れた！').waitFor();
await page.getByText('戦術を選択').waitFor();
# optional: await page.getByText('オーバークロック').click();
await page.getByRole('button', { name: 'バトル！' }).click();
await page.getByText('サポートコマンドを選択').waitFor();
await page.getByRole('button', { name: '支援なし' }).click();
await page.getByRole('button', { name: 'スキップ ▶▶' }).click();
await page.getByRole('button', { name: 'リザルトへ' }).click();
await page.getByText(/勝利！|敗北…/).waitFor();
await page.getByRole('button', { name: 'ホームに戻る' }).scrollIntoViewIfNeeded();
```

Dismiss extra dialogs if they appear: `受け取る` (daily battle gems), `あとで` (first-battle complete).

**Proof (screenshots at preview, mid-battle or skip, result):**

- Preview showed a difficulty badge and `バトル！`.
- After support: either log text `サポート: 支援なし` or skip jumped to `リザルトへ`.
- Result headline is `勝利！` or `敗北…` (both are valid; CPU can lose).
- After `ホームに戻る`, RecordCard `バトル数` is **not** still `0` on a first battle.
- First battle only: `はじめてのバトル完了！` appeared, and the home banner `はじめてのバトル！` is gone on return.

Do not wait out a 50-turn playback at `x1`. Skip is the user-facing fast path (`_skipToEnd` still applies final HP and the real `BattleResult`).

## Gotchas

- **Support blocks the battle.** If you never tap `支援なし` / `攻撃支援` / `防御支援`, `スキップ ▶▶` is not on screen yet (`_supportSelected` is false).
- Speed button accessible name is `x1` (then `x1.5`…). It is not labeled `再生速度`.
- `スキップ ▶▶` includes the triangle characters; match the full label.
- Auto-battle can take many seconds even at `x3` if you forget skip. Prefer skip unless proving log cadence.
- Result `ガチャ` is hidden when the player cannot afford a pull (`_canOpenGacha`). Absence is not a regression if coins/gems are below 100/20/30.
- `もう一戦` exists only for `isCpuBattle`. Friend battles go home without it (`result_screen_test.dart`).
- BGM starts on battle (`playBgm` + `playBattleStart`). `--mute-audio` is mandatory. Do not use audible BGM as proof.
- Overlay `BGM`/`SE` are not Material buttons; `getByText('BGM')` after semantics.
- Random enemy: do not assert a specific device name unless you entered via HARD/BOSS/rival-road which pins the catalog entry.
