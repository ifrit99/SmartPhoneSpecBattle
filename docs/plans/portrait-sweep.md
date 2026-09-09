# Plan: portrait-sweep — 旧ドット絵の全画面一掃
Created: 2026-09-09
Status: PLANNING（Avatar Studio の方針は 2026-09-09 決定済み。着手可）
Parent: `docs/rfc_portrait_screen_sweep.md`（本ファイルは順序と検証の手引き。仕様の正本は RFC）
実装: grok-4.6。設計・レビューはこのファイルを書き換えず、RFC 側を直す。

## 要件
ユーザー受け入れ（2026-09-09）: プレバトル・リザルト等に 12×12 ドット絵が残っている。キャラを見せる全面で新ポートレート（bust/full/battle）に置き換える。

## PR の順序
**PR-A（Step 1–2: 置換）→ PR-A2（Step 3: Avatar Studio 移行）→ PR-B（`docs/plans/battle-animation.md`）**。A を先にする理由: B はバトル画面の `Stack` 構造を変えるが、A はバトル画面に触らない（コメント 1 行のみ）。A2 は `character_portrait.dart` の battle 描画を `Stack` にするので、B の `BattleSprite` がそれを包む前に入れておく。A → A2 → B の順で master に入れると競合しない。

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

### Step 3: Avatar Studio をバトルスプライトのカスタマイズへ移行（RFC §3-5）
Step 1–2 とは**別 PR（PR-A2）**にしてよい。A2 は `character_portrait.dart` の battle 描画に触るので、Step 1 の `square` とは競合しないが、PR-B（演出）より前にマージする。

| コミット | 内容 |
|---|---|
| h | `lib/domain/data/battle_sprite_anchors.dart`【新規】: `BattleAnchors(headTopY, chestY, shoulderY, centerX)` と `const Map<String, BattleAnchors>`、`anchorsFor(key)`（未登録は既定値）。値は 24 枚の `*_battle.png` を `magick identify -format '%@'`（トリム境界）で測って入れる。Flutter 非依存 |
| i | `character_portrait.dart` の `_buildBattlePortrait` を `Stack([Image.asset, CustomPaint(_BattleAccessoryPainter)])` に。painter は `character.accessoryIndex`（形）・`colorPaletteIndex`（色）・`auraIndex`（足元の影）を 48 グリッドで描き、`spriteSize / 48` を掛けて整数倍に乗せる。`accessoryIndex == 0` かつ `auraIndex == 0` なら `CustomPaint` を積まない。フォールバック（`PixelCharacter`）経路は変更しない |
| j | `avatar_customization.dart` に `visibleCustomizedCount`（palette/accessory/aura の 3 つだけ数える）を追加。既存メソッド・定数は無変更 |
| k | `avatar_studio_screen.dart`: プレビュー（`:195`）を `CharacterPortrait(variant: battle, height: 96)`、候補タイル（`:342`）を `CharacterPortrait(variant: battle, height: 48)` に。head/body/arm/leg の 4 行（`:86-111`）を削除。行順は アクセサリー → カラー（12 色スウォッチ、`accessoryIndex == 0` で無効表示）→ 影。ランダム（`:41-51`）は 3 スロットだけ振る。画面名・説明文を「バトルスプライトのカスタマイズ／バトル中の見た目」に。`import '../widgets/pixel_character.dart'` を削除 |
| l | `home_screen.dart:819` 付近の入口ラベルを「スプライト」に。`_applyAvatarCustomization` は変更なし（保存値の適用はそのまま） |

### 新規ファイル
- `lib/domain/data/battle_sprite_anchors.dart`（Step 3-h）。Step 1–2 は既存ファイルへの追記のみ。

## テスト基準
- [ ] `test/presentation/character_portrait_test.dart`: `square` の 2 件が通る。既存のフォールバック 3 件が無変更で通る。
- [ ] `test/presentation/character_screen_test.dart:95`（PNG 未出荷で `PixelCharacter` フォールバック）が無変更で通る。
- [ ] `rg "PixelCharacter\(" lib` の結果が `character_portrait.dart:127` だけになる。
- [ ] `rg "flipHorizontal" lib/presentation/screens` の結果が `battle_screen.dart` だけになる。
- [ ] `test/domain/battle_sprite_anchors_test.dart`（新規）: 24 キー全部で `anchorsFor` が 0–47 の範囲を返す。未登録キーは既定値。
- [ ] `test/presentation/character_portrait_test.dart` に追記: battle + `accessoryIndex: 3` で `CustomPaint` が 1 つある。battle + `accessoryIndex: 0, auraIndex: 0` で `CustomPaint` がない。bust / full では `accessoryIndex` を渡しても `CustomPaint` がない。
- [ ] `test/domain/avatar_customization_test.dart` に追記: `visibleCustomizedCount` が head/body/arm/leg を数えない。既存テストは無変更で通る。
- [ ] Avatar Studio widget テスト（新規 `test/presentation/avatar_studio_screen_test.dart`、360×640）: 初期表示で `find.byType(PixelCharacter)` が 0、`CharacterPortrait` の `variant == battle` が 1 つ以上。「頭」「体」「腕」「脚」のラベルが見つからない。アクセサリータイルをタップすると `saveAvatarCustomization` に 7 値のカンマ区切りが渡り、先頭 4 値が `-1`。
- [ ] `test/domain/character_codec_test.dart` が無変更で通る（accessory/palette/aura が v3 のまま相手に届く証明）。
- [ ] 図鑑テスト（新規 or 既存に追記）: 同じ `EnemyDeviceSpec` から 2 回生成した `Character` が同じ `PortraitId.key` を返す（seed/element が specs 決定であることの回帰ガード）。`test/domain/enemy_generator_test.dart` に 1 件。
- [ ] ブラウザ確認（`flutter run -d chrome`、360×640 と 430×932）: RFC §4 の 1–12 を順に見る。**Avatar Studio は開いた瞬間のメインプレビューが battle スプライトで、旧 12×12 がどこにも出ないこと**を最初に見る。Playwright は使わない（ユーザー依頼時のみ）。

## 完了条件
- [ ] `flutter analyze`: エラー 0、warning 0（unused_import を残さない）
- [ ] `flutter test`: 全パス
- [ ] `git diff --stat` に `character_codec*`・`character.dart`・`pubspec.yaml`・`assets/**` が**含まれない**。`lib/domain/**` の変更は `battle_sprite_anchors.dart`（新規）と `avatar_customization.dart`（ゲッター 1 つ追加）だけ
- [ ] PR 説明に RFC §4 の受け入れ 1–12 のチェック結果と、確認した 3 ペルソナ（archetype 0 / 1–3 を含む）を記載
- [ ] `docs/TODO.md` の「現在地」を portrait-sweep に更新

---
## Generator ログ
（実装時に追記）

---
## 評価
（レビュー結果を追記）
