# Plan: portrait-sweep — 旧ドット絵の全画面一掃
Created: 2026-09-09
Status: PLANNING（`docs/rfc_portrait_screen_sweep.md` §6-1 のユーザー判断後に IN_PROGRESS）
Parent: `docs/rfc_portrait_screen_sweep.md`（本ファイルは順序と検証の手引き。仕様の正本は RFC）
実装: grok-4.6。設計・レビューはこのファイルを書き換えず、RFC 側を直す。

## 要件
ユーザー受け入れ（2026-09-09）: プレバトル・リザルト等に 12×12 ドット絵が残っている。キャラを見せる全面で新ポートレート（bust/full/battle）に置き換える。

## PR の順序
**PR-A（本計画）→ PR-B（`docs/plans/battle-animation.md`）**。A を先にする理由: B はバトル画面の `Stack` 構造を変えるが、A はバトル画面に触らない（コメント 1 行のみ）。A が master に入ってから B を切ると競合しない。

## 仕様（RFC 転記・順序付き）

### Step 1: `CharacterPortrait` に `square`（RFC §3-1）
- `lib/presentation/widgets/character_portrait.dart`: `final bool square` を追加（既定 false）。`variant == bust && square` のとき `SizedBox(width: height, height: height)` + `Image.asset(fit: BoxFit.cover, alignment: Alignment.topCenter)`。`errorBuilder` は従来どおり `PixelCharacter(size: height)`。
- テスト `test/presentation/character_portrait_test.dart` に 2 件追加: `square: true` で `SizedBox` が正方形、`Image.fit == BoxFit.cover`。`square: true` を full/battle に渡しても無視される。

### Step 2: 置換（RFC §2-2 の S1–S12）
コミットは画面単位で分ける（レビューしやすくする）。各コミット後に `flutter analyze`。

| コミット | 対象 | 置換 |
|---|---|---|
| a | `result_screen.dart:312`, `:333` | `CharacterPortrait(variant: bust, height: 72)`。`flipHorizontal` を渡さない |
| b | `home_screen.dart:2493`（CPU敵プレビュー） | bust `charSize`。反転なし。`:2492` のコメントも直す |
| c | `qr_guest_preview_screen.dart:406`, `qr_display_screen.dart:220` | bust 96 / bust 70。反転なし |
| d | `inventory_screen.dart:135`, `:776` | full 160 / bust 52 |
| e | `gacha_screen.dart:488`, `power_rating_card.dart:279`, `collection_screen.dart:808` | bust 28 / 28 / 24、すべて `square: true` |
| f | `collection_screen.dart:154`, `:195` | RFC §3-3。`State` に `late final Map<String, Character> _portraitSources` を作り、`EnemyGenerator.generateFromDeviceSpec(deviceSpec:, playerLevel: 1).character` を `initState` で 21 体分生成。発見済み = bust 48、未発見 = 同 bust を既存 `ColorFiltered` で黒塗り |
| g | `battle_screen.dart:306` コメント修正、`docs/rfc_character_art.md` §0 に「ミニアイコンの扱いは `docs/rfc_portrait_screen_sweep.md` §3-1 が優先」を 1 行追記、`docs/coding_rules.md` に「bust/full に `flipHorizontal` を渡さない」を 1 行追記 |

未使用になった `import '../widgets/pixel_character.dart'` は各ファイルで削除する（analyze が unused_import で拾う）。

### Step 3: Avatar Studio（RFC §6-1 の判断に従う）
- **A（既定）**: `home_screen.dart:818-` の `GestureDetector(onTap: _openAvatarStudio, ...)` を取り除く。`_openAvatarStudio` / `_applyAvatarCustomization` / `avatar_studio_screen.dart` / `avatar_customization.dart` / `test/domain/avatar_customization_test.dart` は**残す**（未使用メソッドの analyze 警告が出る場合は `// ignore: unused_element` ではなく、呼び出し元を残す最小の形にする。どちらも嫌なら `_openAvatarStudio` だけ削除し `_applyAvatarCustomization` は起動時適用のため残す）。
- B を選んだ場合: `avatar_studio_screen.dart:195` を bust 140 に。`:342` は Pixel のまま。

### 新規ファイル
なし（`square` は既存ファイルへの追記）。

## テスト基準
- [ ] `test/presentation/character_portrait_test.dart`: `square` の 2 件が通る。既存のフォールバック 3 件が無変更で通る。
- [ ] `test/presentation/character_screen_test.dart:95`（PNG 未出荷で `PixelCharacter` フォールバック）が無変更で通る。
- [ ] `rg "PixelCharacter\(" lib` の結果が `character_portrait.dart:127` と、案 B のときだけ `avatar_studio_screen.dart:342` になる。
- [ ] `rg "flipHorizontal" lib/presentation/screens` の結果が `battle_screen.dart` だけになる（案 A/B 共通）。
- [ ] 図鑑テスト（新規 or 既存に追記）: 同じ `EnemyDeviceSpec` から 2 回生成した `Character` が同じ `PortraitId.key` を返す（seed/element が specs 決定であることの回帰ガード）。`test/domain/enemy_generator_test.dart` に 1 件。
- [ ] ブラウザ確認（`flutter run -d chrome`、360×640 と 430×932）: RFC §4 の 1–11 を順に見る。Playwright は使わない（ユーザー依頼時のみ）。

## 完了条件
- [ ] `flutter analyze`: エラー 0、warning 0（unused_import を残さない）
- [ ] `flutter test`: 全パス
- [ ] `git diff --stat` に `lib/domain/**`（`enemy_generator_test` 以外）・`character_codec*`・`pubspec.yaml`・`assets/**` が**含まれない**
- [ ] PR 説明に RFC §4 の受け入れ 1–11 のチェック結果と、確認した 3 ペルソナ（archetype 0 / 1–3 を含む）を記載
- [ ] `docs/TODO.md` の「現在地」を portrait-sweep に更新

---
## Generator ログ
（実装時に追記）

---
## 評価
（レビュー結果を追記）
