import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/services/battle_engine.dart';
import 'package:spec_battle_game/domain/services/character_generator.dart';
import 'package:spec_battle_game/domain/models/experience.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/data/device_info_service.dart';

/// テスト用キャラクターを生成するヘルパー
Character _makeCharacter({
  String name = 'テスト',
  ElementType element = ElementType.fire,
  int hp = 100,
  int atk = 20,
  int def = 10,
  int spd = 10,
}) {
  final stats = Stats(hp: hp, maxHp: hp, atk: atk, def: def, spd: spd);
  return Character(
    name: name,
    element: element,
    baseStats: stats,
    currentStats: stats,
    skills: const [],
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // BattleEngine.executeBattle()
  // ---------------------------------------------------------------------------
  group('BattleEngine.executeBattle()', () {
    test('勝者が決まる（playerWon が true か false のどちらかである）', () {
      final engine = BattleEngine();
      final player = _makeCharacter(name: 'プレイヤー', atk: 50, def: 5);
      final enemy = _makeCharacter(name: '敵', hp: 30, atk: 5, def: 1);
      final result = engine.executeBattle(player, enemy);

      expect(result.playerWon, isTrue); // プレイヤーが大幅有利
      expect(result.turnsPlayed, greaterThan(0));
    });

    test('弱いプレイヤーは負ける', () {
      final engine = BattleEngine();
      final player = _makeCharacter(name: 'プレイヤー', hp: 10, atk: 1, def: 1);
      final enemy = _makeCharacter(name: '敵', atk: 100, def: 50);
      final result = engine.executeBattle(player, enemy);

      expect(result.playerWon, isFalse);
    });

    test('turnsPlayed は 1 以上 50 以下', () {
      final engine = BattleEngine();
      final player = _makeCharacter(name: 'プレイヤー');
      final enemy = _makeCharacter(name: '敵');
      final result = engine.executeBattle(player, enemy);

      expect(result.turnsPlayed, greaterThanOrEqualTo(1));
      expect(result.turnsPlayed, lessThanOrEqualTo(50));
    });

    test('finalPlayerHp と finalEnemyHp の一方は 0', () {
      final engine = BattleEngine();
      final player = _makeCharacter(name: 'プレイヤー', atk: 50, def: 5);
      final enemy = _makeCharacter(name: '敵', hp: 30, atk: 5, def: 1);
      final result = engine.executeBattle(player, enemy);

      // 勝者のHPは0より大きく、敗者のHPは0
      if (result.playerWon) {
        expect(result.finalPlayerHp, greaterThan(0));
        expect(result.finalEnemyHp, equals(0));
      } else {
        expect(result.finalPlayerHp, equals(0));
        expect(result.finalEnemyHp, greaterThan(0));
      }
    });

    test('ログにバトル開始メッセージが含まれる', () {
      final engine = BattleEngine();
      final player = _makeCharacter(name: 'プレイヤー');
      final enemy = _makeCharacter(name: '敵');
      final result = engine.executeBattle(player, enemy);

      expect(result.log, isNotEmpty);
      expect(
        result.log.first.message,
        contains('バトル開始'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // CharacterGenerator
  // ---------------------------------------------------------------------------
  group('CharacterGenerator', () {
    test('同一スペック → 同一名・属性・ステータス', () {
      const specs = DeviceSpecs(osVersion: '14.0', cpuCores: 8, ramMB: 6144);
      final char1 = CharacterGenerator.generate(specs);
      final char2 = CharacterGenerator.generate(specs);

      expect(char1.name, equals(char2.name));
      expect(char1.element, equals(char2.element));
      expect(char1.baseStats.atk, equals(char2.baseStats.atk));
      expect(char1.baseStats.def, equals(char2.baseStats.def));
      expect(char1.baseStats.spd, equals(char2.baseStats.spd));
    });

    test('生成直後は hp == maxHp（分散バグ修正の確認）', () {
      const specs = DeviceSpecs();
      final char = CharacterGenerator.generate(specs);

      expect(char.baseStats.hp, equals(char.baseStats.maxHp));
    });

    test('異なるスペック → 異なるシード値', () {
      const specs1 = DeviceSpecs(cpuCores: 4, ramMB: 2048);
      const specs2 = DeviceSpecs(cpuCores: 8, ramMB: 6144);

      final seed1 = CharacterGenerator.generateSeed(specs1);
      final seed2 = CharacterGenerator.generateSeed(specs2);

      expect(seed1, isNot(equals(seed2)));
    });
  });

  // ---------------------------------------------------------------------------
  // Experience.addExp()
  // ---------------------------------------------------------------------------
  group('Experience.addExp()', () {
    test('非レベルアップ: 経験値が加算されるだけ', () {
      const exp = Experience(level: 1, currentExp: 0, expToNext: 100);
      final updated = exp.addExp(50);

      expect(updated.level, equals(1));
      expect(updated.currentExp, equals(50));
    });

    test('境界値: ちょうど 100 EXP でレベルアップ', () {
      const exp = Experience(level: 1, currentExp: 0, expToNext: 100);
      final updated = exp.addExp(100);

      expect(updated.level, equals(2));
      expect(updated.currentExp, equals(0));
    });

    test('境界値: 99 EXP ではレベルアップしない', () {
      const exp = Experience(level: 1, currentExp: 0, expToNext: 100);
      final updated = exp.addExp(99);

      expect(updated.level, equals(1));
      expect(updated.currentExp, equals(99));
    });

    test('複数レベルアップ: 大量の経験値でスキップ', () {
      const exp = Experience(level: 1, currentExp: 0, expToNext: 100);
      final updated = exp.addExp(500);

      expect(updated.level, greaterThanOrEqualTo(3));
    });

    test('0 EXP 加算は変化なし', () {
      const exp = Experience(level: 5, currentExp: 30, expToNext: 175);
      final updated = exp.addExp(0);

      expect(updated.level, equals(5));
      expect(updated.currentExp, equals(30));
    });

    test('calcBattleExp: 勝利時は敗北時より多い', () {
      final wonExp = Experience.calcBattleExp(won: true, enemyLevel: 1);
      final lostExp = Experience.calcBattleExp(won: false, enemyLevel: 1);

      expect(wonExp, greaterThan(lostExp));
    });

    test('calcBattleExp: 敵レベルが高いほど獲得経験値が多い', () {
      final lowLvExp = Experience.calcBattleExp(won: true, enemyLevel: 1);
      final highLvExp = Experience.calcBattleExp(won: true, enemyLevel: 10);

      expect(highLvExp, greaterThan(lowLvExp));
    });
  });

  // ---------------------------------------------------------------------------
  // elementMultiplier()
  // ---------------------------------------------------------------------------
  group('elementMultiplier()', () {
    test('有利属性: 炎 → 風 は 1.5 倍', () {
      expect(
        elementMultiplier(ElementType.fire, ElementType.wind),
        equals(1.5),
      );
    });

    test('有利属性: 水 → 炎 は 1.5 倍', () {
      expect(
        elementMultiplier(ElementType.water, ElementType.fire),
        equals(1.5),
      );
    });

    test('不利属性: 炎 → 水 は 0.75 倍', () {
      expect(
        elementMultiplier(ElementType.fire, ElementType.water),
        equals(0.75),
      );
    });

    test('不利属性: 風 → 炎 は 0.75 倍', () {
      expect(
        elementMultiplier(ElementType.wind, ElementType.fire),
        equals(0.75),
      );
    });

    test('中立: 同属性は 1.0 倍', () {
      expect(
        elementMultiplier(ElementType.fire, ElementType.fire),
        equals(1.0),
      );
    });

    test('中立: 相性のない組み合わせは 1.0 倍', () {
      // 炎→地 は有利でも不利でもない
      expect(
        elementMultiplier(ElementType.fire, ElementType.earth),
        equals(1.0),
      );
    });

    test('全有利属性ペアが 1.5 倍', () {
      final advantages = {
        ElementType.fire: ElementType.wind,
        ElementType.water: ElementType.fire,
        ElementType.earth: ElementType.light,
        ElementType.wind: ElementType.earth,
        ElementType.light: ElementType.dark,
        ElementType.dark: ElementType.water,
      };
      for (final entry in advantages.entries) {
        expect(
          elementMultiplier(entry.key, entry.value),
          equals(1.5),
          reason: '${entry.key} → ${entry.value} は 1.5 倍であるべき',
        );
      }
    });
  });
}
