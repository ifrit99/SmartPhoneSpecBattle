import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:spec_battle_game/data/error_monitoring.dart';

void main() {
  group('scrubPii', () {
    test('v1 バックアップコードの値をマスクする', () {
      const raw =
          'restore failed for SPEC-BATTLE-BACKUP:eyJhIjoxfQ_abc-123 end';
      final scrubbed = scrubPii(raw);
      expect(scrubbed.contains('eyJhIjoxfQ_abc-123'), isFalse);
      expect(scrubbed.contains('SPEC-BATTLE-BACKUP:[REDACTED]'), isTrue);
    });

    test('v2 バックアップコードの値をマスクする', () {
      const raw = 'code=SPEC-BATTLE-BACKUP2:AAAABBBBcccc_dd-ee more';
      final scrubbed = scrubPii(raw);
      expect(scrubbed.contains('AAAABBBBcccc_dd-ee'), isFalse);
      expect(scrubbed.contains('SPEC-BATTLE-BACKUP:[REDACTED]'), isTrue);
    });

    test('battle クエリ値をマスクしキー名は残す', () {
      const raw = 'open https://x.example/?battle=Zm9vYmFyX3NlY3JldA and more';
      final scrubbed = scrubPii(raw);
      expect(scrubbed.contains('Zm9vYmFyX3NlY3JldA'), isFalse);
      expect(scrubbed.contains('battle=[REDACTED]'), isTrue);
    });

    test('& 連結の battle 値でも後続パラメータを壊さない', () {
      const raw = 'https://x.example/?foo=1&battle=SECRETVAL&bar=2';
      final scrubbed = scrubPii(raw);
      expect(scrubbed.contains('SECRETVAL'), isFalse);
      expect(scrubbed.contains('battle=[REDACTED]'), isTrue);
      expect(scrubbed.contains('bar=2'), isTrue);
    });

    test('PII を含まない文字列は変更しない', () {
      const raw = 'NullPointerException at battle_engine.dart:120';
      expect(scrubPii(raw), raw);
    });
  });

  group('scrubUrl', () {
    test('query / fragment を除去しパス部のみ残す', () {
      const url = 'https://ifrit99.github.io/SmartPhoneSpecBattle/?battle=SECRET#frag';
      final scrubbed = scrubUrl(url);
      expect(scrubbed, 'https://ifrit99.github.io/SmartPhoneSpecBattle/');
      expect(scrubbed.contains('SECRET'), isFalse);
    });

    test('query の無い URL はそのまま', () {
      const url = 'https://ifrit99.github.io/SmartPhoneSpecBattle/';
      expect(scrubUrl(url), url);
    });
  });

  group('scrubEvent', () {
    test('message / request URL / exception value をマスクする', () {
      final event = SentryEvent(
        message: SentryMessage(
          'restore SPEC-BATTLE-BACKUP:secret_payload_xyz failed',
        ),
        request: SentryRequest(
          url: 'https://x.example/game/?battle=SECRETBATTLE',
        ),
        exceptions: [
          SentryException(
            type: 'FormatException',
            value: 'bad code SPEC-BATTLE-BACKUP2:another_secret_val',
          ),
        ],
      );

      final scrubbed = scrubEvent(event);

      expect(scrubbed.message?.formatted.contains('secret_payload_xyz'), isFalse);
      expect(scrubbed.request?.url, 'https://x.example/game/');
      expect(
        scrubbed.exceptions?.first.value?.contains('another_secret_val'),
        isFalse,
      );
    });
  });
}
