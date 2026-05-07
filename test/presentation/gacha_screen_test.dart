import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/service_locator.dart';
import 'package:spec_battle_game/presentation/screens/gacha_screen.dart';

void main() {
  group('GachaScreen currency errors', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService().resetForTest();
      await ServiceLocator().init();
      await LocalStorageService().resetForTest();
    });

    testWidgets('コイン不足時は不足量と入手導線を表示する', (tester) async {
      await _pumpScreen(tester);

      await tester.tap(find.text('1回引く'));
      await tester.pump();

      expect(
        find.text('コインが足りません: あと100 Coin。CPU戦やミッションで集めましょう'),
        findsOneWidget,
      );
    });

    testWidgets('イベント解析のジェム不足時は不足量と入手導線を表示する', (tester) async {
      await _pumpScreen(tester);

      await tester.ensureVisible(find.text('イベント解析'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('イベント解析'));
      await tester.pump();

      expect(
        find.text('ジェムが足りません: あと30 Gems。ログイン報酬やイベント報酬で集めましょう'),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: GachaScreen(),
    ),
  );
  await tester.pumpAndSettle();
}
