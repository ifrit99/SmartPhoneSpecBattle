# Plan: battle-animation — スプライトアニメーション＋スキル VFX
Created: 2026-09-09
Status: IMPLEMENTING（master `8e048e83` / #42 から着手）
Parent: `docs/rfc_battle_animation.md`（仕様の正本。本ファイルは順序と検証の手引き）
実装: grok-4.6。

## 要件
ユーザー受け入れ（2026-09-09）: バトルにピクセルスプライトの動きも、技のエフェクトもない。既存の単一フレーム `*_battle.png` を再利用した動き（ボブ・突進・点滅・シェイク）と、属性色の軽量 VFX をログ再生に同期して入れる。新規画像・動画・音・外部アニメライブラリは追加しない。

## PR の分割
1 PR で出すが、コミットは以下の順で積む。各コミットで `flutter analyze` / `flutter test` を通す。途中コミットでも画面が壊れないよう、旧 `SkillEffectOverlay` の削除は最後にする。

| # | コミット | 内容 | 目安 |
|---|---|---|---|
| 1 | cue 純関数 | `lib/presentation/battle/battle_cue.dart` + `test/presentation/battle/battle_cue_test.dart`（RFC §3-1 の全行） | UI 変更なし |
| 2 | `BattleSprite` | `lib/presentation/widgets/battle/battle_sprite.dart`（idle/attack/cast/hit/guard/heal/victory/defeat、`BattleSpriteController`）+ widget テスト。まだ画面に載せない | UI 変更なし |
| 3 | 画面へ載せる（動きのみ） | `battle_screen.dart:433`/`:463` の `CharacterPortrait` を `BattleSprite` で包む。`_shakeController` と `_displayedLog.last` 参照の被弾判定（`:416-441`, `:452-470`）を削除し hit に置き換える。`_flashController`（`:63`, `:82-85`, `:112`, `:204`）を削除。`_showNextLog` を RFC §3 のビート構造に変更。`_skipToEnd` で `stopAll()` | ここで受け入れ 1・2・6・7・8 が見られる |
| 4 | `BattleVfxLayer` | `lib/presentation/widgets/battle/battle_vfx_layer.dart`（flash/slash/burst/ring/sparkle/crit、単一 Ticker）+ テスト。`_buildBattleField` の `Stack` に `..._popups` の下に追加。ターゲット矩形は `GlobalKey` → `localToGlobal` | 受け入れ 2–5 |
| 5 | スキル名バナー | `lib/presentation/widgets/battle/skill_name_banner.dart`。`_showSkillEffect`（`:863-882`）と `_skillEffectDelayMs`（`:288-289`）を削除し、`SkillEffectOverlay`（`lib/presentation/widgets/skill_effect_overlay.dart`）をファイルごと削除 | 受け入れ 3 |
| 6 | 減モーション対応 | `MediaQuery.disableAnimationsOf(context)` で全演出を即時完了・ボブ停止 | 受け入れ 10 |
| 7 | 文書 | `docs/rfc_character_art.md` §4-1 に「演出は `docs/rfc_battle_animation.md` を優先」を 1 行追記。`docs/TODO.md` 現在地更新。`docs/architecture.md` に `lib/presentation/battle/` と `widgets/battle/` を 1 行ずつ追加 | |

## 実装上の注意
- **座標**: VFX の中心は「スプライトの矩形中心」。`BattleSprite` に `GlobalKey` を持たせ、フィールドの `Stack` の `RenderBox` 座標系へ変換する。最初のフレームで取れないときはフィールド中心にフォールバック（RFC §8）。
- **整数 px**: ボブ・lunge の変位は `.roundToDouble()` で論理 px 整数に丸める。`FilterQuality.none` はそのまま `CharacterPortrait` が持つ。
- **速度スケール**: 全演出時間は `/ _playbackSpeed`、下限は 40%。ボブは速度非依存。
- **ティントの付け外し**: `ColorFiltered` は cast/hit/heal の間だけツリーに入れる。idle 中は素の `CharacterPortrait`（Web の再ラスタライズを避ける）。
- **Ticker**: `BattleVfxLayer` は `SingleTickerProviderStateMixin` の 1 本。VFX ごとに `AnimationController` を作らない。
- **既存 `battle_screen_test.dart`**（`test/presentation/battle_screen_test.dart:14`、背景・HUD・ログ導線の確認）は無変更で通ること。`pump()` 1 回で描けるよう、`BattleSprite` の初期フレームは変位 0・ティントなしにする。
- **actor 判定**は現行の名前一致（`battle_screen.dart:180-182`, `:198-199`）を変えない（RFC §9-2）。

## テスト基準
- [x] `battle_cue_test.dart`: RFC §3-1 の 8 行 + `isCritical` + `actionType == null && damage > 0`（継続ダメージ）を網羅。
- [x] `battle_sprite_test.dart`: attack で 120ms 時点の x 変位が自 > 0 / 敵 < 0、300ms で 0・idle。`stopAll()` 即時 idle。`disableAnimations: true` で変位 0。victory/defeat が最終状態で止まる（idle に戻らない）。
- [x] `battle_vfx_layer_test.dart`: `spawn` 後にペイントされ、寿命経過後に描画対象が空。`clear()` で即時空。
- [x] `battle_screen_test.dart` 既存 1 件が無変更で通る。
- [x] `rg "SkillEffectOverlay|_flashController|_shakeController|_skillEffectDelayMs" lib/presentation/screens/battle_screen.dart lib/presentation/widgets test` が 0 件（`gacha_screen.dart` の既存 `_shakeController` は対象外）。
- [ ] ブラウザ確認（`flutter run -d chrome`、360×640 DPR2 と 430×932 DPR3）: RFC §6 の 1–12。速度 ×1 と ×3 の両方で 1 バトル通す。スキップも 1 回。Chrome Performance で 10 ターンを記録し、フレーム落ち 5% 未満。Playwright は使わない。

## 完了条件
- [x] `flutter analyze`: エラー 0、warning 0
- [x] `flutter test`: 全パス
- [x] `git diff --stat` に `lib/domain/**`・`lib/data/**`・`pubspec.yaml`・`assets/**` が含まれない（音・画像・依存を増やしていない証明）
- [ ] PR 説明に RFC §6 の 1–12 のチェック結果、確認した速度、Performance の要約（平均フレーム時間）を記載
- [x] `docs/TODO.md` 現在地更新

---
## Generator ログ
- 2026-09-11 grok-4.6: commits 1–7（cue / BattleSprite / screen 配線 / VFX / バナー / disableAnimations / docs）。`flutter analyze` 0、`flutter test` 全パス。

---
## 評価
（レビュー結果を追記）
