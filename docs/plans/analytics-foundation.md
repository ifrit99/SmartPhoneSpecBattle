# Plan: 分析基盤導入＋計測イベント設計（F1）
Created: 2026-07-10
Status: PLANNING

## 要件
`docs/phase5_brushup_spec.md` §2-1 のF1を実装する。「計測できる無料Web運用」の第一歩として、匿名プレイデータの計測基盤（Firebase Analytics）と起動時の同意ゲートを導入する。同意前は自動収集を含め送信ゼロ。拒否しても全機能プレイ可能（§1-4受け入れ基準）。F2(Sentry)・F6(ランキング)は含めない。

## 仕様

### 画面/UI変更
- `title_screen.dart`: 初回タップでBGMアンロック後、ホーム/オンボーディング遷移「前」に、同意状態が未回答なら同意ダイアログを1回表示（§3-2）。回答を永続化してから既存遷移を続行。
- `main.dart`: `?battle=` 直リンク起動時、生の`battle`パラメータを保持し、ゲストプレビューpush「前」に未回答なら同意ダイアログを表示→回答後にデコード実行（デコード自体はF3の理由別エラー化は範囲外、現行の`debugPrint`挙動は維持）。回答前は`share_url_opened`を送信しない。
- ホームメニュー（`home_screen.dart` の `_buildMenuButton` 群）に「Privacy」項目を追加し、同意を後から変更する `PrivacySettingsScreen` へ遷移。
- 同意ダイアログ本文はエラー送信（F2）にも触れる（§3-2文言踏襲）。

### ロジック/状態変更
- `service_locator.dart`: `AnalyticsService analyticsService` を追加し `init()` 内で生成・登録。`main()`で同意状態に応じ収集有効化を呼ぶ。
- `local_storage_service.dart`: `analytics_consent`（`unanswered`/`granted`/`denied` の3値）の取得・保存メソッドを追加。**バックアップ対象外**。
- 計測イベント12種（§2-1の表）を各発火箇所へ敷設: onboarding_step / battle_start / battle_result / gacha_pull / gacha_blocked / share_url_created / share_url_opened / mission_claimed / shop_purchased / backup_created・backup_restored / screen_view。`ranking_opt_in`はF6範囲のため今回敷設しない（イベント名は予約）。screen_viewは`main.dart`の`navigatorObservers`にAnalytics連動オブザーバを追加。

### 新規ファイル
- `lib/domain/services/analytics_service.dart`: 抽象IF。`logEvent(name, {params})` と3値同意状態管理（`consent` getter / `setConsent()` / `isEnabled`）。ドメイン層はFirebaseに依存しない。テスト用 No-op 実装（`NoopAnalyticsService`）も同ファイルに置く。
- `lib/data/firebase_analytics_client.dart`: `AnalyticsService`実装。Firebaseを**収集無効で初期化**（`setAnalyticsCollectionEnabled(false)`＋Consent Mode既定`denied`）。同意後のみ収集有効化。未同意/拒否時はラッパー側でも全イベント破棄（二重ガード）。
- `lib/data/firebase_options.dart`: **ユーザー提供のプロジェクト情報で差し込む前提**。未提供時はビルドを壊さないダミー/環境変数（`--dart-define`）フォールバックとし、キー無しでもFirebase初期化を安全にスキップして No-op で動作させる。→ Codexがキー無しで `flutter analyze` / `flutter test` を通せること。
- `lib/presentation/widgets/analytics_consent_dialog.dart`: 2択即決ダイアログ（協力する/協力しない、§3-2文言、後から変更可の注記）。
- `lib/presentation/screens/privacy_settings_screen.dart`: 現在の同意状態の表示・トグル変更（即時反映・永続化）。

### テスト基準（Widget確認は browse ではなく flutter test で）
- [ ] AnalyticsService: 未同意時は`logEvent`が送信されない（No-op/破棄）／同意後は送信される／`unanswered→granted→denied` の3値遷移
- [ ] 同意ダイアログ: 未回答時のみ表示／「協力する」「協力しない」で永続化・即反映／「協力しない」後もホームへ遷移
- [ ] 直リンク経路: `?battle=` 起動で未回答ならゲストプレビュー「前」に同意ダイアログが出る／回答前に`share_url_opened`が送られない
- [ ] PrivacySettingsScreen: 現在値表示と変更が`analytics_consent`へ永続化される
- [ ] `analytics_consent` がバックアップ対象外であること（既存バックアップ往復テストにキーが含まれない）

### 完了条件
- [ ] flutter analyze: エラー0（Firebaseキー未提供・ダミーfallback状態で通ること）
- [ ] flutter test: 全パス（既存 `economy_balance_test.dart` 無変更でパス）
- [ ] 未同意状態で自動収集含め送信ゼロ／同意後に`battle_start`〜`battle_result`が到達する経路がコード上で追える（本番DebugView確認は手動テストで別途）

---
## Generator ログ
（Generator が実装時に追記）

---
## 評価
（Evaluator が検証結果を追記）
