# SPEC BATTLE — TODO

バージョン: 0.1.0
最終更新: 2026-03-07

---

## 状態サマリー
- **完了済み**:
  - Phase 1 MVP (ドメインモデル、各種画面UI、バトルエンジン本実装)
  - Phase 2 (各種UX演出：ダメージポップアップ、クリティカル、バッテリー連携によるSPD補正、効果音)
  - Phase 3-1 (CPU敵キャラ自動生成: `enemy_generator.dart`)
  - Phase 3-2 (キャラクター図鑑・対戦履歴: `CollectionScreen`)
  - Phase 3-3 (タイトル画面: `title_screen.dart`)
  - セキュリティ強化・環境分離のためのDocker開発環境（Dockerfile, docker-compose.yml等）の構築
  - 重大なバグ修正、及びユニットテスト群の追加
  - Phase 4-1 エミュレートガチャ（ガチャロジック・UI・ブラウザテスト）
  - Phase 4-2 QR/URL対戦 ロジック層（チェックサム検証・QrBattleService・テスト）
- **現在の位置づけ**: **Android先行MVPリリースに向けて作業中**（目標: 2026-04-03）。
  - 詳細な計画は `docs/MVP_RELEASE_PLAN.md` を参照。

---

## MVP リリースに向けた残タスク（Android先行）

> 詳細スケジュールは `docs/MVP_RELEASE_PLAN.md` を参照。

### Week 1 タスク — ビルド基盤整備

#### タスク1-1: targetSdk/compileSdk 更新 ✅ 完了（設定済み・テスト通過済み）
- `android/app/build.gradle`: compileSdk/targetSdk → **34**
- AGP: 7.3.0 → **8.7.0**、Gradle: 7.5 → **8.7**、Kotlin: 1.9.0 → **2.1.0**
- Java互換性: 1.8 → **17**（AGP 8.x 要件）
- `AndroidManifest.xml`: `android:exported="true"` 追加（targetSdk 34 要件）
- `flutter analyze` エラー0、`flutter test` 全122件パス ✅

#### タスク1-2: リリース用署名設定 🔶 設定済み・ビルド未検証
- ✅ `keytool` でリリース用keystore生成済み（`.keystore/release.jks`）
- ✅ `android/key.properties` 作成済み（`.gitignore` に追加済み）
- ✅ `android/app/build.gradle` にリリース署名設定追加済み（`key.properties` 存在時はrelease署名、不在時はdebug署名にフォールバック）
- ⚠️ `flutter build appbundle --release` のビルド検証が**未完了**
  - **原因**: VPS環境のメモリ不足（960MB）でKotlin daemonが起動できず
  - **対策済み**: `gradle.properties` にメモリ節約設定を追加済み（`kotlin.compiler.execution.strategy=in-process`, `org.gradle.daemon=false` 等）
  - **→ MacBook環境で `flutter build appbundle --release` を実行して検証してください**

### Week 1 タスク — QR対戦UI（Antigravity担当）

#### タスク1-3: QRコード表示画面 🔲 未着手
- `qr_flutter` 導入 → キャラ選択 → QR表示 + URL共有ボタン

#### タスク1-4: 対戦コード入力画面 🔲 未着手
- TextField → `decodeAsGuest` → エラー処理 → バトル遷移

#### タスク1-5: ホーム画面にQR対戦導線追加 🔲 未着手

---

## 🤖 MacBook Claude Code への引き継ぎ事項

### 現在のブランチ状態
- **`feature/android-release-setup`** ブランチにプッシュ済み（master起点）
- **`feature/phase4-qr-battle`** ブランチもプッシュ済み（CharacterCodec v2 + QrBattleService）
- 両ブランチは独立（別々に master にマージ可能）

### 引き継ぎ先で最初にやること
1. `git pull` して最新を取得
2. `feature/android-release-setup` ブランチをチェックアウト
3. **`flutter build appbundle --release` を実行してビルド通過を確認**
4. 通らない場合は `android/gradle.properties` のメモリ設定を環境に合わせて調整
5. ビルド通過を確認したらコミット＆プッシュ（または master にマージ）

### 変更されたファイル一覧（`feature/android-release-setup`）
| ファイル | 変更内容 |
|---------|---------|
| `android/app/build.gradle` | compileSdk/targetSdk→34、署名設定追加、Java 17 |
| `android/settings.gradle` | AGP 8.7.0、Kotlin 2.1.0 |
| `android/gradle/wrapper/gradle-wrapper.properties` | Gradle 8.7 |
| `android/gradle.properties` | メモリ節約設定追加 |
| `android/app/src/main/AndroidManifest.xml` | `android:exported="true"` 追加 |
| `.gitignore` | `android/key.properties` と `.keystore/` を追加 |
| `docs/TODO.md` | 本ファイル（進捗更新） |

### keystore について
- `.keystore/release.jks` は VPS 上の `/home/dev/projects/SmartPhoneSpecBattle/.keystore/` に存在
- `.gitignore` に含まれるためリポジトリには含まれない
- **MacBook環境では新しい keystore を生成するか、VPS からコピーする必要がある**
- keystoreが存在しない場合、build.gradle は自動的に debug 署名にフォールバックする

---

## 既知の問題・課題
- **VPSメモリ不足**: 960MBのVPS環境ではKotlin daemon/Gradleビルドがメモリ不足で失敗する。MacBookでのビルド検証を推奨。
- **ユニットテスト環境構築エラー（Mac）**: `flutter test` 実行時に `objective_c` パッケージのネイティブビルドが失敗する（Xcode Command Line Tools のアーキテクチャ不一致問題）。Docker環境では問題なし。
