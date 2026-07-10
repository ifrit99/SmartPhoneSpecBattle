import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/data/firebase_analytics_client.dart';
import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/analytics_service.dart';
import 'package:spec_battle_game/domain/services/service_locator.dart';
import 'package:spec_battle_game/presentation/screens/privacy_settings_screen.dart';
import 'package:spec_battle_game/presentation/widgets/analytics_consent_dialog.dart';

class _RecordingSink implements AnalyticsEventSink {
  bool collectionEnabled = false;

  @override
  Future<void> logEvent(String name, Map<String, Object?> params) async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }

  @override
  Future<void> setConsentGranted(bool granted) async {}
}

void main() {
  late LocalStorageService storage;
  late _RecordingSink sink;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    sink = _RecordingSink();
    final analytics = FirebaseAnalyticsClient(storage, sink: sink);
    await ServiceLocator().resetForTest(analytics: analytics);
  });

  testWidgets('未回答時のみ表示され、協力するで永続化と即時反映を行う', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ensureAnalyticsConsent(context),
            child: const Text('Start'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('プレイデータ送信へのご協力'), findsOneWidget);

    await tester.tap(find.text('協力する'));
    await tester.pumpAndSettle();

    expect(storage.getAnalyticsConsent(), AnalyticsConsent.granted);
    expect(ServiceLocator().analyticsService.isEnabled, isTrue);
    expect(sink.collectionEnabled, isTrue);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('プレイデータ送信へのご協力'), findsNothing);
  });

  testWidgets('協力しないでも回答を保存して後続画面へ進める', (tester) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await ensureAnalyticsConsent(context);
              continued = true;
            },
            child: const Text('Start'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('協力しない'));
    await tester.pumpAndSettle();

    expect(storage.getAnalyticsConsent(), AnalyticsConsent.denied);
    expect(ServiceLocator().analyticsService.isEnabled, isFalse);
    expect(continued, isTrue);
  });

  testWidgets('PrivacySettingsScreenで現在値表示と変更を永続化する', (tester) async {
    await ServiceLocator().analyticsService.setConsent(AnalyticsConsent.denied);

    await tester.pumpWidget(
      const MaterialApp(home: PrivacySettingsScreen()),
    );

    expect(find.text('送信しない'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(storage.getAnalyticsConsent(), AnalyticsConsent.granted);
    expect(find.text('送信する'), findsOneWidget);
  });
}
