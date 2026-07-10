# Plan: F2 エラー監視導入（Sentry）
Created: 2026-07-10
Status: PLANNING

## 要件
`docs/phase5_brushup_spec.md` §2-2。`sentry_flutter`（Web対応）を導入し `main()` を `SentryFlutter.init` でラップ。`FlutterError.onError` と非同期例外を捕捉。`beforeSend` でPII（バックアップコード・`?battle=`値）をマスク。release タグに git SHA を注入。DSN未設定時はSentryを無効化（no-op）してビルドを壊さない。エラー送信は分析同意と独立（技術的必須／同意ダイアログが既に明示済み・F1本番マージ済み）。

## 仕様（3層）
### data 層
- 新規 `lib/data/sentry_options.dart`: `SentryOptionsConfig` を定義。`dsn = String.fromEnvironment('SENTRY_DSN')`, `release = String.fromEnvironment('SENTRY_RELEASE')`（未設定時 `'dev'` フォールバック）。`hasDsn => dsn.isNotEmpty`。`FirebaseOptionsConfig` の踏襲。
- 新規 `lib/data/error_monitoring.dart`:
  - `String scrubPii(String input)` — 純関数。`SPEC-BATTLE-BACKUP[0-9]*:<値>` と `?battle=<値>`（および `&battle=`）の値部を `[REDACTED]` に置換。URLはパス部のみ残し query/fragment を除去。テスト容易化のため sentry非依存で実装。
  - `SentryEvent? scrubEvent(SentryEvent event)` — `beforeSend`。message / exception value / request URL / breadcrumb message に `scrubPii` を適用。
  - `Future<void> runWithErrorMonitoring(FutureOr<void> Function() appRunner)`:
    - `SentryOptionsConfig.hasDsn` が false → `SentryFlutter.init` を呼ばず `await appRunner()` のみ（no-op、DSN無しでビルド/テスト可）。
    - true → `SentryFlutter.init((o){ o.dsn=...; o.release=...; o.tracesSampleRate=0.0; o.sampleRate=1.0; o.beforeSend=(e,h)=>scrubEvent(e); }, appRunner: appRunner)`。`FlutterError.onError` と Zone例外は `SentryFlutter.init` が捕捉するため runZonedGuarded 手書きは不要。

### presentation / エントリ層
- `lib/main.dart`: 既存 `main()` 本体を `runWithErrorMonitoring(() async { ...現行処理... })` でラップ。`WidgetsFlutterBinding.ensureInitialized()` は appRunner 内先頭で維持。**同意ゲート順序**: `?battle=` 直リンクの初回フレーム処理は現行どおり `ensureAnalyticsConsent` 通過後にデコード／`share_url_opened` 送信（F1で実装済み）。エラー送信は同意と独立のため初回フレーム前の例外も送信され得る（同意ダイアログが明示済み・仕様通り。挙動変更なし）。

### CI/CD
- `.github/workflows/ci.yml` / `deploy.yml` の `flutter build web` に `--dart-define=SENTRY_DSN=${{ secrets.SENTRY_DSN }} --dart-define=SENTRY_RELEASE=${{ github.sha }}` を追加。secret 未設定でも空文字→no-op でビルド成功。
- pubspec に `sentry_flutter`（Web対応版）を追加。

### テスト
- 新規 `test/error_monitoring_test.dart`: `scrubPii` の純関数テスト。バックアップコード（`SPEC-BATTLE-BACKUP:` / `SPEC-BATTLE-BACKUP2:`）値・`?battle=`値がイベント文字列に残らないこと／URLパス部のみ残ることを検証。

## テスト基準
- [ ] DSN未設定で `runWithErrorMonitoring` が `SentryFlutter.init` を呼ばず appRunner を実行（no-op）
- [ ] `scrubPii`: `SPEC-BATTLE-BACKUP`/`SPEC-BATTLE-BACKUP2` 値と `?battle=`値が `[REDACTED]`、URLはパス部のみ
- [ ] 既存テスト全件パス（特に `test/economy_balance_test.dart` 無変更）

## 完了条件
- [ ] `flutter analyze` エラー0（LSPツールのローカルクラッシュ時は `dart analyze` 代替可）
- [ ] `flutter test` 全パス
- [ ] `flutter build web` 成功、main.dart.js サイズを導入前後で記録（§4-4 の +15% 目安に言及）

## 制約・前提
- feature ブランチ: `feature/error-monitoring` / タスクID: `t2`。
- 実際のSentryプロジェクト作成・DSN取得・GitHub Secret登録は**ユーザー作業**。本計画はDSN無しでグリーンになる状態までを対象とする。
- 実装対象は上記 data/main/CI のみ。無関係ファイルは変更しない。

---
## Generator ログ

---
## 評価
