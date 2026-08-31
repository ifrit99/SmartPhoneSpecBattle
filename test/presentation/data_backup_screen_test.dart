import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/service_locator.dart';
import 'package:spec_battle_game/presentation/screens/data_backup_screen.dart';
import 'package:spec_battle_game/presentation/widgets/empty_state_card.dart';

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

    testWidgets('生成コードはv2プレフィックスで表示される', (tester) async {
      await _pumpScreen(tester);

      final exportField = tester.widget<TextField>(find.byType(TextField).first);
      expect(exportField.controller!.text.startsWith('SPEC-BATTLE-BACKUP2:'),
          isTrue);
    });

    testWidgets('復元コード入力後は読み取り準備完了を表示する', (tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
          find.byType(TextField).last, 'SPEC-BATTLE-BACKUP2:test');
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

    testWidgets('1文字破損したv2は復元前にコードが破損していますと拒否する', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await LocalStorageService().saveCoins(320);
      final code = await LocalStorageService().exportBackupCode();
      const prefix = 'SPEC-BATTLE-BACKUP2:';
      expect(code.startsWith(prefix), isTrue);
      final body = code.substring(prefix.length);
      final flipped = body[0] == 'A' ? 'B' : 'A';
      final corrupted = '$prefix$flipped${body.substring(1)}';
      await LocalStorageService().saveCoins(999);

      await _pumpScreen(tester);

      await tester.enterText(find.byType(TextField).last, corrupted);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, '復元'));
      await tester.tap(find.widgetWithText(ElevatedButton, '復元'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('復元する'));
      await tester.pumpAndSettle();

      expect(find.text('コードが破損しています'), findsOneWidget);
      expect(find.text('コード全体をコピーし直してください'), findsOneWidget);
      expect(find.byType(EmptyStateCard), findsOneWidget);
      expect(LocalStorageService().getCoins(), 999);
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
