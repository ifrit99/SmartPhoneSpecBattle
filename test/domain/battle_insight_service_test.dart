import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/enums/battle_tactic.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/models/battle_statistics.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/experience.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/domain/services/battle_engine.dart';
import 'package:spec_battle_game/domain/services/battle_insight_service.dart';

/// テスト用キャラクターのファクトリ
Character makeCharacter({
  String name = 'テスト',
  ElementType element = ElementType.fire,
  int hp = 100,
  int level = 1,
}) {
  final stats = Stats(hp: hp, maxHp: hp, atk: 20, def: 10, spd: 10);
  return Character(
    name: name,
    element: element,
    baseStats: stats,
    currentStats: stats,
    skills: const [],
    experience: Experience(level: level, currentExp: 0, expToNext: 100),
  );
}

/// 合成 BattleResult のファクトリ
BattleResult makeResult({
  required bool playerWon,
  int turnsPlayed = 10,
  int finalEnemyHp = 0,
  BattleTactic playerTactic = BattleTactic.balanced,
  BattleSupportCommand supportCommand = BattleSupportCommand.barrier,
  BattleStatistics statistics = const BattleStatistics(),
}) {
  return BattleResult(
    playerWon: playerWon,
    turnsPlayed: turnsPlayed,
    finalEnemyHp: finalEnemyHp,
    playerTactic: playerTactic,
    supportCommand: supportCommand,
    statistics: statistics,
  );
}

void main() {
  group('BattleInsightService 勝利時ハイライト', () {
    test('属性ボーナスがあれば属性アドバンテージを定量表示する', () {
      final items = BattleInsightService.analyze(
        result: makeResult(
          playerWon: true,
          statistics: const BattleStatistics(
            playerDamageDealt: 500,
            elementBonusDamage: 120,
          ),
        ),
        player: makeCharacter(name: 'プレイヤー'),
        enemy: makeCharacter(name: '敵', element: ElementType.wind),
      );

      expect(items.first.title, '属性アドバンテージ');
      expect(items.first.detail, contains('+120'));
    });

    test('戦術ボーナスがあれば戦術名とダメージ寄与を表示する', () {
      final items = BattleInsightService.analyze(
        result: makeResult(
          playerWon: true,
          playerTactic: BattleTactic.overclock,
          statistics: const BattleStatistics(
            playerDamageDealt: 500,
            tacticBonusDamage: 60,
          ),
        ),
        player: makeCharacter(name: 'プレイヤー'),
        enemy: makeCharacter(name: '敵'),
      );

      expect(items.map((e) => e.title), contains('戦術「オーバークロック」が的中'));
    });

    test('防御支援の回復が貢献していればハイライトする', () {
      final items = BattleInsightService.analyze(
        result: makeResult(
          playerWon: true,
          supportCommand: BattleSupportCommand.barrier,
          statistics: const BattleStatistics(
            playerDamageDealt: 500,
            supportHealing: 80,
          ),
        ),
        player: makeCharacter(name: 'プレイヤー'),
        enemy: makeCharacter(name: '敵'),
      );

      expect(items.map((e) => e.title), contains('防御支援で粘り勝ち'));
    });

    test('特筆事項がなければ地力勝利のフォールバックを返す', () {
      final items = BattleInsightService.analyze(
        result: makeResult(
          playerWon: true,
          supportCommand: BattleSupportCommand.none,
          statistics: const BattleStatistics(playerDamageDealt: 500),
        ),
        player: makeCharacter(name: 'プレイヤー'),
        enemy: makeCharacter(name: '敵'),
      );

      expect(items, hasLength(1));
      expect(items.first.title, '地力で押し切った');
    });

    test('該当が多くても最大3件に絞る', () {
      final items = BattleInsightService.analyze(
        result: makeResult(
          playerWon: true,
          playerTactic: BattleTactic.overclock,
          supportCommand: BattleSupportCommand.overdrive,
          statistics: const BattleStatistics(
            playerDamageDealt: 500,
            playerCriticalHits: 3,
            playerSkillCount: 4,
            playerSkillDamage: 300,
            elementBonusDamage: 100,
            tacticBonusDamage: 60,
          ),
        ),
        player: makeCharacter(name: 'プレイヤー'),
        enemy: makeCharacter(name: '敵', element: ElementType.wind),
      );

      expect(items, hasLength(BattleInsightService.maxItems));
    });
  });

  group('BattleInsightService 敗北時アドバイス', () {
    test('惜敗なら「あと一歩だった」を最優先で表示する', () {
      final items = BattleInsightService.analyze(
        result: makeResult(
          playerWon: false,
          finalEnemyHp: 10, // maxHp 100 の 10%
        ),
        player: makeCharacter(name: 'プレイヤー'),
        enemy: makeCharacter(name: '敵', hp: 100),
      );

      expect(items.first.title, 'あと一歩だった');
      expect(items.first.detail, contains('10'));
    });

    test('属性不利ならカウンター属性を具体的に提案する', () {
      final items = BattleInsightService.analyze(
        result: makeResult(playerWon: false, finalEnemyHp: 40),
        player: makeCharacter(name: 'プレイヤー', element: ElementType.wind),
        enemy: makeCharacter(name: '敵', element: ElementType.fire, hp: 100),
      );

      final advice =
          items.firstWhere((e) => e.title == '属性相性を見直そう');
      // fire に有利を取れるのは water
      expect(advice.detail, contains('水属性'));
      expect(advice.detail, contains('炎属性'));
    });

    test('相手のHPを半分も削れていなければ火力不足を指摘する', () {
      final items = BattleInsightService.analyze(
        result: makeResult(playerWon: false, finalEnemyHp: 70),
        player: makeCharacter(name: 'プレイヤー'),
        enemy: makeCharacter(name: '敵', hp: 100),
      );

      expect(items.map((e) => e.title), contains('火力が足りていない'));
    });

    test('被ダメージ過多ならファイアウォール＋防御支援を提案する', () {
      final items = BattleInsightService.analyze(
        result: makeResult(
          playerWon: false,
          finalEnemyHp: 40,
          statistics: const BattleStatistics(
            playerDamageDealt: 100,
            enemyDamageDealt: 200,
          ),
        ),
        player: makeCharacter(name: 'プレイヤー'),
        enemy: makeCharacter(name: '敵', hp: 100),
      );

      final advice =
          items.firstWhere((e) => e.title == '被ダメージが多すぎた');
      expect(advice.detail, contains('ファイアウォール'));
    });

    test('レベル差が2以上なら育成導線を提示する', () {
      final items = BattleInsightService.analyze(
        result: makeResult(playerWon: false, finalEnemyHp: 40),
        player: makeCharacter(name: 'プレイヤー', level: 1),
        enemy: makeCharacter(name: '敵', hp: 100, level: 4),
      );

      final advice =
          items.firstWhere((e) => e.title == 'レベル差を埋めよう');
      expect(advice.detail, contains('3'));
    });

    test('支援コマンド未使用なら活用を促す', () {
      final items = BattleInsightService.analyze(
        result: makeResult(
          playerWon: false,
          finalEnemyHp: 40,
          supportCommand: BattleSupportCommand.none,
        ),
        player: makeCharacter(name: 'プレイヤー'),
        enemy: makeCharacter(name: '敵', hp: 100),
      );

      expect(items.map((e) => e.title), contains('支援コマンドを活用しよう'));
    });

    test('該当がなければ戦術変更のフォールバックを返す', () {
      final items = BattleInsightService.analyze(
        result: makeResult(
          playerWon: false,
          finalEnemyHp: 40, // 20%超〜50%未満
          statistics: const BattleStatistics(
            playerDamageDealt: 100,
            enemyDamageDealt: 100,
          ),
        ),
        player: makeCharacter(name: 'プレイヤー'),
        enemy: makeCharacter(name: '敵', hp: 100),
      );

      expect(items, hasLength(1));
      expect(items.first.title, '戦術を変えて再挑戦');
    });
  });
}
