import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/service_locator.dart';
import 'package:spec_battle_game/presentation/screens/data_backup_screen.dart';

void main() {
  group('DataBackupScreen', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService().resetForTest();
      await ServiceLocator().init();
      await LocalStorageService().resetForTest();
    });

    testWidgets('復元コードが空のときは復元ボタンを無効化する', (tester) async {
      await _pumpScreen(tester);

      expect(find.text('復元コードを貼り付けると実行できます'), findsOneWidget);
      expect(_restoreButton(tester).onPressed, isNull);
    });

    testWidgets('復元コード入力後は読み取り準備完了を表示する', (tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
          find.byType(TextField).last, 'SPEC-BATTLE-BACKUP:test');
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('復元コードを読み取り準備完了'), findsOneWidget);
      expect(_restoreButton(tester).onPressed, isNotNull);
    });

    testWidgets('復元失敗時は形式とコピーし直し案内を出す', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpScreen(tester);

      await tester.enterText(
          find.byType(TextField).last, 'SPEC-BATTLE-BACKUP:not-valid');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, '復元'));
      await tester.tap(find.widgetWithText(ElevatedButton, '復元'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('復元する'));
      await tester.pumpAndSettle();

      expect(find.text('形式'), findsOneWidget);
      expect(find.text('コード全体をコピーし直してください'), findsOneWidget);
    });
  });
}

ElevatedButton _restoreButton(WidgetTester tester) {
  return tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, '復元').last,
  );
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: DataBackupScreen(),
    ),
  );
  await tester.pumpAndSettle();
}
