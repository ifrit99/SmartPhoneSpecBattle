import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/enums/battle_tactic.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/skill.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/domain/services/battle_engine.dart';

/// テスト用キャラクターのファクトリ（battle_engine_test.dart と同じパターン）
Character makeCharacter({
  String name = 'テスト',
  ElementType element = ElementType.fire,
  int hp = 100,
  int atk = 20,
  int def = 10,
  int spd = 10,
  List<Skill> skills = const [],
  int batteryLevel = 50,
}) {
  final stats = Stats(hp: hp, maxHp: hp, atk: atk, def: def, spd: spd);
  return Character(
    name: name,
    element: element,
    baseStats: stats,
    currentStats: stats,
    skills: skills,
    batteryLevel: batteryLevel,
  );
}

void main() {
  group('BattleStatistics の収集', () {
    test('与ダメージ・被ダメージ・回復量がログと一致する', () {
      final engine = BattleEngine();
      final player = makeCharacter(name: 'プレイヤー', hp: 300, atk: 25, def: 12);
      final enemy = makeCharacter(name: '敵', hp: 300, atk: 25, def: 12);

      final result = engine.executeBattle(player, enemy);
      final stats = result.statistics;

      // 行動ログ（attack/skill）の damage 合計と統計値が一致する
      int logDamage(String actor) => result.log
          .where((e) => e.actorName == actor && e.actionType != null)
          .fold(0, (sum, e) => sum + e.damage);
      // 回復はログの healing 合計（防御・リジェネ含む）と一致する
      int logHealing(String actor) => result.log
          .where((e) => e.actorName == actor)
          .fold(0, (sum, e) => sum + e.healing);

      expect(stats.playerDamageDealt, logDamage('プレイヤー'));
      expect(stats.enemyDamageDealt, logDamage('敵'));
      expect(stats.playerHealing, logHealing('プレイヤー'));
      expect(stats.playerDamageDealt, greaterThan(0));
    });

    test('属性有利なら elementBonusDamage が正になる', () {
      final engine = BattleEngine();
      // fire は wind に対して1.5倍
      final player = makeCharacter(
          name: 'プレイヤー', element: ElementType.fire, hp: 300, atk: 30);
      final enemy = makeCharacter(
          name: '敵', element: ElementType.wind, hp: 300, atk: 30);

      final stats = engine.executeBattle(player, enemy).statistics;

      expect(stats.elementBonusDamage, greaterThan(0));
      expect(stats.elementPenaltyDamage, 0);
    });

    test('属性不利なら elementPenaltyDamage と enemyElementBonusDamage が正になる', () {
      final engine = BattleEngine();
      // wind は fire に対して0.75倍（相手は1.5倍）
      final player = makeCharacter(
          name: 'プレイヤー', element: ElementType.wind, hp: 300, atk: 30);
      final enemy = makeCharacter(
          name: '敵', element: ElementType.fire, hp: 300, atk: 30);

      final stats = engine.executeBattle(player, enemy).statistics;

      expect(stats.elementPenaltyDamage, greaterThan(0));
      expect(stats.enemyElementBonusDamage, greaterThan(0));
      expect(stats.elementBonusDamage, 0);
    });

    test('等倍属性 + バランス戦術では属性・戦術の差分が出ない', () {
      final engine = BattleEngine();
      final player = makeCharacter(name: 'プレイヤー', hp: 300, atk: 30);
      final enemy = makeCharacter(name: '敵', hp: 300, atk: 30);

      final stats = engine.executeBattle(player, enemy).statistics;

      expect(stats.elementBonusDamage, 0);
      expect(stats.elementPenaltyDamage, 0);
      expect(stats.enemyElementBonusDamage, 0);
      expect(stats.tacticBonusDamage, 0);
      expect(stats.tacticGuardedDamage, 0);
    });

    test('オーバークロックは与ダメージ増・被ダメージ増として記録される', () {
      final engine = BattleEngine();
      final player = makeCharacter(name: 'プレイヤー', hp: 400, atk: 30, def: 10);
      final enemy = makeCharacter(name: '敵', hp: 400, atk: 30, def: 10);

      final stats = engine
          .executeBattle(player, enemy,
              playerTactic: BattleTactic.overclock)
          .statistics;

      expect(stats.tacticBonusDamage, greaterThan(0));
      // 被ダメージ1.1倍 → 軽減量はマイナスになる
      expect(stats.tacticGuardedDamage, lessThan(0));
    });

    test('ファイアウォールは被ダメージ軽減として記録される', () {
      final engine = BattleEngine();
      final player = makeCharacter(name: 'プレイヤー', hp: 400, atk: 30, def: 10);
      final enemy = makeCharacter(name: '敵', hp: 400, atk: 30, def: 10);

      final stats = engine
          .executeBattle(player, enemy, playerTactic: BattleTactic.firewall)
          .statistics;

      expect(stats.tacticGuardedDamage, greaterThan(0));
      // 与ダメージ0.95倍 → ボーナスはマイナスになる
      expect(stats.tacticBonusDamage, lessThan(0));
    });

    test('防御支援のリジェネ回復が supportHealing に記録される', () {
      final engine = BattleEngine();
      final player = makeCharacter(name: 'プレイヤー', hp: 400, atk: 20, def: 15);
      final enemy = makeCharacter(name: '敵', hp: 400, atk: 20, def: 15);

      final stats = engine
          .executeBattle(player, enemy,
              supportCommand: BattleSupportCommand.barrier)
          .statistics;

      expect(stats.supportHealing, greaterThan(0));
      expect(stats.playerHealing, greaterThanOrEqualTo(stats.supportHealing));
    });

    test('スキル使用回数とスキルダメージが記録される', () {
      final engine = BattleEngine();
      final player = makeCharacter(
        name: 'プレイヤー',
        hp: 400,
        atk: 30,
        skills: const [
          Skill(
            name: 'テストスラッシュ',
            description: 'テスト用攻撃スキル',
            category: SkillCategory.attack,
            multiplier: 1.5,
            cooldown: 0,
            element: ElementType.fire,
          ),
        ],
      );
      final enemy = makeCharacter(name: '敵', hp: 400, atk: 25, def: 10);

      // burst はスキル使用率0.7のため、長期戦でスキル未使用は事実上起こらない
      final stats = engine
          .executeBattle(player, enemy, playerTactic: BattleTactic.burst)
          .statistics;

      expect(stats.playerSkillCount, greaterThan(0));
      expect(stats.playerSkillDamage, greaterThan(0));
      expect(stats.playerDamageDealt,
          greaterThanOrEqualTo(stats.playerSkillDamage));
    });
  });
}
