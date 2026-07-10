import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/data/firebase_analytics_client.dart';
import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/analytics_service.dart';

class _RecordingSink implements AnalyticsEventSink {
  final events = <String>[];
  final collectionStates = <bool>[];
  final consentStates = <bool>[];

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionStates.add(enabled);
  }

  @override
  Future<void> setConsentGranted(bool granted) async {
    consentStates.add(granted);
  }

  @override
  Future<void> logEvent(String name, Map<String, Object?> params) async {
    events.add(name);
  }
}

void main() {
  late LocalStorageService storage;
  late _RecordingSink sink;
  late FirebaseAnalyticsClient analytics;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    sink = _RecordingSink();
    analytics = FirebaseAnalyticsClient(storage, sink: sink);
    await analytics.initialize();
  });

  test('未回答時はlogEventを送信しない', () async {
    await analytics.logEvent('battle_start');

    expect(analytics.consent, AnalyticsConsent.unanswered);
    expect(analytics.isEnabled, isFalse);
    expect(sink.events, isEmpty);
    expect(sink.collectionStates, [false]);
  });

  test('同意後は送信し、拒否後は再び破棄する', () async {
    await analytics.setConsent(AnalyticsConsent.granted);
    await analytics.logEvent('battle_start');
    await analytics.setConsent(AnalyticsConsent.denied);
    await analytics.logEvent('battle_result');

    expect(sink.events, ['battle_start']);
    expect(storage.getAnalyticsConsent(), AnalyticsConsent.denied);
    expect(sink.consentStates, [false, true, false]);
    expect(sink.collectionStates, [false, true, false]);
  });

  test('unansweredからgrantedとdeniedへ3値遷移する', () async {
    expect(storage.getAnalyticsConsent(), AnalyticsConsent.unanswered);

    await analytics.setConsent(AnalyticsConsent.granted);
    expect(storage.getAnalyticsConsent(), AnalyticsConsent.granted);
    expect(analytics.isEnabled, isTrue);

    await analytics.setConsent(AnalyticsConsent.denied);
    expect(storage.getAnalyticsConsent(), AnalyticsConsent.denied);
    expect(analytics.isEnabled, isFalse);
  });
}
