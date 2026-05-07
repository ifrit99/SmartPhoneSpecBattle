import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spec_battle_game/presentation/screens/qr_scan_screen.dart';

void main() {
  group('UrlInputScreen', () {
    testWidgets('初期状態では読み取りボタンが無効', (tester) async {
      await _pumpScreen(tester);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '読み取る'),
      );

      expect(button.onPressed, isNull);
      expect(find.text('読み取り準備完了'), findsNothing);
    });

    testWidgets('テキスト入力後は読み取り準備完了を表示する', (tester) async {
      await _pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'invalid-code');
      await tester.pump(const Duration(milliseconds: 250));

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '読み取る'),
      );

      expect(find.text('読み取り準備完了'), findsOneWidget);
      expect(button.onPressed, isNotNull);
    });
  });
}

Future<void> _pumpScreen(WidgetTester tester) {
  return tester.pumpWidget(
    const MaterialApp(
      home: UrlInputScreen(),
    ),
  );
}
