import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/presentation/widgets/character_portrait.dart';
import 'package:spec_battle_game/presentation/widgets/pixel_character.dart';

const _gridElements = {
  'fire_0': ElementType.fire,
  'fire_1': ElementType.fire,
  'fire_2': ElementType.fire,
  'fire_3': ElementType.fire,
  'water_0': ElementType.water,
  'water_1': ElementType.water,
  'water_2': ElementType.water,
  'water_3': ElementType.water,
  'earth_0': ElementType.earth,
  'earth_1': ElementType.earth,
  'earth_2': ElementType.earth,
  'earth_3': ElementType.earth,
  'wind_0': ElementType.wind,
  'wind_1': ElementType.wind,
  'wind_2': ElementType.wind,
  'wind_3': ElementType.wind,
  'light_0': ElementType.light,
  'light_1': ElementType.light,
  'light_2': ElementType.light,
  'light_3': ElementType.light,
  'dark_0': ElementType.dark,
  'dark_1': ElementType.dark,
  'dark_2': ElementType.dark,
  'dark_3': ElementType.dark,
};

bool _hasTriad(String key) {
  return File('assets/images/characters/${key}_full.png').existsSync() &&
      File('assets/images/characters/${key}_bust.png').existsSync() &&
      File('assets/images/characters/${key}_battle.png').existsSync();
}

Set<String> _keysWithFullTriad() {
  return {
    for (final key in _gridElements.keys)
      if (_hasTriad(key)) key,
  };
}

MapEntry<String, ElementType> _firstKeyWithoutBustPng() {
  for (final entry in _gridElements.entries) {
    if (!File('assets/images/characters/${entry.key}_bust.png').existsSync()) {
      return entry;
    }
  }
  throw StateError('全キーに bust PNG がある');
}

/// PNG が無く、指揮官フォールバック先も未出荷のキー（PixelCharacter 直出し）。
MapEntry<String, ElementType> _firstUnresolvedKey() {
  final shipped = CharacterPortrait.shippedPortraitKeys;
  for (final entry in _gridElements.entries) {
    if (File('assets/images/characters/${entry.key}_bust.png').existsSync()) {
      continue;
    }
    final commanderKey = '${entry.value.name}_0';
    if (shipped.contains(entry.key) || shipped.contains(commanderKey)) {
      continue;
    }
    return entry;
  }
  throw StateError('マニフェスト外かつ指揮官未出荷のキーが無い');
}

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
  test('shippedPortraitKeys は三揃い PNG があるキーと一致する', () {
    expect(CharacterPortrait.shippedPortraitKeys, _keysWithFullTriad());
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

  testWidgets('未出荷キーはデフォルトマニフェストでも PixelCharacter を描く', (tester) async {
    final missing = _firstUnresolvedKey();
    await _pumpPortrait(
      tester,
      CharacterPortrait(
        character: _character(
          name: missing.key,
          element: missing.value,
          seed: int.parse(missing.key.split('_').last),
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
    final missing = _firstKeyWithoutBustPng();
    await _pumpPortrait(
      tester,
      CharacterPortrait(
        character: _character(
          name: missing.key,
          element: missing.value,
          seed: int.parse(missing.key.split('_').last),
        ),
        variant: PortraitVariant.bust,
        height: 80,
        shippedKeysOverride: {
          ...CharacterPortrait.shippedPortraitKeys,
          missing.key,
        },
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.errorBuilder, isNotNull);
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/characters/${missing.key}_bust.png',
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
