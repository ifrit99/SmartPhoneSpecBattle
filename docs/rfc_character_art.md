# RFC: キャラクターグラフィック刷新（擬人化・成人女性キャラクター）

Created: 2026-09-03
Status: PROPOSED（ユーザー承認後、`docs/plans/character-art-1.md` を起点に実装）
Scope: 設計・要件のみ。本RFCはプロダクトコード（Dart/Flutter）を変更しない。

---

## 0. 背景と決定事項

- master には静かなバトル背景（PR #32 `assets/images/battle_bg.png`）とタイトル背景/OGP（PR #31）が入っている。**背景は承認済みで維持する。**
- キャラクターは現在も `PixelCharacter`（`lib/presentation/widgets/pixel_character.dart`）による 12×12 プロシージャルドット絵。見た目は `Character` の 7 インデックス（head/body/arm/leg/colorPalette/accessory/aura）＋ `element` で決まる。
- **ユーザー決定（2026-09-03）**: キャラクターグラフィックを「端末スペックを擬人化した成人女性キャラクター」を中心に刷新する。戦場をうるさくしない。

## 1. ゴール / 非ゴール

### ゴール
1. ホーム・バトル・ガチャ・詳細で、キャラクターが「擬人化された成人女性のイラスト」として表示される。
2. 既存のゲームループ、シード決定性、6属性、ガチャレアリティ、URL対戦エンコード（`CharacterCodec` v3）を**変更しない**。
3. 最終アセットを本RFC執筆者が描かずに、後続の実装者（Cloud Agent）＋画像生成（gpt-image-2 等）だけで完結できる。
4. 薄い第1スライスで PR できる（§9）。

### 非ゴール（本RFCで扱わない）
- Android、F6/Firebase、F4 残りのホーム分割、課金、オンデマンド生成、API 従量課金。
- タイトル画面へのキャラ追加、動的OGP（F8）、Live2D/アニメーション立ち絵。
- 12×12 ドット絵システムの削除（§6 のとおり残す）。

## 2. アートディレクション

### 2-1. 「擬人化」の定義
- 1キャラ = 1台の（架空の）スマートフォンの**人格化**。人型の身体を持つ成人女性で、端末そのものの形はしない（身体が長方形・画面が顔、はNG）。
- 端末らしさは**衣装と持ち物**で表す: 携行する「端末」（ホログラムスラブ／バイザー／リストターミナルのいずれか1つ）＋ 端末由来のディテール 1〜2点（カメラレンズ状のブローチ、画面発光のパイピング、ノッチ形の髪飾り、SIMトレイ状のバックル等）。
- 属性・スペックは「職能とモチーフ」に写像する（§2-3）。

### 2-2. 画風
- セミリアル寄りのアニメ調イラスト。セルシェード＋ソフトライト、輪郭線は細め。
- 背景なし（透過PNG）。**リムライトは寒色（青〜紫）**に統一し、夜景ネオンの背景に馴染ませる。キャラ自体に枠・光輪・エフェクトは焼き込まない（演出はUI側で必要時に重ねる）。
- 全身画は正面〜やや斜め、直立または軽いコントラポスト。表情は自信・落ち着き・知性のいずれか。
- 24キャラ（§3）で肌色・髪型・体格・年齢感（25〜45歳）をばらけさせ、同顔を避ける。

### 2-3. 属性 → 職能・キーカラー・モチーフ

キーカラーは `elementColor()`（`lib/presentation/theme/app_colors.dart`）と一致させる。

| 属性 | キーカラー | 職能（衣装の系統） | モチーフ |
|------|-----------|------------------|---------|
| 炎 fire | `#FF6B6B` | 熱設計／オーバークロック技師（耐熱ジャケット） | ヒートシンクのフィン、熱の揺らぎ |
| 水 water | `#74B9FF` | 冷却／流体制御（ガラス質のコート） | 液冷チューブ、水面反射 |
| 地 earth | `#FDCB6E` | ストレージ／アーカイブ管理官（金属板の装甲コート） | 金庫、積層プレート |
| 風 wind | `#55EFC4` | 通信／ネットワーク（軽量フライトウェア） | アンテナ、信号の弧 |
| 光 light | `#FFF176` | ディスプレイ／カメラ（白基調の制服） | レンズフレア、発光パネル |
| 闇 dark | `#AB47BC` | セキュリティ／暗号（ダークテーラード） | 錠前、暗号パターン |

スペック→衣装の対応（CPU→ガントレット/工具、RAM→コートのボリューム、ストレージ→ケース/シールド、バッテリー→ブーツの光線）は**プロンプトのヒントとしてのみ**使い、v1 では画像を機械的に変化させない。

### 2-4. 成人表現の必須要件（QAゲート）
すべての画像は生成後に以下を確認し、**1つでもNGなら再生成**する。
1. 7〜7.5頭身。顔は成人の骨格（顎のライン、目の縦幅は顔の1/5以下）。年齢感 25〜45歳。
2. 衣装は職業服・テックウェア・テーラード。**禁止**: 学生服／セーラー襟／ランドセル／大きなリボン付きツインテール／幼児的な丸顔・大きすぎる瞳。
3. 一般向け表現。**禁止**: 下着・水着・過度な露出、性的なポーズや構図。
4. 実在ブランドロゴ、実在人物の顔を含まない。
5. 背景が透過されている（縁のフリンジがない）。
6. 構図テンプレート（§5-2）を満たす。
7. リムライトが寒色で、キャラ自身に発光エフェクトが焼き込まれていない。

## 3. ユニーク枚数と生成バリエーション

### 3-1. 方針: 「6属性 × 4アーキタイプ = 24 ペルソナ」の固定ロスター
- 現行の 691,200 通りのドット絵組み合わせを画像で再現することはしない（不可能かつ不要）。
- 既存の名前生成（`CharacterGenerator._generateName`）は `prefix = prefixes[element][seed.abs() % 4]` で属性別4接頭語を選ぶ。**この接頭語をペルソナ名として採用**し、`archetype = seed.abs() % 4` でポートレートを決める。名前の接尾語（ナイト／ガーディアン／…／キング）は肩書きとして扱い、画像には反映しない。

| 属性 \ archetype | 0: 指揮官 | 1: エンジニア | 2: フィールド | 3: リサーチャー |
|---|---|---|---|---|
| 炎 | フレア | イグニス | ブレイズ | バーン |
| 水 | アクア | ウェイブ | タイダル | リップル |
| 地 | テラ | ロック | ガイア | グランド |
| 風 | ゼファー | ブリーズ | ストーム | ガスト |
| 光 | ルミナ | レイ | シャイン | グロウ |
| 闇 | シャドウ | ノクス | ダスク | ヴォイド |

archetype の役柄（指揮官／エンジニア／フィールド／リサーチャー）は属性をまたいで共通にし、6×4 のグリッドとして一貫させる。

### 3-2. バリエーションの表現（画像を増やさない）
- **レアリティ**: 画像を変えない。カード系UI（ガチャ結果・編成・詳細）だけで枠を変える。N/R=枠なし、SR=銀の細枠、SSR=金枠＋既存オーラ演出（任意）。**バトル画面には枠を出さない。**
- **colorPaletteIndex / accessoryIndex / auraIndex**: ポートレートには使わない（ドット絵ミニアイコンのみで有効）。
- **端末固有ポートレート**（後続スライス）: ガチャカタログ（`gacha_device_catalog.dart`、21端末）の SSR から順に専用画像を追加できる。マッピングは端末スペックから `CharacterGenerator.generateSeed` で得られるシードをキーにした `seed → portraitKey` の逆引き表で行い、**モデル・永続化・URLの変更なし**で実現する。

### 3-3. 却下した代替案
- レイヤー合成（体・髪・衣装を別PNGで重ねる）: 生成画像同士の位置合わせが困難。v1 では不採用。
- 全キャラ固有画像（スペック単位）: 枚数が発散する。
- ドット絵の完全撤廃: Avatar Studio（691,200通り）を無価値にする。ミニアイコンとして残す（§6）。

## 4. 表示箇所と表示形態

| 画面 / 箇所 | 現在 | 刷新後 | スライス |
|---|---|---|---|
| タイトル | キャラなし | 変更なし（背景維持） | — |
| ホーム プレイヤーカード | Pixel 60–120 | **bust**（上半身） | 1 |
| バトル フィールド | Pixel 50–100 | **bust**、位置・シェイク・左右反転は現行踏襲、枠・発光なし | 1 |
| ガチャ 単発結果 | Pixel 80 | **full**（全身）高さ 160 | 1 |
| キャラ詳細（`character_screen.dart`） | Pixel 100–200 | **full** | 1 |
| リザルト | Pixel 60 | bust 高さ 72 | 2 |
| 編成 詳細シート / グリッド | Pixel 100 / 52 | full / bust（グリッドはレアリティ枠） | 2 |
| URL共有カード / ゲストプレビュー | Pixel 70 / 96 | bust / full | 2 |
| ホーム CPU敵プレビュー | Pixel 50–100 | bust | 2 |
| 図鑑（敵キャラ） | `Icons.smartphone` 48 | 発見済み=bust 48、未発見=シルエット（同画像を黒塗り） | 3 |
| ガチャ 10連リスト / 戦闘力ランキング / リーグ順位表 | Pixel 28 / 28 / 24 | **Pixel のまま**（§6） | — |
| Avatar Studio | Pixel 140 / 56 | Pixel のまま。説明文を「ミニアイコンの見た目」に修正 | 2 |

### 4-1. バトル画面の「静けさ」ルール
- 追加するのはポートレート画像の差し替えのみ。枠・グロー・台座・アイドルアニメ・追加パーティクルは入れない。
- 背景 `battle_bg.png` とその表示方法（cover・上寄せ）は変更しない。
- サイズ: 各ハーフ（敵／プレイヤー）の利用可能高さから既存 `enemySpriteTopPadding` を差し引いた値を上限に、bust 高さ = clamp(90, 140)、幅 = 高さ × 0.8。360×640〜430×932 の viewport でオーバーフローしないこと。
- HP バー・名前・TURN 表示・ダメージポップアップのレイアウトは変更しない。

## 5. アセットパイプライン

### 5-1. ファイルと命名
```
assets/images/characters/
  {element}_{archetype}_full.png   # 512×768 (2:3)  例: fire_0_full.png
  {element}_{archetype}_bust.png   # 384×480 (4:5)  例: fire_0_bust.png
```
- `element` は `ElementType.name`（fire/water/earth/wind/light/dark）、`archetype` は 0–3。
- 端末固有画像（スライス3以降）は `device_{slug}_full.png` / `_bust.png`（slug は英小文字・ハイフン。例 `device_stellar-s25-ultra`）。
- `pubspec.yaml` に `assets/images/characters/` を追加。既存の空ディレクトリ `assets/characters/{heads,bodies,arms,legs}/` は未使用のまま触らない（別タスク候補）。
- 1ファイル ≤ 300KB（`pngquant --quality 80-100` または `oxipng -o4`）。Flutter Web はアセットを使用時に取得するため初回ロードには乗らない。バトル開始時に対戦2体分を `precacheImage` する。

### 5-2. 生成マスターと構図テンプレート
- 生成サイズ 1024×1536（gpt-image-2 の縦長）。透過背景で出力、できない場合は単色背景→切り抜き。
- 構図（マスターの高さに対する位置）: 頭頂 6〜10%、目 16〜19%、顎 28〜31%、腰 52〜56%、足元 94〜97%。左右中央。
- `full` = マスターを 512×768 に縮小。`bust` = マスターの上端から高さ 40%（y 0〜40%）、幅は中央 48%（4:5 を保つ）を切り出し 384×480 に縮小。構図が外れた画像は**画像側を再生成**し、切り出し座標をコードで個別対応しない。

```bash
# 例（ImageMagick）: master.png → full / bust
magick master.png -resize 512x768 fire_0_full.png
magick master.png -gravity North -crop 48%x40%+0+0 +repage -resize 384x480 fire_0_bust.png
```

### 5-3. プロンプトテンプレート（実装者が各IDで埋める）
```
Full-body illustration of an adult woman in her {late 20s|30s|40s}, {archetype role},
personification of a fictional smartphone. Semi-realistic anime style, cel shading with
soft lighting, thin line art, cool blue-violet rim light, transparent background,
front-facing standing pose, centered, feet visible, head at top 8% of frame.
Outfit: {element outfit family from §2-3} with {1-2 phone-derived details}. Key color {hex}.
Carrying a {holographic slab|visor|wrist terminal}. Mature facial structure, 7 to 7.5 heads tall,
calm confident expression. {skin tone / hair / build for variety}.
Negative: child, teen, school uniform, sailor collar, oversized ribbons, chibi, big round eyes,
swimsuit, underwear, suggestive pose, logo, text, watermark, background scenery, glow effects.
```
- 使用したプロンプト・採用/却下の理由は実装時の計画ファイル（`docs/plans/character-art-N.md`）の Generator ログに ID ごとに残す。

## 6. 12×12 CustomPaint（`PixelCharacter`）の扱い

- **残す。役割を「ミニアイコン」と「フォールバック」に限定する。**
  - ミニアイコン: 32px 以下の密なリスト（ガチャ10連、戦闘力ランキング、リーグ順位表）は引き続き `PixelCharacter`。Avatar Studio の 7 スロットはこのミニアイコンに効く。
  - フォールバック: 該当 ID のアセットがマニフェストに無い、または読み込みに失敗した場合は `PixelCharacter` を同サイズで描く。
- `pixel_character.dart` の描画ロジックは変更しない。

## 7. データモデル・シード・URL への影響

- **変更なし（スライス1〜3）**: `Character` / `GachaCharacter` / `CharacterCodec` v3 / `avatar.customization` / ガチャ JSON はそのまま。ポートレート ID は `element` と `seed` から**表示時に導出**するため、URL の受け手も同じ画像を解決できる。
- 導出規則（純関数・テスト対象）:
  - `archetype = character.seed.abs() % 4`（名前接頭語と同じ式）
  - `key = '${character.element.name}_$archetype'`
  - 解決順: 端末固有 `seed → key` 逆引き（スライス3以降） → `{element}_{archetype}` → `{element}_0`（同属性の指揮官で代替） → `PixelCharacter`
- 既存ユーザーの見た目が変わるのは意図した変更（Avatar Studio 導入時の頭部形状変更と同じ扱い）。
- **将来 ID を選べるようにする場合（スライス4・任意）**: `AvatarCustomization` に 8 スロット目 `portraitOverride`（0=自動、1〜4=archetype 指定）を追加し、`CharacterCodec` を v4 化（+1 byte、v3 デコード時は 0）、ガチャ JSON に `portraitOverride`（`as int? ?? 0`）を追加する。**本RFCの範囲では行わない。**

## 8. 実装構造（3層）

- `lib/domain/models/portrait_id.dart`【新規】: `PortraitId.fromCharacter(Character)`、`key`、`fullAsset`/`bustAsset` パス。Flutter 非依存の純粋ロジック。
- `lib/presentation/widgets/character_portrait.dart`【新規】: `CharacterPortrait(character:, variant: PortraitVariant.bust|full, height:, flipHorizontal:)`。`const Set<String> shippedPortraitKeys` をマニフェストとして持ち（Flutter はアセット列挙が煩雑なため明示）、解決順に従い `Image.asset`（`errorBuilder` で `PixelCharacter`）を返す。`Semantics(label: character.name)` を付ける。
- 呼び出し側は `PixelCharacter(...)` を `CharacterPortrait(...)` に置換するだけ。ドメインサービスやストレージは触らない。

## 9. 第1スライス（`docs/plans/character-art-1.md` として計画 → 実装 PR）

**名称: character-art-1 — 指揮官6体（archetype 0）＋表示基盤**

含むもの:
1. アセット 12 ファイル: `fire_0`/`water_0`/`earth_0`/`wind_0`/`light_0`/`dark_0` × {full, bust}（§2-4 の QA ゲート通過済み）。`pubspec.yaml` 追記。
2. `portrait_id.dart` と `character_portrait.dart`（§8）。マニフェストは上記 6 キー。
3. 置換 4 箇所: バトル（敵・プレイヤー、bust）、ホーム プレイヤーカード（bust）、ガチャ単発結果（full 高さ160）、キャラ詳細（full）。バトル開始時の `precacheImage`。
4. テスト:
   - `portrait_id_test.dart`: 同一 seed → 同一 key、負の seed、6属性×4 の範囲、名前接頭語との一致（`_generateName` と同じ index になること）。
   - `character_portrait_test.dart`（widget）: マニフェスト外の key で `PixelCharacter` が描かれる／マニフェスト内で `Image` が使われる。
   - 既存 `character_codec_test.dart` が無変更で通ること（URL 互換の証明）。
5. ドキュメント: `docs/TODO.md` 現在地更新、`docs/product_spec.md` 2-1「外見」行と 6-1「キャラ描画」行を 1 行ずつ修正。

含まないもの: 残り 18 体、リザルト／編成／共有／ゲストプレビュー／図鑑の置換、レアリティ枠、端末固有画像、Avatar Studio の文言変更。

完了条件:
- [ ] `flutter analyze` エラー0 / `flutter test` 全パス
- [ ] ブラウザ確認: ホーム→バトルで 6 属性いずれかの bust が表示され、`battle_bg.png` の見え方が変わらない（枠・発光なし）
- [ ] 360×640 と 430×932 でバトルフィールドがオーバーフローしない
- [ ] `?battle=` URL で受け取った相手が、送信側と同じポートレートで表示される（seed/element 由来であることの確認）
- [ ] 6 画像すべてが §2-4 チェックリストを通過（PR 説明にチェック結果を記載）

### 後続スライス（順序の目安）
- **character-art-2**: 残り 18 体、表示箇所の残り（§4 スライス2）、レアリティ枠、Avatar Studio 文言。
- **character-art-3**: 図鑑（発見済み/シルエット）、SSR 端末固有画像（7体）と `seed → key` 逆引き。
- **character-art-4（任意）**: `portraitOverride`（codec v4 移行、§7）。

## 10. リスクと対策

| リスク | 対策 |
|---|---|
| 生成画像の年齢感・構図のばらつき | §2-4 ゲートと §5-2 テンプレートで画像側を再生成。コードで吸収しない |
| 画像生成の残量不足 | スライス1は 6 枚に限定。不足時は `{element}_0` へのフォールバックで部分出荷可能 |
| バトルのレイアウト崩れ | bust を既存アンカーに収め、2 viewport で確認を完了条件に含める |
| ドット絵とイラストの混在感 | 混在は 32px 以下のミニアイコンに限定し、同一画面で同キャラを両形態で並べない |
| 既存ユーザーの見た目変更への戸惑い | リリースノートに 1 行記載。データ移行は不要 |

## 11. 承認を求める判断点
1. archetype の役柄（指揮官／エンジニア／フィールド／リサーチャー）と、名前接頭語＝ペルソナ名の対応（§3-1）。
2. バトルは bust（上半身）で進める。全身立ち絵のためのフィールド再レイアウトはスライス1の結果を見て別途判断。
3. SSR 端末固有画像を 7 体まで用意する予算（スライス3）。
