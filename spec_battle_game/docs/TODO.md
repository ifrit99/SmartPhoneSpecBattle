# SPEC BATTLE — TODO

バージョン: 0.1.0
最終更新: 2026-02-21

---

## 優先度: 高（バグ・ロジック不具合）

### ~~1. Regen の毎ターン回復処理が未実装~~ ✅ 修正済み
- `battle_engine.dart` `_onTurnEnd()` にて `maxHp * value / 100` の回復処理を実装済み

### ~~2. Poison（継続ダメージ）の毎ターン処理が未実装~~ ✅ 修正済み
- `battle_engine.dart` `_onTurnEnd()` にて毎ターンダメージ処理を実装済み

### ~~3. hp と maxHp のシード分散が独立している~~ ✅ 修正済み
- `character_generator.dart` `_calculateBaseStats()` で `final hpVal = hp + variance()` として両フィールドに同一値を設定済み

### ~~4. カースドレインのスキル名ハードコード~~ ✅ 修正済み
- `Skill` モデルに `isDrain` フラグを追加し、`battle_engine.dart` でフラグによる分岐に変更済み

### ~~5. スキップ時の HP バー最終状態が不正確~~ ✅ 修正済み
- `BattleResult` に `finalPlayerHp` / `finalEnemyHp` を追加し、`_skipToEnd()` で反映済み

---

## 優先度: 中（UX・演出の改善）

### ~~6. レベルアップ演出がない~~ ✅ 修正済み
- `result_screen.dart` にて `_levelBefore` / `_levelAfter` 比較 + `_levelUpController` パルスアニメーション + 「⭐ LEVEL UP!」表示を実装済み

### ~~7. クリティカルヒットが未実装~~ ✅ 修正済み
- `battle_engine.dart` `_doAttack()` にてSPD比率・属性有利に基づくクリティカル判定（ダメージ1.5倍）を実装済み
- `DamagePopup` の `isCritical` フラグによる視覚強調（大フォント・グロー）も実装済み
- `battle_screen.dart` にて `entry.isCritical` を正しくポップアップに渡すよう実装済み

### ~~8. バトルログが素テキストのみで見づらい~~ ✅ 修正済み
- `battle_screen.dart` `_buildBattleLog()` にてアクションタイプ別アイコン（⚔️🛡️✨）追加済み
- スキル名を金色ハイライト表示するよう実装済み

### ~~9. キャラクター詳細画面に現在のバフ・デバフ表示がない~~ ✅ 修正済み
- `character_screen.dart` `_buildStatusEffectsCard()` にてバフ（緑）・デバフ（赤）のチップ表示を実装済み

### ~~10. docs/ ディレクトリが未コミット~~ ✅ 修正済み
- `git add spec_battle_game/docs/ && git commit -m "docs: Add SPECIFICATION and TODO"` にてコミット済み

---

## 優先度: 中（コード品質）

### ~~11. ユニットテストが未実装~~ ✅ 修正済み
- `test/domain/` に `battle_engine_test.dart` / `element_type_test.dart` / `experience_test.dart` を追加済み（計21ケース）

### 12. `effectiveStats` の HP 参照が不整合
- **ファイル**: `lib/domain/models/character.dart` L120-128
- **問題**: `effectiveStats` は `battleStats`（レベル倍率適用済み）の `atk/def/spd` を使うが、HP は `currentStats.hp`（バトル中に `withHp` で書き換えられた値）を使う。この二重参照は混乱の元
- **対応**: コメントで意図を明記するか、HP だけ別 getter にする

### ~~13. `HomeScreen._reloadData()` の冗長なキャラクター再構築~~ ✅ 修正済み
- `home_screen.dart` L137 にて `player.copyWith(experience: experience, ...)` を使うよう実装済み

---

## 優先度: 低（将来の拡張）

### 14. カスタムピクセルフォントの追加
- ゲームらしさを高めるため `Press Start 2P` などのピクセルフォントを `pubspec.yaml` に追加し、タイトルや数値表示に適用する

### 15. SEとBGMの追加
- `audioplayers` または `flame_audio` パッケージを使い、バトル開始・攻撃・勝利・敗北時の効果音を追加する

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
