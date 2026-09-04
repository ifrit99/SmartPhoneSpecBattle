# Feature map — SmartPhoneSpecBattle (Flutter web)

Index for `verify-ssb`. Drive the **web UI** with **Mac Cursor Agent browser** (navigate, click, snapshot, screenshot). The user judges screenshots. Native android/ios exist but are not the drive path.

A proof that only opens one convenient screen is incomplete when the change touches another row.

| File | Player-facing feature | Primary arrival |
|---|---|---|
| [home.md](home.md) | Title → home hub (currency, cards, menus) | Cold start → `TAP TO START` ×2 → home |
| [character-status.md](character-status.md) | Character card, status screen, avatar, party | Home card / `見た目` / `Party` |
| [battle.md](battle.md) | CPU battle, tactics, support, skip, result | Home `バトル開始` |
| [gacha.md](gacha.md) | Emulate gacha + equip from inventory | Home `Gacha` / `Party` |
| [friend-battle.md](friend-battle.md) | URL share / paste / guest preview | Home `Friend` or `/?battle=` |

Also shipped, not seeded as top-level files (reach from home; expand when a change lands there): `Help` → `遊び方`, `Privacy`, `Backup` → `データ保護`, `Collection` tabs `敵キャラ図鑑` / `プレイヤー履歴` / `実績`.

Pixel-diff vs `master` is **not** this map. That is the separate merge-gate skill, and only when the user asks for it.
