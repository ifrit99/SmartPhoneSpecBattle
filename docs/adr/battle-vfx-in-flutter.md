# ADR: バトル演出は Effekseer を使わず Flutter の中で作る

- 日付: 2026-10-12
- 状態: Accepted（オーナー判断 2026-10-12。本 ADR は docs のみ。製品コードは変えない）
- 対象: `lib/presentation/battle/` と `lib/presentation/widgets/battle/` のバトル演出全般
- 関連: `docs/rfc_battle_animation.md`（演出の仕様の正本）、`docs/battle_vfx_guide.md`（演出ガイド）、`docs/battle_vfx_review_rubric.md`（レビュー基準）

## Context

- 本アプリは Flutter web を Cloudflare Pages で配信している。CSP は enforce 済み（hosting PR-3）。
- バトルの絵は SFC『FF6』風の約3頭身ドット（48×48 等倍、最近傍で整数倍）。立ち絵はアニメ塗りの大人のスマホ擬人化。背景・枠なし・グローなしの「静けさ」ルールがある（`docs/rfc_character_art.md` §4-1、`docs/rfc_battle_animation.md` §2-1）。
- 演出は RFC どおり実装済み。単一フレーム PNG の変形（移動・拡縮・色）と `CustomPainter` の小さな幾何パーティクルだけで作っている。新しい画像・動画・音・外部アニメライブラリは入れていない。
- 参考にできる資料として、オーナーから `kanaworksai-hue/effekseer-vfx-skill`（MIT）が示された。Effekseer 向けの VFX レシピ生成ツールだが、タイミング・重ね方・作り方・レビューの考え方が文章としてまとまっている。

## Decision

1. **Effekseer は使わない。** 導入も、`.efk` の再生も、依存の追加もしない。
   - Flutter web の Widget / `CustomPaint` の中で `.efk` を再生する手段がない。JS 版を別キャンバスで重ねる案は、依存・CSP・ドット絵との見た目の不整合が大きく、採らない。
   - 3頭身ドットの演出は「小さな幾何の粒・線・全画面の一瞬のフラッシュ」で足りる。3D 向けの大きなツールを持ち込む理由がない。
2. **考え方だけを参考にする。** 読むのは `skills/effekseer-vfx/references/` の `timing.md`・`layering.md`・`craft.md`・`review.md` と `skills/effekseer-vfx/assets/review_rubric.json` だけ。ツール固有の部分（Godot Lab、`vfx` コマンド、レシピ、テクスチャ、フラグ計算）は読まない・持ち込まない。
3. **言い換えて置く。** 丸写しはしない。SSB の 60fps・ドット絵・ログ駆動のビート構造に合わせて要約し、出典を一行で引く。出典表記は「(参考: effekseer-vfx-skill references/xxx.md)」の形。MIT の表示は本 ADR 末尾に 1 回置く。
4. **実装の入口は変えない。** 演出の仕様は引き続き `docs/rfc_battle_animation.md`。ガイドとレビュー基準はその補助で、実装は従来どおり grok-4.6 が小さい PR で行う。

### 比べた案

| 案 | 判断 | 理由 |
|---|---|---|
| Effekseer を導入する | 不採用 | Flutter web で再生できない。依存・CSP・見た目の不整合 |
| Rive / Lottie / Flame を入れる | 不採用（RFC §1 非ゴールのまま） | 新アセットの管理が増える。単一 PNG の変形で足りている |
| 今の `CustomPaint` + `ColorFiltered` + `Transform` を続け、考え方だけ外から取り込む | **採用** | 既存コードを活かせる。足りないのは道具ではなく「当たりの瞬間を一番強くする」「粒に緩急をつける」といった判断基準 |

## Consequence

- 演出の良し悪しを言葉で揃えられる（溜め・当たり・余韻、芯と本体、粒の緩急）。レビューで「なんとなく弱い」を「当たりのフレームが明るくない」のように指せる。
- `review_rubric.json` を削って直した表（`docs/battle_vfx_review_rubric.md`）で、自己採点ではなく別の人（またはレビュー席）が採点する流れを作れる。
- ツール由来の数値（フレーム範囲や比率）はそのまま使わず、SSB の実測で置き換える前提。ガイドの数値は「目安」で、ブラウザで見て直す。
- 新しい依存・アセットは増えないので、`pubspec.yaml`・`assets/`・CSP に変更はない。

## Out of scope

Effekseer 本体・JS 版の評価、画像や音の追加、演出の大幅な拡張（属性ごとの形、2段技）、製品コードの変更、マージ。

## 出典と表示

- 参考: [kanaworksai-hue/effekseer-vfx-skill](https://github.com/kanaworksai-hue/effekseer-vfx-skill) — `skills/effekseer-vfx/references/timing.md`・`layering.md`・`craft.md`・`review.md`、`skills/effekseer-vfx/assets/review_rubric.json`
- ライセンス: MIT License, Copyright (c) 2026 KanaWorks_AI。本リポの文書は上記の考え方を日本語で要約・言い換えたもので、原文やコードの複製は含まない。
