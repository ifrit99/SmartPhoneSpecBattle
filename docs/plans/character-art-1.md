# Plan: character-art-1 — 指揮官6体（archetype 0）＋表示基盤
Created: 2026-09-03
Status: IN_PROGRESS

RFC `docs/rfc_character_art.md` §8–§9 の転記のみ。要件の追加なし。

## 要件
character-art-1。表示層の配線とフォールバック。アセット PNG は後続（参謀 / gpt-image-2）。本スライスでは偽画像を置かない。

## 仕様（RFC §8 転記）

- `lib/domain/models/portrait_id.dart`【新規】: `PortraitId.fromCharacter(Character)`、`key`、`fullAsset`/`bustAsset`/`battleAsset` パス。Flutter 非依存の純粋ロジック。
- `lib/presentation/widgets/character_portrait.dart`【新規】: `CharacterPortrait(character:, variant: PortraitVariant.bust|full|battle, height:, flipHorizontal:)`。`const Set<String> shippedPortraitKeys` をマニフェストとして持ち（Flutter はアセット列挙が煩雑なため明示）、解決順に従い `Image.asset`（`errorBuilder` で `PixelCharacter`）を返す。`battle` は `filterQuality: FilterQuality.none` で整数倍表示（§4-1）。`Semantics(label: character.name)` を付ける。
- 呼び出し側は `PixelCharacter(...)` を `CharacterPortrait(...)` に置換するだけ。ドメインサービスやストレージは触らない。

導出規則（RFC §7）: `archetype = character.seed.abs() % 4`、`key = '${character.element.name}_$archetype'`。解決順: 端末固有 override（後続）→ `{element}_{archetype}` → `{element}_0` → `PixelCharacter`。

## 第1スライス（RFC §9 転記）

**名称: character-art-1 — 指揮官6体（archetype 0）＋表示基盤**

含むもの:
1. アセット 18 ファイル: `fire_0`/`water_0`/`earth_0`/`wind_0`/`light_0`/`dark_0` × {full, bust, battle}（full/bust は QA ゲート A・B、battle はゲート C 通過済み）。`pubspec.yaml` 追記。
   - 本PRは配線のみのため PNG は置かない。`assets/images/characters/` を pubspec に追加し、空ディレクトリを用意する。
2. `portrait_id.dart` と `character_portrait.dart`（§8）。マニフェストは上記 6 キー。
3. 置換 4 箇所: バトル（敵・プレイヤー、**battle** ピクセルスプライト）、ホーム プレイヤーカード（bust）、ガチャ単発結果（full 高さ160）、キャラ詳細（full）。バトル開始時の `precacheImage`（battle 2 体分）。
4. テスト:
   - `portrait_id_test.dart`: 同一 seed → 同一 key、負の seed、6属性×4 の範囲、名前接頭語との一致（`_generateName` と同じ index になること）。
   - `character_portrait_test.dart`（widget）: マニフェスト外の key で `PixelCharacter` が描かれる／マニフェスト内で `Image` が使われる。
   - 既存 `character_codec_test.dart` が無変更で通ること（URL 互換の証明）。
5. ドキュメント: `docs/TODO.md` 現在地更新、`docs/product_spec.md` 2-1「外見」行と 6-1「キャラ描画」行を 1 行ずつ修正。

含まないもの: 残り 18 体、リザルト／編成／共有／ゲストプレビュー／図鑑の置換、レアリティ枠、端末固有画像、Avatar Studio の文言変更。

完了条件:
- [ ] `flutter analyze` エラー0 / `flutter test` 全パス
- [ ] ブラウザ確認: ホームで bust、バトルで `battle` ピクセルスプライトが表示され、`battle_bg.png` の見え方が変わらない（枠・発光なし）。スプライトが整数倍でくっきり表示される（ぼけ・にじみなし）
- [ ] 360×640 と 430×932 でバトルフィールドがオーバーフローしない
- [ ] `?battle=` URL で受け取った相手が、送信側と同じポートレートで表示される（seed/element 由来であることの確認）
- [ ] full/bust 12 画像が §2-4（成人設定の下限）と §2-5（画風・IP距離）、battle 6 画像が §2-6 ゲート C のチェックリストを通過（PR 説明にチェック結果を記載）
- [ ] 6 体を bust 48px に縮小して並べ、髪型・シルエット・キーカラーで互いに区別できる。各 battle スプライトが対応する bust と同一ペルソナと分かる

本PR（配線）での完了条件: analyze / test グリーン。ブラウザ確認・画像 QA はアセット出荷後。Playwright / マージは対象外。

---
## Generator ログ
- 配線のみ実装。PNG は置いていない（`assets/images/characters/` は空 + pubspec 登録）。
- `PortraitId.fromCharacter` / `key` / `fullAsset` / `bustAsset` / `battleAsset` と RFC §7 の `resolveShippedKey`。
- `CharacterPortrait`: マニフェスト 6 キー、欠落は PixelCharacter。battle は FilterQuality.none + 48/96 整数倍。`Semantics(label: character.name)`。
- 置換 4 箇所: バトル battle / ホーム bust / ガチャ単発 full 160 / キャラ詳細 full。バトル開始時に player/enemy の battle を `precacheImage`（欠落は onError で握り、クラッシュしない）。
- `flutter analyze`: No issues found。`flutter test`: All tests passed（+433）。

---
## 評価
（Evaluator が検証結果を追記）
