# RFC: ポートレート全画面スイープ（旧ドット絵の残存を一掃する）

Created: 2026-09-09
Status: PROPOSED（Avatar Studio の方針は 2026-09-09 ユーザー決定済み → §3-5 / §6-1。残る判断は §6-3 のみ。`docs/plans/portrait-sweep.md` で実装）
Scope: 設計のみ。本RFCはプロダクトコード（Dart/Flutter）を変更しない。
Parent: `docs/rfc_character_art.md`（APPROVED）。本RFCは同 §4 / §6 の「残す・後回し」判定を、受け入れ結果に基づいて上書きする。

---

## 0. 背景

- PR #38 で 24 ペルソナ × {full, bust, battle} = 72 枚が `assets/images/characters/` に入り、`CharacterPortrait.shippedPortraitKeys` も 24 キー全てを載せている（`lib/presentation/widgets/character_portrait.dart:13-38`）。
- しかし `CharacterPortrait` へ置換済みなのは 5 箇所だけで、**リザルト・バトル前の敵プレビュー・編成・共有・ランキング等は 12×12 `PixelCharacter` のまま**。ユーザー受け入れ（2026-09-09）で「プレバトル／リザルトに旧イラストが残っている」として NG。
- 親RFC §4 は「リザルト等はスライス2」「32px 以下のミニアイコンは Pixel のまま」と段階化していたが、受け入れ基準は **「キャラを見せる面すべてで旧絵を出さない」** に変わった。本RFCはその基準に合わせて全箇所を一度に扱う。
- **ユーザー決定（2026-09-09）**: 旧 12×12 `PixelCharacter` を編集する Avatar Studio は**廃止**し、**新しいバトルピクセル（`*_battle.png` / `PortraitVariant.battle`）を対象にしたカスタマイズ**へ置き換える。旧ドット絵をユーザー向けの見せ場として残さない。→ §3-5 / §6-1。

## 1. ゴール / 非ゴール

### ゴール
1. ホーム・ガチャ・キャラ詳細・バトル準備（CPU敵プレビュー／ゲストプレビュー／支援コマンド選択）・バトル・リザルト・編成・共有・図鑑・ランキングの**全面で旧 12×12 ドット絵が見えない**。
2. 既存の `CharacterPortrait` / `PortraitId` を拡張して賄う。新しいアセット系統・新しいマニフェスト・新しい画像生成は増やさない。
3. `Character` / codec v3 / ガチャ JSON / 永続化は変更しない。

### 非ゴール
- バトル中のアニメーション・VFX（別RFC `docs/rfc_battle_animation.md`）。
- 新規画像生成、端末固有ポートレート、レアリティ枠の新デザイン（既存の枠色ロジックはそのまま使う）。
- `pixel_character.dart` の削除。読み込み失敗時のフォールバックとして残す（§5）。

## 2. 現状インベントリ（master `83a1444` 時点）

### 2-1. 置換済み（変更不要・回帰確認のみ）

| 画面 | 位置 | variant | 備考 |
|---|---|---|---|
| ホーム プレイヤーカード | `lib/presentation/screens/home_screen.dart:812` | bust | `charSize` = 幅22%・60–120 |
| バトル フィールド 敵 / 自 | `lib/presentation/screens/battle_screen.dart:433`, `:463` | battle | 敵は `flipHorizontal: true` |
| キャラ詳細 ヒーロー | `lib/presentation/screens/character_screen.dart:81` | full | ビューポート高さ 42% |
| ガチャ 単発結果 | `lib/presentation/screens/gacha_screen.dart:312` | full | 高さ 160 |

### 2-2. 旧絵が残っている箇所（本RFCの対象）

「面」欄はユーザー受け入れ基準の呼び名。`→` は置換後の variant と高さ。

| # | 面 | ファイル:行 | 現在 | → variant / 高さ | 補足 |
|---|---|---|---|---|---|
| S1 | リザルト（勝利／敗北） | `lib/presentation/screens/result_screen.dart:312` | Pixel 60（自） | **bust** 72 | 名前幅 80 の Column 内。bust 4:5 → 幅 57.6、収まる |
| S2 | リザルト | `lib/presentation/screens/result_screen.dart:333` | Pixel 60 flip（敵） | **bust** 72 | **反転しない**（§3-2） |
| S3 | バトル準備: CPU敵プレビュー | `lib/presentation/screens/home_screen.dart:2493` | Pixel `charSize` flip | **bust** `charSize`（幅18%・50–100） | Row 左端、右は `Expanded` テキスト。反転しない |
| S4 | バトル準備: ゲストプレビュー（自 vs 相手） | `lib/presentation/screens/qr_guest_preview_screen.dart:406` | Pixel 96 flip | **bust** 96 | 親 `SizedBox(height: 102)` を維持。親RFC §4 は full だったが、96px 高の全身では顔が約 12px になり VS 比較に向かないため bust に変更 |
| S5 | 共有: URL共有カード | `lib/presentation/screens/qr_display_screen.dart:220` | Pixel 70 | **bust** 70 | |
| S6 | 編成: 詳細シート | `lib/presentation/screens/inventory_screen.dart:135` | Pixel 100 | **full** 160 | ガチャ単発結果（S-済）と同じ寸法で統一 |
| S7 | 編成: グリッドカード | `lib/presentation/screens/inventory_screen.dart:776` | Pixel 52 | **bust** 52 | 既存のレアリティ枠色はカード側にあるので触らない |
| S8 | ガチャ: 10連リスト | `lib/presentation/screens/gacha_screen.dart:488` | Pixel 28（40px 円枠内） | **bust** 28 + `square: true`（§3-1） | 親RFC §6 の「Pixel のまま」を撤回 |
| S9 | ホーム: 戦闘力ランキング 自分行 | `lib/presentation/widgets/power_rating_card.dart:279` | Pixel 28 | **bust** 28 + `square: true` | 同上 |
| S10 | 図鑑: リーグ順位表 自分行 | `lib/presentation/screens/collection_screen.dart:808` | Pixel 24 | **bust** 24 + `square: true` | 同上 |
| S11 | 図鑑: 発見済み敵カード | `lib/presentation/screens/collection_screen.dart:154` | `Icons.smartphone` 48 | **bust** 48 | 旧ドット絵ではないが「キャラを見せる面」に該当。`Character` の導出は §3-3 |
| S12 | 図鑑: 未発見敵カード | `lib/presentation/screens/collection_screen.dart:195` | `Icons.smartphone` 48 を黒塗り | **bust** 48 を既存 `ColorFiltered(Colors.black, srcIn)` で黒塗り | 親RFC §4 スライス3 の「未発見=シルエット」 |
| S13 | Avatar Studio プレビュー | `lib/presentation/screens/avatar_studio_screen.dart:195` | Pixel 140 | **battle** 96（×2 整数倍）＋ §3-5 の薄いレイヤー | 画面の対象そのものを旧ドット絵 → バトルスプライトへ切り替える（§3-5） |
| S14 | Avatar Studio 候補タイル | `lib/presentation/screens/avatar_studio_screen.dart:342` | Pixel 56 | **battle** 48（×1）＋ 候補値を適用した薄いレイヤー | head/body/arm/leg/aura の行は削除（§3-5-2） |
| F | フォールバック | `lib/presentation/widgets/character_portrait.dart:127` | Pixel（読込失敗・未出荷時） | 残す（§5） | 24 キー全出荷のため通常経路では到達しない |

補助的な残骸（置換ではなく整理）:
- `lib/presentation/screens/battle_screen.dart:306` のコメント「12x12キャラの可読性を確保する」は事実と違う。`battle` スプライトに合わせて文言を直す。
- `lib/presentation/screens/home_screen.dart:2492` のコメント「ピクセルキャラクター（反転表示）」も同様。

上表以外に `PixelCharacter` を参照する Dart は `pixel_character.dart` 自身と `lib/domain/models/avatar_customization.dart:11`（コメントのみ）だけ（`rg PixelCharacter lib` で確認済み）。

## 3. 設計

### 3-1. `CharacterPortrait` の最小拡張: `square`

S8–S10 は 24–28px の円／丸角枠に入るアイコンで、現行 `bust` の `Image.asset(height:, fit: contain)` では 4:5 の縦長がそのまま出て枠に合わない。**新 variant は増やさず**、`bust` にオプション 1 つを足す。

```dart
/// true のとき height×height の正方形に切り、上寄せ cover で顔を残す（ミニアイコン用）。
/// bust 以外の variant では無視する。
final bool square;
```

- 実装: `variant == bust && square` のとき `SizedBox(width: height, height: height)` + `Image.asset(fit: BoxFit.cover, alignment: Alignment.topCenter)`。丸く切るのは呼び出し側の既存 `ClipOval` / 円形 `Container` に任せる（S8 は既に 40px の円形 `Container` の中）。
- bust は 384×480 で「上端から頭〜胸」（親RFC §5-2）なので、正方形上寄せ crop で顔が中央上部に残る。
- フォールバック（読込失敗）は従来どおり `PixelCharacter(size: height)`。
- `Semantics(label: character.name)` は現行のまま全 variant に付く。

`PortraitId` は変更なし。`shippedPortraitKeys` は変更なし。

### 3-2. bust / full は反転しない

現行の Pixel 呼び出しは敵側に `flipHorizontal: true` を渡している（S2・S3・S4）。立ち絵はアシンメトリな衣装・端末小物・髪型を持つため、鏡像にすると同一ペルソナがバトル画面と別人に見える。**`bust` / `full` では `flipHorizontal` を渡さない**。左右反転は `battle` スプライトだけの慣習として残す（親RFC §2-6）。

`CharacterPortrait` 側で禁止はしない（引数は残す）。呼び出し側の規約として `docs/coding_rules.md` に 1 行足す（実装スライスで）。

### 3-3. 図鑑の敵 `Character` 導出（S11・S12）

図鑑カードは `EnemyDeviceSpec` しか持たず `Character` がない。`EnemyGenerator.generateFromDeviceSpec(deviceSpec:, playerLevel:)`（`lib/domain/services/enemy_generator.dart:290`）が `CharacterGenerator.generate` を通すので、**seed は `generateSeed(specs)`、element は `elementFromOsVersion(specs.osVersion)` から決まり、レベルに依存しない**（`lib/domain/services/character_generator.dart:22-26`）。したがって

```dart
final portraitSource =
    EnemyGenerator.generateFromDeviceSpec(deviceSpec: device, playerLevel: 1).character;
CharacterPortrait(character: portraitSource, variant: PortraitVariant.bust, height: 48)
```

で、実際に戦った敵と同じポートレートが得られる。`levelOffset` に乱数が入るがステータスにしか効かない。

- 図鑑は 21 端末をグリッド表示するため、`build` 内で毎回 `generateFromDeviceSpec` を呼ばず、`State` 側で `Map<String /*deviceName*/, Character>` に 1 度だけ作る。
- 未発見（S12）は同じ bust を `ColorFiltered(ColorFilter.mode(Colors.black, BlendMode.srcIn))` で黒塗りにする（現行の `Icons.smartphone` に対する処理をそのまま流用）。シルエットからでも髪型で属性が推測できるのは意図どおり（発見の動機付け）。

### 3-4. 寸法・レイアウトの確認点

| 箇所 | 確認 |
|---|---|
| S1/S2 リザルト | `Row(spaceEvenly)` の 3 要素。bust 72 は幅 57.6。360 幅で `VS` と重ならない |
| S3 CPU敵プレビュー | bust 高さ `charSize` → 幅 0.8×。旧 Pixel は正方形だったので Row の左端が最大 20px 細くなる。`Expanded` 側が吸収 |
| S4 ゲストプレビュー | `SizedBox(height: 102)` の中に bust 96。幅 76.8。2 カラム比較で各カラム 160 前後あるので収まる |
| S7 編成グリッド | カード高さは `GridView` の `childAspectRatio` で固定。Pixel 52（正方）→ bust 52（幅 41.6）で高さ不変 |
| S8–S10 ミニアイコン | `square: true` で正方形を維持し、既存枠の寸法を変えない |
| S11/S12 図鑑 | `Icon(size: 48)` は 48×48。bust 48 は幅 38.4。`Spacer` 挟みの Column なので高さ不変 |

いずれも高さ基準の置換なので縦方向のオーバーフローは起きない。横方向は全箇所で細くなる方向。

### 3-5. Avatar Studio をバトルスプライトのカスタマイズにする（S13・S14）

前提となる事実:
- `AvatarCustomization`（`lib/domain/models/avatar_customization.dart`）の 7 スロットは `applyTo` で `Character` の `headIndex … auraIndex` に写され、`CharacterCodec` v3 はその 7 バイトを URL に載せる（`lib/domain/services/character_codec.dart:21-25`）。つまり **`colorPaletteIndex` / `accessoryIndex` / `auraIndex` は既に相手側へ届く**。
- battle スプライトは 24 体すべて 48×48 等倍・透過・「足元は下端から 2px 以内、本体高さ 40–46px、幅 24–32px、中央」の構図テンプレートで作られている（親RFC §5-1）。
- 新規画像は生成しない（本RFC非ゴール）。

**方針: 画像を差し替えるのではなく、`CharacterPortrait` の battle 描画に「薄いレイヤー」（アクセサリーのドット描画＋その色）を重ねる。** 描画は `CustomPainter` で 48×48 のグリッド座標に置き、表示側の整数倍拡大（×1/×2、`FilterQuality.none`）にそのまま乗せるので、スプライトと同じ格子・同じ様式に見える。

#### 3-5-1. スロットの再定義（モデル・codec・永続化は変更しない）

| 既存スロット | 新しい意味 | 選択肢 | 描画 |
|---|---|---|---|
| `accessoryIndex`（8, 0=なし） | **バトルスプライトのアクセサリー** | 1 リボン／2 バイザー／3 イヤーピース／4 胸バッジ／5 肩掛けストラップ／6 浮遊スラブ（横に小さく）／7 ヘアピン ×2 | 頭・胸・肩・横のアンカーに 2–6 px のドット図形。1px の暗色アウトラインを持ち、AA なし |
| `colorPaletteIndex`（12） | **アクセサリーの色** | 12 色（`elementColor` 6 色＋白・黒・金・銀・桃・青緑） | アクセサリー本体色。`accessoryIndex == 0` なら見えない |
| `auraIndex`（6, 0=なし） | **足元の影の形** | 1 楕円／2 細い楕円／3 リング／4 ひし形／5 二重楕円 | 足元 y=46–47 に 1 色（黒 40%）。親RFC §2-6「足元の小さな楕円影は任意（1色）」の範囲。**光るオーラにはしない** |
| `headIndex` / `bodyIndex` / `armIndex` / `legIndex` | **廃止（UI から消す）** | — | 描画に使わない。値は `Character` と codec v3 に残り、旧 URL のデコードも壊れない。`PixelCharacter` フォールバック時だけ従来どおり効く |

- 実装場所: `lib/presentation/widgets/character_portrait.dart` の `_buildBattlePortrait` を `Stack([Image.asset, CustomPaint(_BattleAccessoryPainter(character, spriteSize))])` にする。bust / full には**重ねない**（v1。§7 リスク参照）。
- アンカー: 24 体で頭頂・胸・肩の y が数 px ずれるため、`lib/domain/data/battle_sprite_anchors.dart`【新規】に `const Map<String /*PortraitId.key*/, BattleAnchors(headTopY, chestY, shoulderY, centerX)>` を置く。値は実装者が各 PNG のアルファ境界から 1 度測って定数化する（ImageMagick `-trim` の `%@` で取れる）。未登録キーは `BattleAnchors(headTopY: 6, chestY: 22, shoulderY: 16, centerX: 24)` を既定にする。Flutter 非依存の純データ。
- 敵側（`flipHorizontal: true`）はスプライトと一緒に反転される（`Transform` の内側に置く）。
- URL 対戦で受け取った相手の `accessoryIndex` 等はそのまま描く（codec 変更なしで相手のカスタマイズが見える）。

#### 3-5-2. Avatar Studio 画面の変更（`avatar_studio_screen.dart`）
- 画面名・説明文を「バトルスプライトのカスタマイズ」に変える。「ミニアイコン」「ドット絵の見た目」の文言は消す。
- プレビュー（S13）: `CharacterPortrait(variant: battle, height: 96)` を暗色パネル（既存の `#1B2838` カード）に置く。カード幅いっぱいの 140 にはしない（×2 の整数倍を守る）。隣に `bust` 48 を並べて「同じキャラ」を示すのは任意。
- 行の構成: **アクセサリー**（S14 タイル = battle 48 に候補を適用）→ **カラー**（12 色の正方スウォッチ。`accessoryIndex == 0` のときはタイルを無効表示）→ **影**（battle 48 に候補を適用）。head/body/arm/leg の 4 行は削除。
- 「おまかせ」（`unset`）・「ランダム」・「リセット」は残す。ランダムは 3 スロットだけを振る（`avatar_studio_screen.dart:41-51` を縮める）。
- 保存は現行どおり `toStorageString()`（7 値のカンマ区切り）。廃止 4 スロットは `unset` を書き続ける。
- ホームの入口（`home_screen.dart:819`）は残す。ラベルを「見た目」→「スプライト」に変える。

#### 3-5-3. `AvatarCustomization` の扱い
- クラス・7 フィールド・`toStorageString` / `fromStorageString` / `applyTo` は変更しない（永続化・codec 互換）。
- `headVariations` 等の定数はそのまま残す（`PixelCharacter` フォールバックと `test/domain/avatar_customization_test.dart` が参照）。
- `customizedCount` は UI で「n/3 設定済み」と表示したいので、廃止 4 スロットを除いた `visibleCustomizedCount` ゲッターを 1 つ足す（純関数、テスト 1 件）。

#### 3-5-4. やらないこと（v1）
- ペルソナ（archetype）の選択。`seed` を変えずに `PortraitId` を差し替えるには親RFC §7 の `portraitOverride`（codec v4、+1 byte）が要る。§6-3 でユーザー判断。
- bust / full へのアクセサリー描画。立ち絵の解像度・構図に合わせた別描画が必要で、v1 は battle のみ。
- スプライト本体の色替え（髪色・衣装色のパレットスワップ）。24 体のパレットを個別に知る必要があり、新アセットなしでは崩れる。

## 4. 受け入れ基準（ユーザー受け入れの再現手順）

すべて 360×640 と 430×932 で確認。**「旧絵」= 12×12 ドット絵と `Icons.smartphone` プレースホルダー**。

1. ホーム: プレイヤーカード（bust）、戦闘力ランキングの自分行（bust 正方 28）、CPU敵プレビュー（bust）に旧絵がない。
2. ガチャ: 単発結果（full）、10連リストの 10 行すべて（bust 正方 28）に旧絵がない。
3. キャラ詳細: ヒーロー（full）に旧絵がない。
4. バトル準備: CPU敵プレビュー（S3）・ゲストプレビューの自分／相手（S4）・URL共有カード（S5）に旧絵がない。支援コマンド選択（`battle_screen.dart:689`）は背後のフィールドに `battle` スプライトが出ていること。
5. バトル: 敵・自ともに `battle` スプライト。反転は敵のみ。
6. リザルト（勝利・敗北の両方）: 自・敵ともに bust 72、反転なし。
7. 編成: グリッド全カード（bust 52）、詳細シート（full 160）に旧絵がない。
8. 図鑑: 発見済み敵に bust 48、未発見敵に同じ bust の黒シルエット。リーグ順位表の自分行に bust 正方 24。
9. Avatar Studio: 開いた瞬間のメインプレビューが battle スプライト（96px、整数倍でくっきり）であり、**旧 12×12 がどこにも出ない**。アクセサリー／カラー／影を変えるとプレビューが即時に変わり、保存後にバトル画面の自スプライトに同じアクセサリーが出る。head/body/arm/leg の行がない。
10. 24 ペルソナのどれでも上記が成り立つ（`fire_0` だけでなく `dark_3` 等、archetype 1–3 を含めて最低 3 体で確認）。アクセサリーは 3 体で頭・胸・肩の位置がずれていない（`battle_sprite_anchors.dart` の検証）。
11. `rg "PixelCharacter\(" lib` の結果が `character_portrait.dart`（フォールバック）だけになる。
12. `?battle=` URL で受け取った相手のアクセサリー・色・影が、送信側のバトル画面と同じに見える（codec v3 の `accessoryIndex` 等がそのまま効く）。

## 5. `PixelCharacter` の残し方

- `lib/presentation/widgets/pixel_character.dart` は削除しない。`CharacterPortrait` の読込失敗フォールバック（`errorBuilder`）専用になる。
- 24 キー全出荷後は `resolveShippedKey` が null を返す経路はなく、フォールバックは「PNG が壊れている／ネットワーク失敗」時のみ。**受け入れ確認で旧絵が見えたらフォールバックが発火している＝アセット読込の不具合**として扱う（DevTools の Network で 404 を見る）。
- 将来フォールバックも中立なシルエット（`Icons.person` 相当）に置き換える案は、本RFCではやらない。

## 6. 決定事項と残る判断

### 6-1. Avatar Studio（S13・S14）— 決定済み（2026-09-09）
旧 12×12 `PixelCharacter` を編集する Avatar Studio は廃止し、バトルスプライトを対象にしたカスタマイズ（§3-5）に置き換える。以前ここにあった案 A（入口を隠す）／B（Pixel を 1 画面に残す）／C（削除）は採らない。旧ドット絵はユーザー向けの経路として残さず、`CharacterPortrait` の読込失敗フォールバック（§5）だけに限定する。

### 6-2. `docs/rfc_character_art.md` §4・§6 との整合
親RFC §6「32px 以下のミニアイコンは Pixel」「Avatar Studio の 7 スロットはミニアイコンに効く」を本RFCで撤回する。親RFC 本文は書き換えず、§0 冒頭に「ミニアイコンと Avatar Studio の扱いは `docs/rfc_portrait_screen_sweep.md` §3-1 / §3-5 が優先」の 1 行を実装スライスで追記する。親RFC §2-6 / §4-1 の「battle スプライトにグロー・オーラ・台座を焼き込まない」は維持する（§3-5 の影は 1 色・足元のみ、アクセサリーは本体に付く小物で、発光しない）。

### 6-3. ペルソナ（archetype）選択を Avatar Studio に足すか — ユーザー判断
§3-5 の薄いレイヤーでは、同属性の 4 ペルソナ（指揮官／エンジニア／フィールド／リサーチャー）を選び替えることはできない（`seed` 由来）。足すなら親RFC §7 の `portraitOverride`（codec v4、+1 byte、ガチャ JSON に `portraitOverride as int? ?? 0`）が必要で、URL 対戦の受け手がまだ v3 の場合は 0（自動）として読む。**v1 には含めない**。欲しければ `portrait-sweep` の後に別スライス（`docs/plans/portrait-override.md`）で扱う。

## 7. リスク

| リスク | 対策 |
|---|---|
| 28px の bust 正方 crop で顔が小さく判別しにくい | 親RFC §2-2 の「bust 48px で 24 体を判別できる」基準は 28px には要求しない。色（髪・キーカラー）で自分の行と分かればよい。受け入れ基準 1・2 は「旧絵が無い」ことだけを問う |
| 図鑑で 21 体分の `generateFromDeviceSpec` が重い | `State` で 1 回だけ生成（§3-3）。`CharacterGenerator.generate` は純計算で画像を触らない |
| 図鑑 bust 21 枚の同時ロードで Web 初回表示が遅い | 各 bust は ≤300KB（親RFC §5-1）。`Image.asset` は可視分から順にロードされ、グリッドは 2 列で最大 8 枚程度が同時表示。問題が出たら `cacheHeight: 96` を付ける |
| 反転をやめて S3 の敵が「右を向かない」 | 立ち絵は正面〜やや斜めなので向きの意味は薄い。バトルの向き慣習とは切り離す（§3-2） |
| `flutter test` の既存 widget テストが `PixelCharacter` を `find.byType` している | `test/presentation/character_portrait_test.dart` はフォールバック経路の検証なので影響なし。他の画面テストで `PixelCharacter` を探しているものがあれば `CharacterPortrait` に差し替える（実装スライスで `rg PixelCharacter test` を確認） |
| アクセサリーが 24 体の頭・胸・肩からずれる | `battle_sprite_anchors.dart` に 24 キー分の実測値を持つ（§3-5-1）。既定値で済む体は表に載せなくてよいが、受け入れ基準 10 で 3 体以上を目視 |
| アクセサリーがバトル（battle）にだけ出て、ホームの bust や詳細の full には出ない | v1 の割り切り（§3-5-4）。Avatar Studio の画面名を「バトルスプライトのカスタマイズ」とし、説明文で「バトル中の見た目」と明示する。bust/full 対応は別スライス候補 |
| 既存ユーザーの保存値（head/body/arm/leg）が無視される | 見た目への影響はフォールバック時のみ。データは消さず、Studio を開いても壊れない（`fromStorageString` は 7 値のまま）。リリースノートに 1 行 |
