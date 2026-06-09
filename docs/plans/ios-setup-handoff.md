# iOS 実機テスト環境構築 — Codex 引き継ぎドキュメント

作成日: 2026-05-28  
作業者: Claude Code  
ブランチ: `fix/review-followups`（未コミット変更あり）

---

## 現状サマリー

Flutter SDK インストールから iOS ビルド直前まで完了済み。**残り1ステップ: iPhone を USB 接続してビルドを再実行するだけ**で動作確認できる状態。

---

## 完了済みの作業

### 1. Flutter SDK インストール
- `~/development/flutter` に Flutter 3.44.0 (stable) を git clone
- `~/.zshrc` に `export PATH="$HOME/development/flutter/bin:$PATH"` を追加済み
- `flutter pub get` / `flutter precache --ios` 実行済み

### 2. iOS デプロイターゲットの修正
- **修正ファイル**: `ios/Runner.xcodeproj/project.pbxproj`
- `IPHONEOS_DEPLOYMENT_TARGET = 9.0` → `13.0` に変更（Debug/Release/Profile 3箇所）
- Podfile（`platform :ios, '13.0'`）との不整合を解消

### 3. Generated.xcconfig の修正
- `flutter pub get` 実行により `FLUTTER_ROOT=/Users/develop/flutter`（誤ったパス）→ `FLUTTER_ROOT=/Users/kanaihideaki/development/flutter` に自動修正

### 4. CocoaPods & pod install
- CocoaPods 1.16.2 はインストール済み
- `flutter precache --ios` で iOS エンジン Artifact を取得後、`pod install` 成功

### 5. Xcode iOS 26.5 プラットフォームのインストール
- `xcodebuild -downloadPlatform iOS` で iOS 26.5 Simulator (23F77) 8.52GB をダウンロード・インストール完了

### 6. flutter run によるプロジェクト自動マイグレーション（未コミット）
`flutter run` 実行時に Flutter 3.44.0 が以下を自動修正（コミット必要）:

| ファイル | 変更内容 |
|---------|---------|
| `ios/Runner/AppDelegate.swift` | `@UIApplicationMain` → `@main`、UIScene ライフサイクルへ移行、`FlutterImplicitEngineBridge` 対応 |
| `ios/Runner/Info.plist` | `UIApplicationSceneManifest`（UIScene 設定）、`CADisableMinimumFrameDurationOnPhone`、`UIApplicationSupportsIndirectInputEvents` を追加 |
| `ios/Runner.xcodeproj/project.pbxproj` | Swift Package Manager 統合の追加 |
| `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | スキーム更新 |
| `ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | ワークスペース更新 |
| `ios/Flutter/AppFrameworkInfo.plist` | バージョン更新 |
| `ios/Podfile.lock` | pod 依存関係更新 |
| `pubspec.lock` | `matcher`, `meta`, `test_api` 等3パッケージ更新 |

---

## 残っている作業

### ステップ A（ユーザー操作が必要）: USB 接続
現在 iPhone がワイヤレスで接続されているが `unavailable` 状態。DDI マウントに失敗する。

```
xcrun devicectl list devices 結果:
  Hideaki.Kanai's iPhone  State: unavailable  Model: iPhone 17 (iPhone18,3)
```

**対処**: iPhone を USB ケーブルで Mac に接続 → 「このコンピュータを信頼しますか？」でタップ

### ステップ B: ビルド＆実機インストール
USB 接続後に以下を実行:

```bash
cd /Users/kanaihideaki/Documents/SmartPhoneSpecBattle
~/development/flutter/bin/flutter run -d 00008150-000212961A28401C
```

デバイスIDが変わっている場合は先に `flutter devices` で確認。

### ステップ C: 動作確認
- タイトル画面が表示されること
- ホーム → CPU バトル → リザルト の基本フローが動作すること
- BGM / SE が再生されること（現状は Web Audio 実装のため iOS では無音の可能性あり）

### ステップ D: 変更のコミット
マイグレーション変更は `fix/review-followups` ブランチに含めてよいか確認の上コミット。  
コミット対象ファイル例（git add で個別指定を推奨）:

```bash
git add ios/Runner/AppDelegate.swift
git add ios/Runner/Info.plist
git add ios/Runner.xcodeproj/project.pbxproj
git add ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata
git add ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
git add ios/Flutter/AppFrameworkInfo.plist
git add ios/Podfile.lock
git add pubspec.lock
```

---

## 既知の注意事項

### CocoaPods → Swift Package Manager 移行の警告
`flutter run` 実行時に以下の警告が出るが現時点ではビルドに影響なし:
```
All plugins found for ios are Swift Packages, but your project still has CocoaPods integration.
```
今後対応する場合は `pod deintegrate` 実行と Debug.xcconfig / Release.xcconfig から Pods インクルード行を削除。

### Web Audio の iOS 互換性
現行の SE 再生は `lib/data/web_se_player_web.dart`（`document.createElement` 方式）で実装されており、iOS ネイティブでは無音になる可能性がある。iOS では `audioplayers` パッケージが使われるはず（`kIsWeb` 分岐）なので動作確認要。

### PATH の恒久化
新規ターミナルセッションでは `~/.zshrc` からパスが読み込まれる。Claude Code セッション内では `~/development/flutter/bin/flutter` フルパスを使用する。

---

## 環境情報

| 項目 | 値 |
|------|----|
| Flutter | 3.44.0 (stable) |
| Dart | 3.12.0 |
| Flutter SDK パス | `~/development/flutter` |
| Xcode | 26.4.1 (Build 17E202) |
| iOS SDK | 26.5 |
| CocoaPods | 1.16.2 |
| Bundle ID | `com.specbattle.specBattleGame` |
| Development Team | `V3634P8RSS` |
| Signing | Automatic（`Apple Development: sironekoinochi8900@docomonet.jp (JKU26Q7VM4)`） |
| テスト対象デバイス | iPhone 17 (iPhone18,3) / iOS 26.4.2 / UDID: `00008150-000212961A28401C` |
