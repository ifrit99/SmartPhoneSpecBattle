import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/portrait_id.dart';
import 'package:spec_battle_game/domain/models/stats.dart';

/// CharacterGenerator._generateName と同じ接頭語表（seed.abs() % 4 で選ぶ）
const _namePrefixes = {
  ElementType.fire: ['フレア', 'イグニス', 'ブレイズ', 'バーン'],
  ElementType.water: ['アクア', 'ウェイブ', 'タイダル', 'リップル'],
  ElementType.earth: ['テラ', 'ロック', 'ガイア', 'グランド'],
  ElementType.wind: ['ゼファー', 'ブリーズ', 'ストーム', 'ガスト'],
  ElementType.light: ['ルミナ', 'レイ', 'シャイン', 'グロウ'],
  ElementType.dark: ['シャドウ', 'ノクス', 'ダスク', 'ヴォイド'],
};

Character _character({
  ElementType element = ElementType.fire,
  int seed = 0,
}) {
  const stats = Stats(hp: 100, maxHp: 100, atk: 10, def: 10, spd: 10);
  return Character(
    name: 'テスト',
    element: element,
    baseStats: stats,
    currentStats: stats,
    skills: const [],
    seed: seed,
  );
}

void main() {
  group('PortraitId.fromCharacter', () {
    test('同一 seed は同一 key になる', () {
      final a = PortraitId.fromCharacter(_character(seed: 42));
      final b = PortraitId.fromCharacter(_character(seed: 42));
      expect(a.key, b.key);
      expect(a.key, 'fire_2');
    });

    test('負の seed は abs() してから archetype を決める', () {
      final id = PortraitId.fromCharacter(_character(seed: -5));
      expect(id.archetype, 1);
      expect(id.key, 'fire_1');
    });

    test('6属性 × 4アーキタイプの key 範囲に収まる', () {
      for (final element in ElementType.values) {
        for (var seed = 0; seed < 4; seed++) {
          final id = PortraitId.fromCharacter(
            _character(element: element, seed: seed),
          );
          expect(id.archetype, inInclusiveRange(0, 3));
          expect(id.key, '${element.name}_$seed');
          expect(id.fullAsset, 'assets/images/characters/${id.key}_full.png');
          expect(id.bustAsset, 'assets/images/characters/${id.key}_bust.png');
          expect(id.battleAsset, 'assets/images/characters/${id.key}_battle.png');
        }
      }
    });

    test('prefix index は CharacterGenerator の名前接頭語式 seed.abs() % 4 と一致する', () {
      for (final element in ElementType.values) {
        final prefixes = _namePrefixes[element]!;
        for (final seed in [0, 1, 2, 3, 4, 7, -1, -4, -8]) {
          final id = PortraitId.fromCharacter(
            _character(element: element, seed: seed),
          );
          final prefixIndex = seed.abs() % prefixes.length;
          expect(id.archetype, prefixIndex);
          expect(id.archetype, seed.abs() % 4);
          expect(prefixes[id.archetype], prefixes[prefixIndex]);
        }
      }
    });
  });

  group('PortraitId.resolveShippedKey', () {
    const shipped = {
      'fire_0',
      'water_0',
      'earth_0',
      'wind_0',
      'light_0',
      'dark_0',
    };

    test('出荷済み key はそのまま使う', () {
      final id = PortraitId.fromCharacter(_character(seed: 0));
      expect(id.resolveShippedKey(shipped), 'fire_0');
    });

    test('未出荷の archetype は同属性の指揮官 key にフォールバックする', () {
      final id = PortraitId.fromCharacter(_character(seed: 1));
      expect(id.key, 'fire_1');
      expect(id.resolveShippedKey(shipped), 'fire_0');
    });

    test('マニフェストに無ければ null を返す', () {
      final id = PortraitId.fromCharacter(_character(seed: 0));
      expect(id.resolveShippedKey(const {}), isNull);
    });
  });
}
