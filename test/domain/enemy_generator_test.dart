import 'package:flutter_test/flutter_test.dart';

import 'package:spec_battle_game/domain/services/enemy_generator.dart';

void main() {
  group('EnemyGenerator', () {
    test('指定した難易度の敵を生成できる', () {
      for (final difficulty in EnemyDifficulty.values) {
        final profile = EnemyGenerator.generate(
          difficulty: difficulty,
          playerLevel: 5,
        );

        expect(profile.deviceSpec.difficulty, difficulty);
        expect(profile.character.level, greaterThanOrEqualTo(1));
      }
    });

    test('全難易度に図鑑用デバイスが存在する', () {
      for (final difficulty in EnemyDifficulty.values) {
        final count = EnemyGenerator.allEnemyDevices
            .where((device) => device.difficulty == difficulty)
            .length;

        expect(count, greaterThan(0), reason: difficulty.label);
      }
    });

    test('指定したデバイスからイベント用の敵を生成できる', () {
      final device = EnemyGenerator.findById('hard_02');

      final profile = EnemyGenerator.generateFromDeviceSpec(
        deviceSpec: device!,
        playerLevel: 3,
      );

      expect(profile.deviceSpec.id, 'hard_02');
      expect(profile.character.name, isNotEmpty);
      expect(profile.character.level, greaterThanOrEqualTo(1));
    });
  });
}
