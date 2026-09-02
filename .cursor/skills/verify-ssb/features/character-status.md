# Character / status

Who you are fighting as: the spec-generated (or gacha-equipped) character, its stats, avatar paint, and the party roster. Players tap the home portrait, open `見た目`, or press `Party`.

## Sub-features

- **Home portrait** (`_buildCharacterCard`): pixel sprite, name, title (e.g. `ルーキー`), element badge, `Lv.N`, HP bar. Tap the card (not `見た目`) → `CharacterScreen`.
- **Character screen** (`character_screen.dart`): AppBar `キャラクター`. Sections `ステータス` (HP / ATK / DEF / SPD bars), `スキル`, EXP card. Read-only; no save button.
- **Avatar studio** (`avatar_studio_screen.dart`): AppBar `アバタースタジオ`. Entry: home chip `見た目`. AppBar tooltip `リセット（全ておまかせ）`. Changes persist as `avatar.customization` and show on home / ranking / league / battle sprites.
- **Power rating** (`power_rating_card.dart`): home card with `推定上位N%` and tier letter. Tap → modal `戦闘力ランキング` listing `あなたのスマホ` plus catalog devices.
- **Party / inventory** (`inventory_screen.dart`): AppBar `編成・インベントリ`. Empty: `まだ編成できるキャラがいません` + `ガチャで仲間を獲得`. With roster: rarity filter, Power, tap a card → sheet with `このキャラクターで戦う` or `装備中`. Unequip snackbar `実機のスペックに戻しました`. Equip snackbar `{deviceName} をメインキャラクターに設定しました` then pops back to home.

Web device specs are mostly fixed (`docs/device_info.md`: OS `"Web"`, model `"Web Browser"`, 4 cores, 32GB free, 50% battery), so the first-run character is stable-ish aside from ±2 stat jitter and a stored `character_seed`.

## How to get to it (user POV)

From home (see [home.md](home.md)):

- **Status:** tap the big character card (the portrait / name / `Lv.` block). Footer already says `タップしてキャラクター詳細を見る`.
- **Avatar:** tap the small `見た目` chip under the sprite — not the card body.
- **Ranking sheet:** tap the power card (`推定上位`).
- **Party:** tap `Party`. First-run roster is empty until a gacha pull ([gacha.md](gacha.md)).

Back via the AppBar back affordance (Flutter semantics: often `Back` / `戻る`) or Android-style leading icon.

## Driving it with Playwright

**Character screen**

```text
# on home
await page.getByText('タップしてキャラクター詳細を見る').waitFor();
await page.getByText('Lv.', { exact: false }).first.click();
await page.getByText('キャラクター').waitFor();  # AppBar
await page.getByText('ステータス').waitFor();
await page.getByText('ATK').waitFor();
await page.getByText('スキル').waitFor();
```

If the `Lv.` click hits the wrong node, click the player name text instead (whatever string sits above `Lv.` on the card). Screenshot home card, then the `キャラクター` screen showing HP trailing text `N/M`.

**Avatar**

```text
await page.getByText('見た目').click();
await page.getByText('アバタースタジオ').waitFor();
```

Proof: studio AppBar visible; after a visible slot change, pop back and screenshot the home sprite (same run — do not require pixel-match to `master`; that is the other gate).

**Empty party**

```text
await page.getByRole('button', { name: 'Party' }).click();
await page.getByText('編成・インベントリ').waitFor();
await page.getByText('まだ編成できるキャラがいません').waitFor();
await page.getByRole('button', { name: 'ガチャで仲間を獲得' }).waitFor();
```

**Equip (needs a roster — pull first, [gacha.md](gacha.md))**

```text
await page.getByRole('button', { name: 'Party' }).click();
# tap a roster card by device name shown on the tile
await page.getByRole('button', { name: 'このキャラクターで戦う' }).click();
await page.getByText('をメインキャラクターに設定しました').waitFor();
```

Home character **name** should now match the gacha device, not the spec-generated name.

## Gotchas

- `見た目` is a nested `GestureDetector` on the card. A click on the sprite may open **character status**, not the studio. Target the string `見た目`.
- Character screen has no `Key`s. `HP` / `ATK` also appear on home and the enemy preview — assert AppBar `キャラクター` first.
- Empty inventory is the first-run truth, not a failure. Do not treat "no cards" as a broken Party button.
- Equipping pops the inventory route (`Navigator.pop` after snackbar). Wait for home `Party` to return before the next click.
- Web stats are not "the user's real phone". Do not fail a proof because HP does not match a physical device.
- Avatar studio is a large combinatorial UI; one slot change + home sprite update is enough unless the bug is studio-specific.
