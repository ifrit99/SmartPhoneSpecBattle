# Home hub

The player's desk after the title: see the generated phone-character, currencies, daily chores, and every door into the rest of the game. Implemented in `lib/presentation/screens/home_screen.dart` (a long vertical scroll, not a tab shell).

## Sub-features

- **Title gate** (`title_screen.dart`): logo `SPEC BATTLE`, subtitle `スマホのスペックで戦え`, blinking `TAP TO START`, `v0.1.0`. Web needs two taps (audio unlock, then leave).
- **Analytics consent** (`analytics_consent_dialog.dart`): first leave-title only, `プレイデータ送信へのご協力`.
- **Onboarding** (`onboarding_screen.dart`): first run, three pages, `スキップ` / `次へ` / `はじめる！`. Flag `onboarding_completed`.
- **Currency header**: coins `🪙` and gems `💎` at the top-right (`_buildCurrencyHeader`).
- **Character card**: name, title badge, element, `Lv.N`, HP bar, `見た目` chip. Tap card → character screen. Tap `見た目` → avatar studio.
- **Power rating card**: `推定上位N%` and a letter tier; tap → sheet `戦闘力ランキング`.
- **Record card**: `バトル数` / `勝利数` / `勝率`.
- **Home cards seen on a live first-run pass** (titles in the semantics tree; several sit below the first canvas fold):
  - `解析ロードマップ`
  - `日替わりショップ`
  - `ライバルロード`
  - `高難度チャレンジ`
  - `シーズンパス YYYY-MM` (source `'シーズンパス ${pass.seasonId}'`; live semantics may concatenate, e.g. `シーズンパス2026-09`)
  - plus missions / next-action / weekly / limited-event copy that changes with state. Do not treat every card as required chrome if a later A/B hides one; the five titles above were present on the Mac home proof.
- **Menu rows** (OutlinedButton.icon labels, exact):
  - `Party` → inventory
  - `Gacha` → gacha
  - `Collection` → collection
  - `Friend` → friend menu
  - `Help` → `遊び方`
  - `Privacy` → `Privacy`
  - `Backup` → `データ保護`
- **First-run banner**: `はじめてのバトル！` / `あなたのスマホの実力を試してみよう` while `first_battle_completed` is false.
- **Battle CTA**: ElevatedButton `バトル開始` (then enemy preview — see [battle.md](battle.md)).
- **Hint**: `タップしてキャラクター詳細を見る`.
- **Login popup**: `ログインボーナス！` + `受け取る` when the daily login is unclaimed and home is in front.

## How to get to it (user POV)

1. Open `http://127.0.0.1:<port>/` (no `?battle=`).
2. Wait for `SPEC BATTLE` + `TAP TO START`.
3. Tap the view once. Still on title.
4. Tap again. Dismiss `協力しない` if the consent dialog appears. Tap `スキップ` if onboarding appears. Tap `受け取る` if login bonus appears.
5. You are home when semantics include `Party`, `Gacha`, `Collection`, `Friend`, `Help`, `Privacy`, `Backup`, and `バトル開始`. Several of those sit below the first 390×844 canvas fold — presence in the tree is enough for this feature's arrival proof.

Returning from a pushed screen (gacha, party, battle result `ホームに戻る`) lands on the same hub; data reloads via `_reloadData()`.

## Driving it with Playwright

Boot path is in `SKILL.md` Drive. Then:

```text
# flt-semantics-placeholder / Enable accessibility sits OUTSIDE 390x844.
# A normal click times out. Force (or click the DOM node).
await page.getByRole('button', { name: 'Enable accessibility' })
  .click({ force: true }); // if present
await page.getByText('SPEC BATTLE').waitFor();
await page.locator('flutter-view, flt-glass-pane, canvas').first.click();
await page.waitForTimeout(500);
await page.locator('flutter-view, flt-glass-pane, canvas').first.click();
# consent — Japanese 協力しない, never 协力しない
if (await page.getByRole('button', { name: '協力しない' }).count()) {
  await page.getByRole('button', { name: '協力しない' }).click();
}
if (await page.getByRole('button', { name: 'スキップ' }).count()) {
  await page.getByRole('button', { name: 'スキップ' }).click();
}
if (await page.getByRole('button', { name: '受け取る' }).count()) {
  await page.getByRole('button', { name: '受け取る' }).click();
}
await page.getByRole('button', { name: 'Party' }).waitFor();
await page.getByRole('button', { name: 'Gacha' }).waitFor();
await page.getByRole('button', { name: 'Collection' }).waitFor();
await page.getByRole('button', { name: 'Friend' }).waitFor();
await page.getByRole('button', { name: 'Help' }).waitFor();
await page.getByRole('button', { name: 'Privacy' }).waitFor();
await page.getByRole('button', { name: 'Backup' }).waitFor();
await page.getByRole('button', { name: 'バトル開始' }).waitFor();
# do NOT rely on scrollIntoViewIfNeeded() here — it does not move the canvas
```

Observable home proof (screenshot **and** semantics):

- Menu row + CTA in the tree: `Party`, `Gacha`, `Collection`, `Friend`, `Help`, `Privacy`, `Backup`, `バトル開始`.
- Cards also seen live: `解析ロードマップ`, `ライバルロード`, `高難度チャレンジ`, `シーズンパス2026-09` (or `シーズンパス 2026-09`), `日替わりショップ`.
- A `Lv.` string on the character card.

Smoke a door without finishing the destination: click `Help`, wait for AppBar `遊び方`, screenshot, back.

## Gotchas

- **Two taps on web.** One tap is not a bug; `_webAudioReady` returns early (`title_screen.dart`).
- **Enable accessibility is off-viewport.** `flt-semantics-placeholder` sits outside 390×844. Click with `{ force: true }` (or DOM). Without `force`, Playwright times out on actionability.
- **Semantics scroll does not move the canvas.** `scrollIntoViewIfNeeded()` on a semantics node leaves the painted Flutter view where it was. `Party` / `Gacha` / `バトル開始` can be in the tree while still below the first canvas fold. Arrival proof = semantics presence. To click a below-fold painted control, wheel/drag the canvas; do not assume semantics-scroll.
- **Do not confuse** home `バトル開始` with preview sheet `バトル！` or guest preview `バトル開始`.
- Consent button is `協力しない` (協力). Do not write `协力しない`.
- Login / mission claim dialogs steal clicks. If a button no-ops, screenshot and look for `受け取る` / `ログインボーナス！`.
- Home is not a URL route. Reload (`page.goto` again) restarts at the title, but a **same-origin** reload keeps `shared_preferences` (onboarding already done).
- First-run `はじめてのバトル！` disappears after the first completed battle (`first_battle_completed`).
- Docker's published 8080 is not this hub unless you exec'd `flutter run` inside the container. Default verify port is 8091.
