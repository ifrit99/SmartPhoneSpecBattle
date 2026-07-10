import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

import 'sentry_options.dart';

/// バックアップコード（`SPEC-BATTLE-BACKUP:` / `SPEC-BATTLE-BACKUP2:`）と
/// URL の `battle` クエリ値を `[REDACTED]` に置換する純関数。
///
/// Sentry に依存しないためユニットテスト可能。`beforeSend`（[scrubEvent]）から
/// 利用し、エラーイベントに個人情報（セーブデータ・共有URL全文）が残らないようにする。
String scrubPii(String input) {
  return input
      .replaceAll(
        RegExp(r'''SPEC-BATTLE-BACKUP[0-9]*:[^\s"']+'''),
        'SPEC-BATTLE-BACKUP:[REDACTED]',
      )
      .replaceAllMapped(
        RegExp(r'''([?&]battle=)[^\s&"']+'''),
        (m) => '${m[1]}[REDACTED]',
      );
}

/// URL から query / fragment を除去し、パス部のみを残す。
/// `?battle=` を含む共有URLの値部を送信しないための処理。
String scrubUrl(String url) {
  final noPii = scrubPii(url);
  return noPii.split(RegExp(r'[?#]')).first;
}

/// `beforeSend` 本体。message / exception value / request URL / breadcrumb message
/// に [scrubPii] / [scrubUrl] を適用したイベントを返す。
SentryEvent scrubEvent(SentryEvent event) {
  final message = event.message;
  final request = event.request;

  return event.copyWith(
    message: message?.copyWith(formatted: scrubPii(message.formatted)),
    request: request?.url == null
        ? request
        : request!.copyWith(url: scrubUrl(request.url!)),
    exceptions: event.exceptions
        ?.map((e) =>
            e.value == null ? e : e.copyWith(value: scrubPii(e.value!)))
        .toList(),
    breadcrumbs: event.breadcrumbs
        ?.map((b) =>
            b.message == null ? b : b.copyWith(message: scrubPii(b.message!)))
        .toList(),
  );
}

/// アプリを Sentry のエラー監視下で起動する。
///
/// DSN 未設定時は Sentry を初期化せず [appRunner] をそのまま実行する（no-op）。
/// DSN 設定時は `SentryFlutter.init` で `FlutterError.onError` と Zone 例外を
/// 捕捉する（両者は init が内蔵捕捉するため runZonedGuarded の手書きは不要）。
/// エラー送信は分析同意とは独立（技術的必須。同意ダイアログが明示済み）。
Future<void> runWithErrorMonitoring(AppRunner appRunner) async {
  if (!SentryOptionsConfig.hasDsn) {
    await appRunner();
    return;
  }
  await SentryFlutter.init(
    (options) {
      options.dsn = SentryOptionsConfig.dsn;
      options.release = SentryOptionsConfig.releaseOrDefault;
      options.tracesSampleRate = 0.0;
      options.sampleRate = 1.0;
      options.beforeSend = (event, hint) => scrubEvent(event);
    },
    appRunner: appRunner,
  );
}
