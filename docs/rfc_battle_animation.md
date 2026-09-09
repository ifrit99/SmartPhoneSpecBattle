# RFC: バトル演出（スプライトアニメーション＋スキル VFX）

Created: 2026-09-09
Status: PROPOSED（`docs/rfc_portrait_screen_sweep.md` の実装後に着手。ユーザー判断待ち: §9）
Scope: 設計のみ。本RFCはプロダクトコード（Dart/Flutter）を変更しない。
Parent: `docs/rfc_character_art.md`（APPROVED）。同 §4-1「バトル画面の静けさ」のうち「アイドルアニメ・追加パーティクルは入れない」を、ユーザー受け入れ（2026-09-09「バトルに動きも技エフェクトもない」）に基づいて緩める。背景・枠なし・グローなしの原則は維持する。

---

## 0. 現状（master `83a1444`）

バトル画面 `lib/presentation/screens/battle_screen.dart` は、`BattleEngine.executeBattle` が返す `BattleResult.log`（`List<BattleLogEntry>`）を `_showNextLog()`（`:150-252`）が 1 件ずつ再生する **ログ駆動**である。演出は以下だけ。

| 演出 | 実装 | 備考 |
|---|---|---|
| 被弾シェイク | `_shakeController`（300ms, `Tween(0→8)`, `elasticIn`）を `Transform.translate` で X にだけ適用（`:74-80`, `:416-441`, `:452-470`） | 敵は +x、自は −x。被弾側の判定は `_displayedLog.last` を毎フレーム見る |
| フラッシュ | `_flashController`（200ms）を `forward().then(reverse)`（`:82-85`, `:204`） | **どのウィジェットにも束縛されておらず、何も描かない（デッドコード）** |
| ダメージ数値 | `DamagePopup`（`lib/presentation/widgets/damage_popup.dart`, 800ms、跳ねて上昇・フェード） | `Positioned` をランダム位置で `Stack` に積む（`:826-860`） |
| スキル発動 | `SkillEffectOverlay`（`lib/presentation/widgets/skill_effect_overlay.dart`, 1200ms） | 画面全体に属性色 20% のティント＋中央に「SKILL ACTIVATE / スキル名」のカード。`_skillEffectDelayMs`（1000/速度, 320–1000）だけログ再生を待たせる（`:863-882`） |
| 効果音 | `SoundService`（`lib/data/sound_service.dart`）: attack/defend/heal/skill/victory/defeat | BGM・SE それぞれミュート可（`:338-356`） |
| スプライト | `CharacterPortrait(variant: battle)` 48/96 論理 px 整数倍、`FilterQuality.none`（`character_portrait.dart:106-124`） | **単一フレーム PNG**（24 体 × 1 枚）。スプライトシートなし |

再生テンポ: `_logDelayMs = (800 / 速度).clamp(220, 800)`、速度は 1.0 / 1.5 / 2.0 / 3.0（`:59-60`, `:287-289`）。`_skipToEnd()`（`:254-273`）は全ログを即時反映する。

## 1. ゴール / 非ゴール

### ゴール
1. スプライトが**常に生きて見える**（アイドルの上下ボブ）。
2. 攻撃・スキル・被弾・回復・勝敗が、**スプライトの動き＋属性色の VFX** で音なしでも分かる。
3. 既存のログ駆動フローとテンポ（速度 ×1〜×3、スキップ）を壊さない。
4. Flutter Web 上で 60fps を保てる軽さ。**新しいスプライトシート・画像・動画・音を追加しない。** 全て既存の単一フレーム PNG の変形（移動・拡縮・色）と `CustomPainter` 描画で作る。
5. 参照様式は SFC 期 JRPG の戦闘演出（前に出て戻る、白点滅、画面フラッシュ、小さな幾何パーティクル）。

### 非ゴール
- 新規画像生成、複数フレームの歩行／攻撃モーション、Rive/Lottie/Flame の導入、動画。
- Android 固有 API、Firebase、Haptic。
- 効果音の追加・差し替え。
- `BattleEngine` のロジック・ログ文言の変更（§4 で `BattleLogEntry` に読み取り専用の派生情報を足すのみ）。

## 2. 演出語彙（全て単一フレームの再利用）

### 2-1. スプライトのステート

| ステート | 動き | 長さ | 発火 |
|---|---|---|---|
| **idle** | Y 方向 ±1 論理 px の正弦ボブ（48px 表示時。96px 表示時は ±2）。周期 1.6s。敵と自で位相を半周期ずらす | 常時ループ | 何もしていない間 |
| **attack (lunge)** | 相手方向へ 12% `charSize` 前進 → 戻る。行き 120ms `easeOut`、戻り 180ms `easeIn`。前進の頂点で被弾側の hit を開始 | 300ms | `actionType == attack`、または `skill` で `damage > 0` |
| **cast** | その場で Y −6% `charSize` に浮き、属性色に 40% ティント（`ColorFiltered` `srcATop`）。頂点で VFX 発火 | 360ms | `actionType == skill`（`damage` の有無に関わらず）、`defend`（回復あり） |
| **hit** | 白 100% ティント 2 回点滅（各 60ms on / 40ms off）＋ 既存シェイクの X ±8 を維持 | 300ms（既存と同じ） | `damage > 0` の被弾側 |
| **guard** | 6% `charSize` だけ後退し、属性色の細い縦長楕円（盾）を前面に 1 枚描く | 300ms | `actionType == defend`（回復なし） |
| **heal** | 緑（`0xFF00B894`、`DamagePopup` の回復色と同じ）の 30% ティント 1 回 + 上昇する小粒 6 個（§2-2 sparkle） | 500ms | `healing > 0` の対象側 |
| **victory** | 2 回ホップ（Y −10% → 0、各 200ms、`easeOut`/`bounceOut`） | 400ms ×2 | `_battleComplete && playerWon`（自）。敵は §2-1 defeat |
| **defeat** | 不透明度 1 → 0.35、Y +4% に沈み、彩度を落とす（`ColorFilter.matrix` グレースケール 60%） | 600ms | HP 0 になった側（`_battleComplete` 時） |

- ステートは排他。新しいステートが入ると現在のものを打ち切る。idle は他ステートの下で常に回し、`Transform.translate` を**加算**する（ボブが止まると死んで見えるため）。
- `flipHorizontal`（敵）は向きの反転だけで、lunge の進行方向は「相手側」に統一する（敵は −x、自は +x）。現行シェイクの符号と同じ考え方（`:427`, `:462`）。
- **静けさの維持**: スプライト自身に常時グロー・オーラ・台座は付けない。ティントは瞬間的（≤360ms）。

### 2-2. VFX（`CustomPainter`、画像なし）

全て属性色 `elementColor(element)`（`lib/presentation/theme/app_colors.dart`）でティントし、**アクター（術者）の属性**を使う。座標はターゲットスプライトの矩形中心を基準にする。

| VFX | 描画 | 長さ | 用途 |
|---|---|---|---|
| **flash** | フィールド全面（`_buildBattleField` の `Stack`）に属性色 alpha 0.35 → 0 を 1 回 | 160ms | スキル発動の頭。現 `SkillEffectOverlay` の 20% 常時ティントを置き換える |
| **slash** | ターゲット中心を通る太さ 3px の白い線分 2 本を、対角に 0 → 全長へ描いて消す。属性色の外縁 1px | 180ms | attack のヒット時 |
| **burst** | 中心から放射する 8–12 個の正方形粒（3–4 px、`FilterQuality.none` で角が立つ）。距離 0 → 0.6 `charSize`、alpha 1 → 0 | 320ms | 攻撃スキル（`damage > 0` の skill）のヒット時 |
| **ring** | 中心の円環、半径 0.3 → 0.8 `charSize`、線幅 2px、alpha 1 → 0 | 300ms | 自己バフ系スキル（`defend` 系 skill・`isSelfTarget`）と `guard` |
| **sparkle** | 6 個の小粒（2 px）がターゲット足元から上へ 0.5 `charSize` 上昇しながらフェード | 500ms | heal / regen |
| **crit** | `slash` を 2 本 → 3 本にし、`flash` を白 alpha 0.5 で 1 回追加。`DamagePopup` は既存のクリティカル表示のまま | slash と同時 | `isCritical` |

- 粒の数・寸法は `charSize` に比例させ、360×640（`charSize` 64.8 → 48px 表示）でも 430×932（77.4 → 48px 表示）でも比率が同じになるようにする。
- 属性ごとの**形の差は付けない**（v1）。色だけで属性を伝える。形の差（炎＝上昇粒、水＝波紋 …）は §9 の後続候補。
- 粒は `List<_Particle>` を `AnimationController` の値から**毎フレーム再計算**する（状態を持たない決定的な軌道）。乱数は VFX 開始時に 1 度シードして固定する。

### 2-3. `SkillEffectOverlay` の再定義

現行の全画面ティント＋中央カード（1200ms）は、フィールドを覆いスプライトの動きを隠す。以下に変える。

- ティントは §2-2 flash（160ms）に置き換え。
- スキル名カードは**フィールド上端の `TURN n` バッジの直下に小さく**（フォント 14、幅は文字に追従、背景黒 60%、属性色の 1px 枠）を 600ms 表示（fade in 80 / hold 400 / fade out 120）。「SKILL ACTIVATE」の英字行は削除。
- 敵の動きが見えるよう、カードはスプライト矩形と重ねない（バッジ直下の帯に限定）。

## 3. タイミング（ログ 1 件あたりの時間軸）

`_showNextLog` の 1 反復を **1 ビート**とし、その中で演出を並べる。`speed` は再生速度（1.0–3.0）。演出時間はすべて `/ speed` でスケールし、下限は各 ms の 40%。

```
t=0     ログをまだ表示しない。actor: attack→lunge / skill→cast / defend→guard or cast
t=0.4B  lunge の頂点（or cast の頂点）:
          - damage>0: target hit 開始、slash/burst、DamagePopup 生成、HP 反映、シェイク
          - healing>0: target heal、sparkle、DamagePopup(+)
          - バフのみ: ring
        ここで _displayedLog.add(entry)（ログ行が出る瞬間 = 数値が出る瞬間）
t=B     actor は idle に戻る。次のログへ（現行 _logDelayMs を待つ）
```

- **B（ビート長）**: attack = 300ms、skill = 360ms（flash 160 を頭に重ねる）、defend = 300ms、その他（ターン区切り・状態異常メッセージ）= 0。
- 現行の `_logDelayMs`（220–800ms）はビート**後**の待ちとしてそのまま残す。つまり 1 ログの総時間は `B/speed + _logDelayMs`。速度 ×1 で attack 1 件 = 300 + 800 = 1100ms（現行 800ms → 300ms 増）。
- 現行 `_skillEffectDelayMs`（320–1000ms）は廃止し、skill の B に統合する。速度 ×1 のスキル 1 件は 1000 + 800 = 1800ms → 360 + 800 = 1160ms と**短くなる**（スキルで待たされる感覚が減る）。
- `_playbackSpeed` ×3 のとき attack B = 100ms、lunge は 40/60ms。粒の生存も 1/3。ボブは速度に依存させない（等速）。
- **スキップ** `_skipToEnd()`: 進行中の演出コントローラを全て `stop()` → `reset()` し、粒を破棄。勝敗ステート（victory/defeat）だけ即時に最終状態で適用する。

### 3-1. ログエントリ → 演出の決定表

`BattleLogEntry`（`lib/domain/services/battle_engine.dart:44-65`）の既存フィールドだけで判定できる。

| 条件 | actor | target | VFX |
|---|---|---|---|
| `actionType == attack` | lunge | hit | slash（+crit） |
| `actionType == skill && damage > 0` | cast → lunge の後半のみ（前進 6%） | hit | flash + burst（+crit） |
| `actionType == skill && damage == 0 && healing > 0` | cast | heal（自分対象なら actor = target） | flash + sparkle |
| `actionType == skill && damage == 0 && healing == 0` | cast | — | flash + ring（actor 上） |
| `actionType == defend && healing > 0` | cast | heal | sparkle |
| `actionType == defend && healing == 0` | guard | — | ring（actor 上） |
| `actionType == null`（ターン区切り・状態異常の tick 文言等） | — | — | なし。**ただし `damage > 0` なら hit＋slash なしの被弾のみ**（毒等の継続ダメージを想定） |
| `_battleComplete` | 勝者 victory | 敗者 defeat | なし |

actor / target の判定は現行と同じ `entry.actorName == _currentPlayer.name || == widget.player.name`（`:180-182`, `:198-199`）を使う。**この名前一致は既存の弱点（同名キャラで誤判定）だが、本RFCでは変えない**。§9 参照。

## 4. 実装構造

3 層規約（`docs/architecture.md`）に沿い、presentation 内で完結させる。ドメインは触らない。

### 4-1. 新規
- `lib/presentation/widgets/battle/battle_sprite.dart` — `BattleSprite` StatefulWidget。`CharacterPortrait(variant: battle)` を子に持ち、§2-1 のステートを `AnimationController` 1 本＋`enum SpriteState` で表現する。外部 API:
  ```dart
  class BattleSpriteController extends ChangeNotifier {
    void play(SpriteState s);   // 排他で切替。完了で idle に戻る
    void stopAll();             // skip 用
    SpriteState get state;
  }
  ```
  `CharacterPortrait` 自体は変更しない（ティントは `ColorFiltered` で外側から包む）。Avatar Studio のアクセサリー／影レイヤー（`docs/rfc_portrait_screen_sweep.md` §3-5）は `CharacterPortrait` の battle 描画の内側にあるため、ボブ・lunge・ティント・反転はそのまま一緒に掛かる。`BattleSprite` 側で別扱いしない。
- `lib/presentation/widgets/battle/battle_vfx_layer.dart` — `BattleVfxLayer`。`Stack` に 1 枚だけ置く `CustomPaint`。`BattleVfxController.spawn(VfxKind kind, {Rect target, Color color, bool crit})` で §2-2 の VFX をキューに入れ、各 VFX は自分の `AnimationController` を持たず、**レイヤーの単一 `Ticker`** の経過時間で寿命を管理する（Web での Ticker 多重を避ける）。
- `lib/presentation/widgets/battle/skill_name_banner.dart` — §2-3 の小さなスキル名バナー。`SkillEffectOverlay` は削除する（呼び出しは `battle_screen.dart:863-882` のみ）。
- `lib/presentation/battle/battle_cue.dart` — **純関数** `BattleCue resolve(BattleLogEntry entry, {required bool isPlayerActor})` が §3-1 の表を返す（`actorState`, `targetState`, `vfxKinds`, `beatMs`）。Flutter 非依存にしてユニットテスト対象にする。

### 4-2. 変更
- `battle_screen.dart`
  - `_flashController` を削除（デッドコード）。シェイクは `BattleSprite` の hit に吸収し `_shakeController` も削除。`_displayedLog.last` を毎フレーム読む被弾判定（`:419-424`, `:455-459`）は不要になる。
  - `_showNextLog` の 1 反復を §3 のビートに置き換える。`await` の順序: `cue = resolve(entry)` → `actorSprite.play(cue.actorState)` → `Future.delayed(0.4B)` → 数値反映・`setState(_displayedLog.add)`・target/VFX → `Future.delayed(0.6B)` → `_logDelayMs`。
  - `_buildBattleField` の `Stack` に `BattleVfxLayer` を `..._popups` の**下**に 1 枚追加。ターゲット矩形は各 `BattleSprite` に `GlobalKey` を持たせ、`RenderBox.localToGlobal` をフィールド座標へ変換して取る。
  - `_skipToEnd` で `stopAll()` と `vfx.clear()` を呼ぶ。
  - `dispose` で新コントローラを破棄。
- `damage_popup.dart` は変更なし。

### 4-3. アクセシビリティ・ミュート
- 音に依存する情報はない（すべて視覚で並行表示）。逆に、`MediaQuery.disableAnimationsOf(context)` が true のときは lunge/cast/hit/VFX を**即時完了扱い**（0ms、最終状態のみ）にし、ボブも止める。数値・HP・ログ行は同じタイミングで出す。
- `SoundService` のミュート状態には演出を連動させない（ミュートでも動く）。

## 5. パフォーマンス（Flutter Web）

- 常時動くのは idle ボブ 2 体（`Transform.translate` のみ、リペイントはスプライト矩形だけ）。`RepaintBoundary` で `BattleSprite` を包み、ログリスト・HP バーを巻き込まない。
- VFX は 1 `CustomPaint`・1 `Ticker`。粒は最大 12 個 × 同時 2 VFX = 24 描画。`Paint` はレイヤーで 3 本を使い回し、`build` 内で生成しない。
- 画像の色変換は `ColorFiltered`（GPU）で行い、`Image` を再デコードしない。CanvasKit / skwasm どちらでも `ColorFilter.mode` と `ColorFilter.matrix` は対応済み。
- テキストシャドウ・`BoxShadow` の `blurRadius` は Web で高コスト。§2-3 のバナーでは既存カードの `blurRadius: 20` を持ち込まない（枠 1px のみ）。
- 検証: Chrome の Performance パネルでバトル 1 本（10 ターン程度）を記録し、フレーム落ちが 5% 未満、Long Task なし。360×640 DPR 2 と 430×932 DPR 3 で確認。

## 6. 受け入れ基準

1. 何もしていない間、敵・自スプライトが上下にボブしている（静止画に見えない）。
2. 通常攻撃で、攻撃側が前に出て戻り、被弾側が白く点滅してシェイクし、白いスラッシュとダメージ数値が**同じ瞬間**に出る。ログ行もその瞬間に追加される。
3. スキルで、術者が浮いて属性色に染まり、フィールドが属性色に一瞬フラッシュし、スキル名がターン表示の下に小さく出る。攻撃スキルなら被弾側に属性色の粒が飛ぶ。
4. 回復で、緑の粒が上昇し `+n` が出る。防御で盾のリングが出る。
5. クリティカルで、スラッシュが 3 本になり白フラッシュが追加される。
6. 勝利で自スプライトが 2 回ホップし、敗者側が沈んで薄くなる。敗北時は逆。
7. 速度 ×1〜×3 で演出が破綻せず（粒が残留しない、スプライトが変位したまま止まらない）、×3 でも数値と VFX の同期がずれない。
8. スキップで残留する演出がない。勝敗ステートだけ適用されている。
9. 音を両方ミュートしても 1–6 が全部分かる。
10. `MediaQuery.disableAnimations` 相当（OS の「視覚効果を減らす」）でボブ・移動・粒が出ず、数値・HP・ログのタイミングは変わらない。
11. スプライトは整数倍表示のまま（ボブ・lunge の移動量は論理 px の整数に丸め、`FilterQuality.none` を維持）。ぼけ・にじみがない。
12. 背景 `battle_bg.png` の見え方、HP バー・名前・TURN・ログのレイアウトは変わらない。

## 7. テスト方針（`flutter test`）

- `test/presentation/battle/battle_cue_test.dart`: §3-1 の決定表を全行、`isCritical`、`actionType == null && damage > 0` を含めて検証。
- `test/presentation/battle/battle_sprite_test.dart`（widget）: `play(attack)` 後 `pump(120ms)` で `Transform.translate` の x が正（自）/負（敵）、`pump(300ms)` で 0 に戻り state が idle。`stopAll()` で即時 idle。`disableAnimations: true` の `MediaQuery` 下で変位 0。
- `test/presentation/battle/battle_vfx_layer_test.dart`: `spawn` 後にペイントが行われ、寿命経過で粒リストが空になる（`CustomPainter.shouldRepaint` と `Ticker` を `tester.pump` で進める）。
- 既存 `battle_screen` 系テストが `SkillEffectOverlay` / `_flashController` に依存していれば置き換える（`rg SkillEffectOverlay test`）。
- **ゴールデン画像テストは入れない**（Web/CI でフォント差が出るため）。見た目は §6 の手動確認。

## 8. リスク

| リスク | 対策 |
|---|---|
| 演出でバトルが長くなり ×1 が退屈 | attack のビートは 300ms に抑え、スキル待ちは現行より短くなる（§3）。総時間は ×1 で 10 ターン 25s → 28s 程度。気になれば `_logDelayMs` の上限を 800 → 600 に下げる（別判断） |
| 名前一致による actor 誤判定（同名） | 既存の弱点で本RFC外。§9-2 |
| Web で `ColorFiltered` が毎フレーム再ラスタライズ | ティントは ≤360ms の瞬間だけ。idle 中は `ColorFiltered` を外す（ウィジェットツリーから除く） |
| 座標取得（`localToGlobal`）が最初のフレームで 0 | VFX の座標は `addPostFrameCallback` 後に確定した矩形を使い、未確定時はフィールド中心にフォールバック |
| 親RFC §4-1「アイドルアニメ・追加パーティクルは入れない」との矛盾 | 本RFC §0 で緩和を明記。背景・枠・グロー・台座なしは維持。親RFC本文は書き換えず、§4-1 に「演出は `docs/rfc_battle_animation.md` を優先」の 1 行を実装時に追記 |
| `SkillEffectOverlay` 削除で「スキル名が読めなくなった」 | §2-3 のバナー 600ms。読みにくければ hold を 400 → 600 に延ばす |

## 9. ユーザー判断が必要な点・後続候補

1. **演出の強さ**: 本RFCは「SFC 期の控えめな演出」を採る。もっと派手（画面全体の粒、スプライトの回転、ヒットストップ）にするかは実物を見てから判断で良い。まず v1 を出す。
2. **actor 判定の名前一致**（`battle_screen.dart:180-182`）: `BattleLogEntry` に `isPlayerActor: bool` を持たせれば確実になるが、`BattleEngine` の変更になるため本RFC外。演出の誤発火が出たら別タスクにする。
3. **属性ごとの VFX 形状**（炎＝上昇粒、水＝波紋、地＝落下岩片、風＝横切り線、光＝縦光線、闇＝収束粒）: v2 候補。色だけの v1 で不足なら追加。
4. **タイムライン方式への移行**: ログ 1 件 = 1 ビートで十分か。将来 2 段技（cast → 複数ヒット）が入るなら `BattleLogEntry` の構造化が先に要る。
