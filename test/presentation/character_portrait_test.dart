import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/presentation/widgets/character_portrait.dart';
import 'package:spec_battle_game/presentation/widgets/pixel_character.dart';

Character _character({
  String name = 'フレア・ナイト',
  ElementType element = ElementType.fire,
  int seed = 0,
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

Future<void> _pumpPortrait(
  WidgetTester tester,
  CharacterPortrait portrait,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: portrait),
    ),
  );
}

void main() {
  test('shippedPortraitKeys は三揃い PNG がある 9 キーと一致する', () {
    expect(CharacterPortrait.shippedPortraitKeys, {
      'fire_0',
      'fire_1',
      'fire_2',
      'fire_3',
      'water_0',
      'water_1',
      'water_2',
      'earth_0',
      'wind_0',
    });
  });

  testWidgets('マニフェスト外の key では PixelCharacter を描く', (tester) async {
    await _pumpPortrait(
      tester,
      CharacterPortrait(
        character: _character(seed: 0),
        variant: PortraitVariant.bust,
        height: 80,
        shippedKeysOverride: const {},
      ),
    );

    expect(find.byType(PixelCharacter), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('未出荷の light_0 はデフォルトマニフェストでも PixelCharacter を描く',
      (tester) async {
    await _pumpPortrait(
      tester,
      CharacterPortrait(
        character: _character(
          name: 'ルミナ・ナイト',
          element: ElementType.light,
          seed: 0,
        ),
        variant: PortraitVariant.bust,
        height: 80,
      ),
    );

    expect(find.byType(PixelCharacter), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('出荷済み fire_2 は fire_2 のアセットを使い、fire_0 にフォールバックしない',
      (tester) async {
    await _pumpPortrait(
      tester,
      CharacterPortrait(
        character: _character(name: 'ブレイズ・ナイト', seed: 2),
        variant: PortraitVariant.bust,
        height: 80,
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/characters/fire_2_bust.png',
    );
  });

  testWidgets('マニフェスト内の key では Image を使い、欠落時は errorBuilder で PixelCharacter にフォールバックする',
      (tester) async {
    await _pumpPortrait(
      tester,
      CharacterPortrait(
        character: _character(
          name: 'ルミナ・ナイト',
          element: ElementType.light,
          seed: 0,
        ),
        variant: PortraitVariant.bust,
        height: 80,
        shippedKeysOverride: {
          ...CharacterPortrait.shippedPortraitKeys,
          'light_0',
        },
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.errorBuilder, isNotNull);
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/characters/light_0_bust.png',
    );

    await tester.pump();

    expect(find.byType(PixelCharacter), findsOneWidget);
  });

  testWidgets('battle は FilterQuality.none で整数倍サイズを指定する', (tester) async {
    await _pumpPortrait(
      tester,
      CharacterPortrait(
        character: _character(seed: 0),
        variant: PortraitVariant.battle,
        height: 80,
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.filterQuality, FilterQuality.none);
    expect(image.width, 48);
    expect(image.height, 48);
    expect(image.errorBuilder, isNotNull);
  });
}
