import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/data/device_info_service.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/domain/services/character_generator.dart';
import 'package:spec_battle_game/domain/services/enemy_generator.dart';
import 'package:spec_battle_game/domain/services/power_rating_service.dart';

void main() {
  final service = PowerRatingService();

  group('PowerRatingService.powerScore', () {
    test('編成画面と同一の式でスコアを計算する', () {
      const stats = Stats(hp: 100, maxHp: 100, atk: 20, def: 15, spd: 10);
      // 100*0.35 + 20*3.0 + 15*2.1 + 10*1.6 = 35 + 60 + 31.5 + 16 = 142.5 -> 143
      expect(PowerRatingService.powerScore(stats), 143);
    });
  });

  group('PowerRatingService.estimate', () {
    test('最強クラスのスペックは上位ティアになる', () {
      const specs = DeviceSpecs(
        osVersion: '18',
        cpuCores: 16,
        ramMB: 24576,
        storageFreeGB: 512,
        batteryLevel: 100,
      );
      final rating = service.estimate(CharacterGenerator.generate(specs));

      expect(rating.rank, 1);
      expect(rating.tier, PowerTier.ss);
      expect(rating.topPercent, lessThanOrEqualTo(12));
    });

    test('最弱クラスのスペックは下位ティアになる', () {
      const specs = DeviceSpecs(
        osVersion: '6',
        cpuCores: 1,
        ramMB: 512,
        storageFreeGB: 1,
        batteryLevel: 0,
      );
      final rating = service.estimate(CharacterGenerator.generate(specs));

      expect(rating.rank, rating.populationSize);
      expect(rating.tier, PowerTier.d);
      expect(rating.topPercent, 100);
    });

    test('母集団は全登場端末 + プレイヤーで構成される', () {
      const specs = DeviceSpecs();
      final rating = service.estimate(CharacterGenerator.generate(specs));

      final expectedSize = EnemyGenerator.allEnemyDevices.length + 1;
      expect(rating.populationSize, expectedSize);
      expect(rating.entries.length, expectedSize);
      expect(rating.entries.where((e) => e.isPlayer).length, 1);
    });

    test('ランキングはスコア降順に並び、順位はエントリ位置と一致する', () {
      const specs = DeviceSpecs();
      final rating = service.estimate(CharacterGenerator.generate(specs));

      for (var i = 1; i < rating.entries.length; i++) {
        expect(
          rating.entries[i - 1].score,
          greaterThanOrEqualTo(rating.entries[i].score),
        );
      }

      final playerIndex = rating.entries.indexWhere((e) => e.isPlayer);
      // 同点はプレイヤー有利のため、順位はプレイヤー行の位置以下になる
      expect(rating.rank, lessThanOrEqualTo(playerIndex + 1));
      expect(rating.score, rating.entries[playerIndex].score);
    });

    test('同じスペックなら常に同じ評価を返す（決定論）', () {
      const specs = DeviceSpecs(cpuCores: 8, ramMB: 8192);
      final a = service.estimate(CharacterGenerator.generate(specs));
      final b = service.estimate(CharacterGenerator.generate(specs));

      expect(a.score, b.score);
      expect(a.rank, b.rank);
      expect(a.tier, b.tier);
    });

    test('ローカル推定であることを示すフラグが立っている', () {
      const specs = DeviceSpecs();
      final rating = service.estimate(CharacterGenerator.generate(specs));
      expect(rating.isEstimated, isTrue);
    });
  });
}
