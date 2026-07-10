/// Sentry の設定値。DSN / release はビルド時に `--dart-define` で注入する。
///
/// 実際の DSN はユーザー提供のシークレット（`SENTRY_DSN`）。未設定時は
/// [hasDsn] が false となり、Sentry を初期化しない（no-op）ため、
/// キー無しでも `flutter analyze` / `flutter test` / `build web` が通る。
/// `FirebaseOptionsConfig` と同じ方式。
class SentryOptionsConfig {
  static const dsn = String.fromEnvironment('SENTRY_DSN');
  static const release = String.fromEnvironment('SENTRY_RELEASE');

  static bool get hasDsn => dsn.isNotEmpty;

  /// release タグ。CI からは git SHA を渡す。未設定時は 'dev'。
  static String get releaseOrDefault => release.isNotEmpty ? release : 'dev';
}
