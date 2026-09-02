# Friend URL battle

Share your character as a `?battle=` URL, or paste someone else's, preview the matchup, then fight. Web MVP replaced QR camera screens; class names still say `qr_*`. Files: `qr_menu_screen.dart`, `qr_display_screen.dart`, `qr_scan_screen.dart`, `qr_guest_preview_screen.dart`, `battle_deep_link.dart`.

## Sub-features

- **Menu** AppBar `フレンド対戦`. Blurb `自分のキャラクターを友達にシェアして対戦しよう！`. Buttons:
  - `URLでシェアする` / subtitle `自分のキャラの対戦URLを発行`
  - `URLを入力して対戦` / subtitle `友達から受け取ったURLで対戦`
- **Share** AppBar `対戦URLを共有`. Character card (equipped gacha or `実機スペック`), URL as `SelectableText` (green monospace, contains `?battle=`), `シェアする`, `URLをコピー`. Snackbars `URLをコピーしました！` or `共有テキストをコピーしました。SNS等に貼り付けてください！`.
- **Input** AppBar `対戦コードを入力`. Field label `対戦URL / コード`, hint `https://.../?battle=`. `貼り付け`, `読み取る` (disabled until non-empty; while working `解析中`). Inline: `読み取り準備完了` (`ValueKey('ready')`), errors `形式不正` / `チェックサム不一致` / `クリップボードに対戦URLがありません` (`ValueKey('error')`).
- **Guest preview** AppBar `対戦プレビュー`. Own vs opponent cards, 相性 copy, `戦術`, start `バトル開始` (or `準備中...`), `キャンセル`. Recommended tactic is pre-selected and passed into `BattleScreen`.
- **Cold deep link:** `http://127.0.0.1:<port>/?battle=<payload>` skips title and opens preview (`main.dart` `_initialBattleParam`). Decode failures use `decode_failure_copy.dart` (not a silent white screen).
- **Rewards:** this path sets `isCpuBattle: false`. Result has **no** `もう一戦` and must **not** increment CPU-only coin grants. EXP/collection still update.

## How to get to it (user POV)

From home: tap `Friend`.

**Share:** `URLでシェアする` → wait for the URL box → `URLをコピー`. Send that string to another origin/port or paste locally.

**Receive (in-app):** `URLを入力して対戦` → paste or type → wait `読み取り準備完了` → `読み取る` → preview → `バトル開始` → same support/skip/result as CPU, minus CPU rewards.

**Receive (URL bar):** paste a full share URL into the same or second instance. Preview should appear without `TAP TO START`.

Two-instance flow (preferred isolation): Launch 8091 (host) and 8092 (guest), copy URL on 8091, `page.goto` the URL on 8092 (different origin → different save data, still valid payload).

## Driving it with Playwright

**Share URL exists**

```text
await page.getByRole('button', { name: 'Friend' }).click();
await page.getByText('フレンド対戦').waitFor();
await page.getByRole('button', { name: /URLでシェアする/ }).click();
await page.getByText('対戦URLを共有').waitFor();
await page.getByText(/\?battle=/).waitFor();
await page.getByRole('button', { name: 'URLをコピー' }).click();
await page.getByText('URLをコピーしました！').waitFor();
```

Read the `?battle=` string from the page text (selectable URL). Screenshot the share card so the character on the card matches home.

**Paste on the same instance** (single-port fallback; overwrites nothing until battle completes):

```text
await page.getByRole('button', { name: /URLを入力して対戦/ }).click();
await page.getByText('対戦コードを入力').waitFor();
await page.getByLabel('対戦URL / コード').fill(shareUrl);
await page.getByText('読み取り準備完了').waitFor();
await page.getByRole('button', { name: '読み取る' }).click();
await page.getByText('対戦プレビュー').waitFor();
await page.getByRole('button', { name: 'バトル開始' }).click();
```

If `getByLabel` misses (Flutter semantics sometimes names the field from hint only), `getByPlaceholder('https://.../?battle=')` or fill the textbox role.

**Garbage input**

```text
await page.getByLabel('対戦URL / コード').fill('not-a-battle-code');
await page.getByRole('button', { name: '読み取る' }).click();
await page.getByText('形式不正').waitFor();
```

**Proof:** share page shows `?battle=` once (no doubled query); preview shows two names; after battle, result **lacks** `もう一戦`; home coins did not jump by a CPU-win amount if you noted coins before.

## Gotchas

- **Deep link vs title.** `/?battle=` must not require `TAP TO START`. If it does, the param parse in `main.dart` / `QrBattleService.extractBattleParam` failed (padding, fragment, or `battle=` stripped).
- Clipboard `貼り付け` in headless Playwright is flaky unless you grant clipboard permissions and set `navigator.clipboard`. Prefer `fill()` on the text field.
- `読み取る` stays disabled (`_canSubmit`) while the field is empty — that is the backup-style empty UX, not a broken button.
- Guest `バトル開始` is the **preview** CTA. Home also has `バトル開始`. Assert AppBar `対戦プレビュー` before clicking it.
- Do not use production GitHub Pages (`ifrit99.github.io`) as `baseUrl` for a local character unless you mean to mix deploys. Local `generateShareUrl` uses `Uri.base` (PR #11), so a local server issues `http://127.0.0.1:<port>/?battle=...`.
- Second instance is the right way to simulate "a friend". Same origin + same context will share inventory and look like fighting yourself after equip changes.
- Refuse to attach a second Playwright to port 8091 while another verify run owns it. Launch 8092 instead.
