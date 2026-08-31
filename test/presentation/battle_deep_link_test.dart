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
import 'package:spec_battle_game/presentation/battle_deep_link.dart';
import 'package:spec_battle_game/presentation/screens/qr_scan_screen.dart';
import 'package:spec_battle_game/presentation/widgets/empty_state_card.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService().resetForTest();
    await ServiceLocator().resetForTest();
    await ServiceLocator().init();
  });

  testWidgets('同意後の形式不正は理由別エラーとURL入力導線を出す', (tester) async {
    await _pumpDeepLink(tester, '!!!invalid!!!');

    expect(find.text('プレイデータ送信へのご協力'), findsOneWidget);
    await tester.tap(find.text('協力しない'));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyStateCard), findsOneWidget);
    expect(find.text('形式不正'), findsOneWidget);
    expect(find.text('入力画面へ'), findsOneWidget);

    await tester.tap(find.text('入力画面へ'));
    await tester.pumpAndSettle();
    expect(find.byType(UrlInputScreen), findsOneWidget);
  });

  testWidgets('同意後の改ざん検知は理由別エラーを出す', (tester) async {
    await _pumpDeepLink(tester, _tamperedBattleCode());

    await tester.tap(find.text('協力しない'));
    await tester.pumpAndSettle();

    expect(find.text('改ざん検知'), findsOneWidget);
    expect(find.text('入力画面へ'), findsOneWidget);
  });
}

Future<void> _pumpDeepLink(WidgetTester tester, String battleParam) {
  return tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => openBattleDeepLink(context, battleParam),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  ).then((_) async {
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  });
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
