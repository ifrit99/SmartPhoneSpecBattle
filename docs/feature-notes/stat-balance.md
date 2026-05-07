# 機能メモ: ステータスバランス

## 機能の目的
デバイススペック（CPUコア数・RAM・ストレージ・画面解像度・OSバージョン等）から、一意かつ「納得感のある強さ」を持つキャラクターを生成する。
実デバイス＝実力（プレイヤー）と、ガチャ（仮想スペック）＝成長要素の両軸でバランスが取れている必要がある。

## 現状の理解
- 生成は `CharacterGenerator.generate(DeviceSpecs, experience)` が担当。
- **シード**: CPUコア数・RAM(MB)・ストレージ空き(GB)・画面幅/高さ・OSバージョンを連結→`hashCode` で決定。同スペック＝同キャラ。
- **属性**: `elementFromOsVersion(osVersion)` で決まる（OS系統が属性を決める仕組み）。
- **基礎ステータス**: `_calculateBaseStats` でスペック→数値化。内部にランダム要素あり（シード固定なので再現可）。
- **見た目**: 頭/胴/腕/脚/カラーの5要素を `random.nextInt` で決定（4要素は8通り、カラーは6通り）。
- **名前**: `_generateName(element, seed)` で属性+シードから生成。
- **レベル成長**: `Experience` から `currentStats = baseStats.levelUp(level)` で反映。
- **ガチャキャラ**: `GachaCharacter` はレアリティ付き。`gacha_service.dart` が排出テーブルを持つ（詳細は未確認）。

## 関連しそうなファイルや処理
- `lib/domain/services/character_generator.dart` — 生成ロジック本体
- `lib/domain/services/enemy_generator.dart` — CPU敵生成（架空ブランド名、PR #13）
- `lib/domain/services/gacha_service.dart` — ガチャ排出
- `lib/domain/services/experience_service.dart` — 経験値→レベル変換
- `lib/domain/models/stats.dart` — `levelUp` による成長計算
- `lib/domain/models/character.dart` — キャラ保持・状態更新
- `lib/data/device_info_service.dart` — スペック取得（Web/Native分岐）
- `docs/device_info.md` — プラットフォーム別取得可否

## 今後見直しそうな点
- Web環境ではバッテリー情報が取得できないため削除済み。他のWeb未取得スペック（CPUコア数等）でバランスが偏っていないかは未確認（仮置き）。
- シードが `String.hashCode` 依存のため、分布の偏りや衝突率は未検証。
- `_calculateBaseStats` の数値範囲チューニング（HP/ATK/DEF/SPD の上限・下限が仕様書とズレていないかは要確認）。
- OSバージョン文字列のパース方法に破壊的変更が入った場合、属性決定が壊れるリスクがある。
- ガチャ排出率と実機キャラ強度の比較バランス（仮置き：現状は「ガチャが上振れ可能」想定）。
