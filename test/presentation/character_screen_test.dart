import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/data/character_bios.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/presentation/screens/character_screen.dart';
import 'package:spec_battle_game/presentation/widgets/character_portrait.dart';
import 'package:spec_battle_game/presentation/widgets/pixel_character.dart';

Character _character({
  required String name,
  required ElementType element,
  required int seed,
}) {
  const stats = Stats(hp: 100, maxHp: 100, atk: 10, def: 10, spd: 10);
  return Character(
    name: name,
    element: element,
    baseStats: stats,
    currentStats: stats,
    skills: const [],
    seed: seed,
  );
}

Future<void> _pumpScreen(WidgetTester tester, Character character) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: CharacterScreen(character: character),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('fire_0 はプロフィールカードにフレアの紹介文を表示し、立ち絵高さは 268.8',
      (tester) async {
    await _pumpScreen(
      tester,
      _character(name: 'フレア・ナイト', element: ElementType.fire, seed: 0),
    );

    expect(find.text('プロフィール'), findsOneWidget);
    expect(
      find.text(
        '熱設計チームを率いる指揮官。限界ぎりぎりまでクロックを上げても、排熱の計算だけは一度も外したことがない。怒鳴らず、迷わず、決めたら最短で走る。耐熱ジャケットの内側には、焼き付いた基板の破片をお守りとして縫い込んでいる。',
      ),
      findsOneWidget,
    );

    final portrait =
        tester.widget<CharacterPortrait>(find.byType(CharacterPortrait));
    expect(portrait.variant, PortraitVariant.full);
    expect(portrait.height, (640 * 0.42).clamp(240.0, 420.0));
    expect(portrait.height, 268.8);
  });

  testWidgets('fire_2 は紹介カードを出さない', (tester) async {
    await _pumpScreen(
      tester,
      _character(name: 'ブレイズ・ナイト', element: ElementType.fire, seed: 2),
    );

    expect(find.text('プロフィール'), findsNothing);
    expect(find.text(characterBios['fire_0']!), findsNothing);
  });

  testWidgets('water_0 は PixelCharacter にフォールバックしつつプロフィールを表示する',
      (tester) async {
    await _pumpScreen(
      tester,
      _character(name: 'アクア・ナイト', element: ElementType.water, seed: 0),
    );

    expect(find.byType(PixelCharacter), findsOneWidget);
    expect(find.text('プロフィール'), findsOneWidget);
    expect(find.text(characterBios['water_0']!), findsOneWidget);
  });
}
