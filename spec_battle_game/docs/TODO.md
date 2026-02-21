# SPEC BATTLE — TODO

バージョン: 0.1.0
最終更新: 2026-02-20

---

## 優先度: 高（バグ・ロジック不具合） ✅ 全件修正済み

### ~~1. Regen の毎ターン回復処理が未実装~~ ✅
- **ファイル**: `lib/domain/services/battle_engine.dart` `_onTurnEnd()`
- **問題**: `EffectType.regen` を持つステータス効果（セイントヒール: 15%/T）がターン終了時に HP を回復しない。duration を減らすだけで終わっている
- **対応**: `_onTurnEnd` 内で `EffectType.regen` の効果を検出し、`maxHp * value / 100` 分だけ HP を回復するログ＋処理を追加する

### ~~2. Poison（継続ダメージ）の毎ターン処理が未実装~~ ✅
- **ファイル**: `lib/domain/services/battle_engine.dart` `_onTurnEnd()`
- **問題**: `EffectType.poison` の毎ターンダメージ処理がない（仕様 §9.1 に記載あり）
- **対応**: regen と同様に `_onTurnEnd` でダメージ処理を追加する

### ~~3. hp と maxHp のシード分散が独立している~~ ✅
- **ファイル**: `lib/domain/services/character_generator.dart` `_calculateBaseStats()` L122-128
- **問題**: `Stats(hp: hp + variance(), maxHp: hp + variance(), ...)` のように `variance()` を2回呼ぶため、hp と maxHp に異なる乱数が加算され初期状態から hp ≠ maxHp になる可能性がある
- **対応**: `final hpVal = hp + variance(); return Stats(hp: hpVal, maxHp: hpVal, ...)`

### ~~4. カースドレインのスキル名ハードコード~~ ✅
- **ファイル**: `lib/domain/services/battle_engine.dart` L343
- **問題**: `if (skill.name == 'カースドレイン')` という文字列直比較。スキル名変更時に壊れる
- **対応**: `Skill` モデルにドレイン専用フラグ（例: `isDrain: bool`）を追加するか、`SkillCategory.drain` を新設して分岐する

### ~~5. スキップ時の HP バー最終状態が不正確~~ ✅
- **ファイル**: `lib/presentation/screens/battle_screen.dart` `_skipToEnd()`
- **問題**: スキップ後は勝者側 HP をそのまま・敗者側 HP を0にするだけで、実際のバトル最終 HP と一致しない場合がある。バトル結果（`BattleResult`）に最終 HP を持たせていない
- **対応**: `BattleResult` に `finalPlayerHp` / `finalEnemyHp` フィールドを追加し、スキップ時はそれを反映する

---

## 優先度: 中（UX・演出の改善）

### ~~6. レベルアップ演出がない~~ ✅
- **ファイル**: `lib/presentation/screens/result_screen.dart`
- **問題**: リザルト画面でレベルアップしても視覚的なフィードバックがない
- **対応**: 保存前後でレベルを比較し、レベルアップした場合は「LEVEL UP!」テキスト＋光るアニメーションを表示する

### ~~7. クリティカルヒットが未実装~~ ✅
- **ファイル**: `lib/presentation/widgets/damage_popup.dart`, `lib/domain/services/battle_engine.dart`
- **問題**: `DamagePopup` に `isCritical` フラグがあるが、バトルエンジン側でクリティカル判定がなく常に `false`
- **対応**: SPD が一定以上高い場合や属性有利時に確率でクリティカル（ダメージ1.5倍）を発生させ、ポップアップでも強調表示する

### ~~8. バトルログが素テキストのみで見づらい~~ ✅
- **ファイル**: `lib/presentation/screens/battle_screen.dart` `_buildBattleLog()`
- **問題**: ダメージ・回復テキストの色分けはあるが、スキル名・バフ/デバフのテキストが単色で埋もれる
- **対応**: ログエントリの `actionType` に応じてアイコン（⚔️🛡️✨）や色を変える

### ~~9. キャラクター詳細画面に現在のバフ・デバフ表示がない~~ ✅
- **ファイル**: `lib/presentation/screens/character_screen.dart`
- **問題**: `statusEffects` がホーム→詳細に引き渡されるが、表示されていない

### 10. docs/ ディレクトリが未コミット
- **問題**: `SPECIFICATION.md` と `TODO.md`（本ファイル）が git 管理外
- **対応**: `git add spec_battle_game/docs/ && git commit -m "docs: Add SPECIFICATION and TODO"`

---

## 優先度: 中（コード品質）

### ~~11. ユニットテストが未実装~~ ✅
- **ファイル**: `test/widget_test.dart`, `test/domain/`（ウィジェットテスト + ドメインテスト21ケース追加済み）
- **対応（優先順位高いもの）**:
  - `BattleEngine.executeBattle()` のテスト（勝敗・ターン数・ログ件数の検証）
  - `CharacterGenerator.generate()` のテスト（同一スペックで同一キャラが生成されるか）
  - `Experience.addExp()` のレベルアップ境界値テスト
  - `elementMultiplier()` の属性相性テスト

### ~~12. `effectiveStats` の HP 参照が不整合~~ ✅（コメントで意図を明記済み）
- **ファイル**: `lib/domain/models/character.dart` L120-128
- **問題**: `effectiveStats` は `battleStats`（レベル倍率適用済み）の `atk/def/spd` を使うが、HP は `currentStats.hp`（バトル中に `withHp` で書き換えられた値）を使う。この二重参照は混乱の元
- **対応**: コメントで意図を明記するか、HP だけ別 getter にする

### 13. `HomeScreen._reloadData()` の冗長なキャラクター再構築
- **ファイル**: `lib/presentation/screens/home_screen.dart` L109-134
- **問題**: `_reloadData` でキャラクター全フィールドを手動コピーしている。`copyWith(experience: ...)` で済む
- **対応**: `copyWith` を使って簡潔にする

---

## 優先度: 低（将来の拡張）

### 14. カスタムピクセルフォントの追加
- ゲームらしさを高めるため `Press Start 2P` などのピクセルフォントを `pubspec.yaml` に追加し、タイトルや数値表示に適用する

### ~~15. SEとBGMの追加~~ ✅
- `audioplayers` パッケージで `SoundService` を実装済み。バトル開始・攻撃・スキル・防御・回復・勝利・敗北の効果音を追加済み

### 16. バトル履歴画面の追加
- 過去のバトルログ（対戦相手名・勝敗・ターン数）を SharedPreferences に保存し、ホームから閲覧できる履歴画面を追加する

### 17. QR コードによる端末間対戦
- `qr_flutter` + `mobile_scanner` を使い、プレイヤーのキャラクターデータを QR コードにエンコードして友人の端末のキャラクターと対戦できる機能を追加する

### 18. Android リリースビルド設定
- `android/app/build.gradle` に署名設定を追加し、Play Store 配布用の APK/AAB ビルドができるようにする

### 19. iOS 動作確認と配布設定
- Xcode でのビルド確認・`Runner/Info.plist` のプライバシー説明追加（battery_plus 要求）・App Store 配布設定

---

## 実装済み（確認済み）

- [x] Phase 1 MVP — ドメインモデル・データ層・バトルエンジン・全4画面
- [x] バッテリーモニタリング（30秒ポーリング、SPD補正）
- [x] バトル演出（ダメージポップアップ・シェイク・スキルエフェクトオーバーレイ）
- [x] Web 対応（条件付きインポートによる `dart:io` 分離）
- [x] Flutter 3.41 / Dart 3.11 対応（null safety・const化）
- [x] Android ビルド設定修正
- [x] バトル結果（経験値・戦績）のホーム画面への反映修正
- [x] 属性相性システム（1.5倍 / 0.75倍）
- [x] バフ・デバフシステム（ATK/DEF/SPD の上昇・低下、duration 管理）
- [x] スキルクールダウン管理
- [x] ローカルデータ永続化（SharedPreferences）
