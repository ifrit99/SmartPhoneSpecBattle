import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/data/battle_sprite_anchors.dart';

const _portraitKeys = [
  'fire_0',
  'fire_1',
  'fire_2',
  'fire_3',
  'water_0',
  'water_1',
  'water_2',
  'water_3',
  'earth_0',
  'earth_1',
  'earth_2',
  'earth_3',
  'wind_0',
  'wind_1',
  'wind_2',
  'wind_3',
  'light_0',
  'light_1',
  'light_2',
  'light_3',
  'dark_0',
  'dark_1',
  'dark_2',
  'dark_3',
];

void main() {
  test('24キーすべてで anchorsFor が 0–47 の範囲を返す', () {
    expect(battleSpriteAnchors.keys.toList(), _portraitKeys);
    expect(battleSpriteAnchors.length, 24);

    for (final key in _portraitKeys) {
      final a = anchorsFor(key);
      for (final value in [a.headTopY, a.chestY, a.shoulderY, a.centerX]) {
        expect(value, inInclusiveRange(0, 47), reason: '$key=$value');
      }
    }
  });

  test('未登録キーは既定値', () {
    final a = anchorsFor('missing_9');
    expect(a.headTopY, defaultBattleAnchors.headTopY);
    expect(a.chestY, defaultBattleAnchors.chestY);
    expect(a.shoulderY, defaultBattleAnchors.shoulderY);
    expect(a.centerX, defaultBattleAnchors.centerX);
  });
}
