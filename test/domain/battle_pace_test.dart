import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/data/device_info_service.dart';
import 'package:spec_battle_game/domain/models/experience.dart';
import 'package:spec_battle_game/domain/services/battle_engine.dart';
import 'package:spec_battle_game/domain/services/character_generator.dart';
import 'package:spec_battle_game/domain/services/enemy_generator.dart';

/// バトルテンポの回帰テスト。
///
/// ゴール「1回の対戦が2〜4分程度で終わり、テンポが良い」を
/// シミュレーションで検証する。x1 再生時の所要時間は
/// ログ1件あたり 800ms + スキル演出 1000ms で換算する
/// （battle_screen.dart の _logDelayMs / _skillEffectDelayMs と同じ基準）。
void main() {
  // 標準的なミドルレンジ端末（テンポの代表値計測用）
  const standardSpecs = DeviceSpecs(
    osVersion: '17',
    deviceModel: 'PaceTest Standard',
    cpuCores: 8,
    ramMB: 8192,
    storageFreeGB: 128,
    batteryLevel: 80,
  );

  const trials = 60;
  const playerLevel = 5;

  group('バトルテンポ回帰', () {
    for (final difficulty in EnemyDifficulty.values) {
      test('${difficulty.label}: x1 再生でも4分以内に収まる', () {
        final engine = BattleEngine();
        var totalTurns = 0;
        var totalEntries = 0;
        var totalSkills = 0;
        var wins = 0;
        var maxTurns = 0;

        for (var i = 0; i < trials; i++) {
          final player = CharacterGenerator.generate(
            standardSpecs,
            experience:
                Experience(level: playerLevel, currentExp: 0, expToNext: 100),
          );
          final enemy = EnemyGenerator.generate(
            difficulty: difficulty,
            playerLevel: playerLevel,
          );
          final result = engine.executeBattle(player, enemy.character);

          totalTurns += result.turnsPlayed;
          totalEntries += result.log.length;
          totalSkills += result.log
              .where((e) => e.actionType == BattleActionType.skill)
              .length;
          if (result.playerWon) wins++;
          if (result.turnsPlayed > maxTurns) maxTurns = result.turnsPlayed;
        }

        final avgTurns = totalTurns / trials;
        final avgEntries = totalEntries / trials;
        final avgSkills = totalSkills / trials;
        // x1 再生時の想定所要秒（ログ 0.8s/件 + スキル演出 1.0s/回）
        final avgSeconds = avgEntries * 0.8 + avgSkills * 1.0;

        // 計測値の可視化（テンポ調整の判断材料として出力する）
        // ignore: avoid_print
        print(
          '[pace] ${difficulty.label}: 平均${avgTurns.toStringAsFixed(1)}ターン '
          '(最大$maxTurnsターン) / 平均ログ${avgEntries.toStringAsFixed(1)}件 / '
          'x1想定${avgSeconds.toStringAsFixed(0)}秒 / 勝率${(wins / trials * 100).toStringAsFixed(0)}%',
        );

        // x1 再生でも4分（240秒）以内に終わること
        expect(avgSeconds, lessThanOrEqualTo(240),
            reason: 'x1 再生の平均所要時間が4分を超えている');
        // ターン上限張り付き（テンポ破綻）になっていないこと
        expect(avgTurns, lessThan(45), reason: '平均ターン数が上限に張り付いている');
      });
    }
  });
}
