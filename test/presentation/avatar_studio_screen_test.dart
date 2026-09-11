import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/presentation/screens/avatar_studio_screen.dart';
import 'package:spec_battle_game/presentation/widgets/character_portrait.dart';
import 'package:spec_battle_game/presentation/widgets/pixel_character.dart';

Character _character() {
  const stats = Stats(hp: 100, maxHp: 100, atk: 10, def: 10, spd: 10);
  return const Character(
    name: 'フレア・ナイト',
    element: ElementType.fire,
    baseStats: stats,
    currentStats: stats,
    skills: [],
    seed: 0,
  );
}

Future<void> _pumpStudio(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: AvatarStudioScreen(baseCharacter: _character()),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService().resetForTest();
  });

  testWidgets('初期表示は battle スプライトで、旧ドット絵と頭体腕脚の行がない', (tester) async {
    await _pumpStudio(tester);

    expect(find.byType(PixelCharacter), findsNothing);
    final portraits = tester
        .widgetList<CharacterPortrait>(find.byType(CharacterPortrait))
        .where((p) => p.variant == PortraitVariant.battle);
    expect(portraits.length, greaterThanOrEqualTo(1));

    expect(find.text('頭'), findsNothing);
    expect(find.text('体'), findsNothing);
    expect(find.text('腕'), findsNothing);
    expect(find.text('脚'), findsNothing);
    expect(find.text('バトルスプライトのカスタマイズ'), findsOneWidget);
    expect(find.text('バトル中の見た目'), findsOneWidget);
    expect(battleAccessoryLabels, contains('イヤーピース'));
    expect(find.text('リボン'), findsOneWidget);
    expect(find.text('バイザー'), findsOneWidget);
  });

  testWidgets('アクセサリータイルをタップすると先頭4値が -1 の7値で保存される', (tester) async {
    await _pumpStudio(tester);

    await tester.tap(find.text('リボン'));
    await tester.pump();

    final saved = LocalStorageService().getAvatarCustomization();
    expect(saved, isNotNull);
    final parts = saved!.split(',');
    expect(parts, hasLength(7));
    expect(parts.take(4).toList(), ['-1', '-1', '-1', '-1']);
  });
}
