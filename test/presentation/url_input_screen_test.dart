import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/domain/services/character_codec.dart';
import 'package:spec_battle_game/domain/services/service_locator.dart';
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

    testWidgets('形式不正のコードはインラインで形式不正と出す', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService().resetForTest();
      await ServiceLocator().init();
      await LocalStorageService().resetForTest();

      await _pumpScreen(tester);
      await tester.enterText(find.byType(TextField), '!!!invalid!!!');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.widgetWithText(ElevatedButton, '読み取る'));
      await tester.pumpAndSettle();

      expect(find.text('形式不正'), findsOneWidget);
      expect(find.textContaining('オフライン'), findsNothing);
    });

    testWidgets('改ざんコードはインラインでチェックサム不一致と出す', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService().resetForTest();
      await ServiceLocator().init();
      await LocalStorageService().resetForTest();

      await _pumpScreen(tester);
      await tester.enterText(find.byType(TextField), _tamperedBattleCode());
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.widgetWithText(ElevatedButton, '読み取る'));
      await tester.pumpAndSettle();

      expect(find.text('チェックサム不一致'), findsOneWidget);
      expect(find.textContaining('オフライン'), findsNothing);
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

String _tamperedBattleCode() {
  const stats = Stats(hp: 100, maxHp: 100, atk: 20, def: 10, spd: 10);
  const character = Character(
    name: 'T',
    element: ElementType.fire,
    baseStats: stats,
    currentStats: stats,
    skills: [],
  );
  final encoded = CharacterCodec.encode(character);
  final bytes = base64Url.decode(encoded);
  bytes[5] = (bytes[5] + 1) % 256;
  return base64Url.encode(bytes);
}
