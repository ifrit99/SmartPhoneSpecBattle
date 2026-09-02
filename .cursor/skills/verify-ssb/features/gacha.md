# Gacha and party equip

Spend coins/gems on fictional phone characters, then equip one so home/battle/share use it. Screens: `gacha_screen.dart`, `inventory_screen.dart`. Costs in `player_currency.dart`: single **100** coins, ten-pull **900**, premium **20** gems, event **30** gems.

## Sub-features

- **Gacha screen** AppBar `ガチャ`. Rate / pity copy includes `プレミアム解析: SR以上確定`, `イベント解析: SR以上確定`, `※10連はSR以上1枚確定`, `今日のピックアップ:`, `イベント限定:`.
- **Pull buttons** (ElevatedButton rows — match on the leading phrase; coin/gem chips sit beside them):
  - `1回引く` + `🪙 100`
  - `10連` + `🪙 900`
  - `プレミアム解析` + `💎 20`
  - `イベント解析` + `💎 30`
- **Shortage snackbars** (exact patterns from `gacha_screen_test.dart`):
  - `コインが足りません: あとN Coin。CPU戦やミッションで集めましょう` (single)
  - ten-pull hint uses `CPU戦や週次報酬で集めましょう`
  - gems: `ジェムが足りません: あとN Gems。…`
- **Results:** single dialog with rarity `N`/`R`/`SR`/`SSR`, equip `このキャラで戦う`, dismiss `閉じる`. Ten-pull title `10連ガチャ結果`, `おすすめを装備`, `閉じる`. Snackbar after equip: `{deviceName} をメインキャラクターに設定しました`.
- **Shake lock:** while `_isPulling`, buttons are `onPressed: null` (~1.5s of 100ms shakes). Do not double-click.
- **Party** after a pull: cards appear in `編成・インベントリ`; empty CTA `ガチャで仲間を獲得` is gone.

A brand-new profile has **0 coins / 0 gems**. Login bonus (`受け取る` on home) grants gems; CPU wins grant coins. Shortage snackbars are the first-run gacha proof; a successful pull needs currency first.

## How to get to it (user POV)

- Home `Gacha`.
- Home `Party` → empty `ガチャで仲間を獲得`, or result `ガチャ`, or first-battle dialog `ガチャを引く`.
- Home next-action / roadmap cards may also push `GachaScreen`.

Leave with AppBar back. Home header `🪙` / `💎` should drop after a paid pull.

## Driving it with Playwright

**Shortage (fresh context, no CPU wins):**

```text
await page.getByRole('button', { name: 'Gacha' }).click();
await page.getByText('ガチャ').waitFor();  # AppBar; also appears in other copy — prefer the bar
await page.getByRole('button', { name: /1回引く/ }).click();
await page.getByText(/コインが足りません: あと100 Coin/).waitFor();
```

Screenshot the snackbar **and** unchanged `🪙 0` (or whatever the header showed before the tap). That is a valid proof of the empty-wallet path.

**Paid single pull (after at least 100 coins from CPU battles — [battle.md](battle.md)):**

```text
await page.getByRole('button', { name: /1回引く/ }).click();
# wait out shake; buttons are disabled
await page.getByRole('button', { name: '閉じる' }).waitFor({ timeout: 15000 });
# or equip: getByRole('button', { name: 'このキャラで戦う' })  — not Party's このキャラクターで戦う
```

Then `Party` and assert the new device name is on a card.

**Ten-pull / premium / event:** same pattern; only when the header shows `🪙 >= 900` or `💎 >= 20` / `30`. If not, do not fail the feature — record "currency insufficient for this sub-feature" and prove shortage instead.

## Gotchas

- Flutter may expose the pull control as name `1回引く` **or** `1回引く 🪙 100` (icon-button child texts concatenate). Use a regex `/1回引く/` rather than an example selector from another app.
- `Gacha` (home English) vs AppBar `ガチャ` (Japanese). After navigation, do not click home `Gacha` again.
- First-run 0 coin is expected. The old browser-case doc `docs/gacha_browser_test_cases.md` assumed a funded account; this map does not.
- Duplicate pulls convert to 覚醒 (max +5) or coin refund — result copy changes. Still a success if the dialog appears and roster count does not drop.
- Do not scrape RNG to assert a specific SSR. Assert rarity letter + dialog, or inventory growth.
- Pull SFX is muted; do not wait for audio.
- `おすすめを装備` is ten-pull only. Single-result equip is `このキャラで戦う` (shorter than inventory's `このキャラクターで戦う`).
