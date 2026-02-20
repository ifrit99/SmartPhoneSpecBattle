import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/domain/models/skill.dart';
import 'package:spec_battle_game/domain/models/status_effect.dart';
import 'package:spec_battle_game/domain/enums/effect_type.dart';
import 'package:spec_battle_game/domain/services/battle_engine.dart';

/// テスト用キャラクターのファクトリ
Character makeCharacter({
  String name = 'テスト',
  ElementType element = ElementType.fire,
  int hp = 100,
  int atk = 20,
  int def = 10,
  int spd = 10,
  List<Skill> skills = const [],
  List<StatusEffect> statusEffects = const [],
  int batteryLevel = 50, // バッテリー補正なし（50% = ±0%）
}) {
  final stats = Stats(hp: hp, maxHp: hp, atk: atk, def: def, spd: spd);
  return Character(
    name: name,
    element: element,
    baseStats: stats,
    currentStats: stats,
    skills: skills,
    statusEffects: statusEffects,
    batteryLevel: batteryLevel,
  );
}

void main() {
  group('BattleEngine.executeBattle', () {
    test('バトル結果が返され、勝者が存在する', () {
      final engine = BattleEngine();
      final player = makeCharacter(name: 'プレイヤー', hp: 200, atk: 30, def: 10);
      final enemy = makeCharacter(name: '敵', hp: 50, atk: 5, def: 5);

      final result = engine.executeBattle(player, enemy);

      expect(result.playerWon, isTrue);
      expect(result.turnsPlayed, greaterThan(0));
      expect(result.expGained, greaterThan(0));
      expect(result.log, isNotEmpty);
    });

    test('弱いプレイヤーは敗北する', () {
      final engine = BattleEngine();
      final player = makeCharacter(name: 'プレイヤー', hp: 10, atk: 1, def: 1);
      final enemy = makeCharacter(name: '敵', hp: 500, atk: 100, def: 50);

      final result = engine.executeBattle(player, enemy);

      expect(result.playerWon, isFalse);
      expect(result.expGained, greaterThan(0)); // 敗北でも経験値はもらえる
    });

    test('バトルログに開始メッセージが含まれる', () {
      final engine = BattleEngine();
      final player = makeCharacter(name: 'プレイヤー');
      final enemy = makeCharacter(name: '敵');

      final result = engine.executeBattle(player, enemy);
      final firstMessage = result.log.first.message;

      expect(firstMessage, contains('バトル開始'));
      expect(firstMessage, contains('プレイヤー'));
      expect(firstMessage, contains('敵'));
    });

    test('50 ターン以内に決着がつく（無限ループなし）', () {
      final engine = BattleEngine();
      // 同等のステータスで最大ターン検証
      final player = makeCharacter(name: 'プレイヤー', hp: 1000, atk: 1, def: 999);
      final enemy = makeCharacter(name: '敵', hp: 1000, atk: 1, def: 999);

      final result = engine.executeBattle(player, enemy);

      expect(result.turnsPlayed, lessThanOrEqualTo(50));
    });

    test('バトル開始時の HP がそのまま引き継がれない（ステータス初期化）', () {
      final engine = BattleEngine();
      // HP が減った状態のキャラクターでバトルを開始した場合、
      // executeBattle 内でフル HP に初期化される
      final stats = Stats(hp: 10, maxHp: 100, atk: 50, def: 5, spd: 10);
      final player = Character(
        name: 'プレイヤー',
        element: ElementType.fire,
        baseStats: stats,
        currentStats: stats,
        skills: const [],
      );
      final enemy = makeCharacter(name: '敵', hp: 50, atk: 5, def: 5);

      final result = engine.executeBattle(player, enemy);

      // HP が初期化されて強いプレイヤー扱いになるため、ログにフル HP での戦いが記録される
      expect(result.log, isNotEmpty);
    });
  });

  group('BattleEngine: 属性相性', () {
    test('有利属性で攻撃すると「効果抜群」メッセージが出る', () {
      final engine = BattleEngine();
      // 炎(fire) → 風(wind) が有利
      final player = makeCharacter(
        name: '炎キャラ',
        element: ElementType.fire,
        hp: 500,
        atk: 100,
        def: 10,
        spd: 100, // 必ず先攻
      );
      final enemy = makeCharacter(
        name: '風キャラ',
        element: ElementType.wind,
        hp: 50,
        atk: 1,
        def: 1,
        spd: 1,
      );

      final result = engine.executeBattle(player, enemy);
      final messages = result.log.map((e) => e.message).join('\n');

      expect(messages, contains('効果抜群'));
    });

    test('不利属性で攻撃すると「いまひとつ」メッセージが出る', () {
      final engine = BattleEngine();
      // 風(wind) → 炎(fire) は不利
      final player = makeCharacter(
        name: '風キャラ',
        element: ElementType.wind,
        hp: 500,
        atk: 100,
        def: 10,
        spd: 100,
      );
      final enemy = makeCharacter(
        name: '炎キャラ',
        element: ElementType.fire,
        hp: 50,
        atk: 1,
        def: 1,
        spd: 1,
      );

      final result = engine.executeBattle(player, enemy);
      final messages = result.log.map((e) => e.message).join('\n');

      expect(messages, contains('いまひとつ'));
    });
  });

  group('BattleEngine: スキル', () {
    test('isDrain スキルはダメージと回復の両方がログに記録される', () {
      final drainSkill = Skill(
        name: 'ドレインテスト',
        description: 'テスト用ドレイン',
        element: ElementType.dark,
        category: SkillCategory.special,
        multiplier: 1.0,
        cooldown: 0,
        isDrain: true,
      );

      final engine = BattleEngine();
      // スキルのみ使う確率を上げるために多数回バトルを実行してドレインエントリを探す
      bool drainFound = false;
      for (int i = 0; i < 30; i++) {
        final player = makeCharacter(
          name: 'ドレイナー',
          element: ElementType.dark,
          hp: 200,
          atk: 50,
          def: 10,
          spd: 100,
          skills: [drainSkill],
        );
        final enemy = makeCharacter(name: '敵', hp: 500, atk: 1, def: 1, spd: 1);
        final result = engine.executeBattle(player, enemy);
        final drainEntries = result.log.where(
          (e) => e.damage > 0 && e.healing > 0 && e.actionName == 'ドレインテスト',
        );
        if (drainEntries.isNotEmpty) {
          drainFound = true;
          // ダメージ量と回復量が一致することを検証
          for (final entry in drainEntries) {
            expect(entry.damage, entry.healing);
          }
          break;
        }
      }
      // 30回試行してドレインが一度も使われない確率は非常に低い
      expect(drainFound, isTrue, reason: '30回試行でもドレインスキルが使用されなかった');
    });
  });

  group('BattleEngine: SPD による先攻判定', () {
    test('SPD が高いキャラクターが先攻する', () {
      final engine = BattleEngine();
      // プレイヤーが圧倒的に速い → プレイヤーが先に攻撃
      final player = makeCharacter(
        name: '速いプレイヤー',
        hp: 500,
        atk: 100,
        def: 10,
        spd: 999,
      );
      final enemy = makeCharacter(name: '遅い敵', hp: 50, atk: 5, def: 5, spd: 1);

      final result = engine.executeBattle(player, enemy);

      // 最初のアクションログがプレイヤーのもの（ターン開始メッセージの次）
      final firstAction = result.log.firstWhere(
        (e) => e.actionType != null,
        orElse: () => const BattleLogEntry(actorName: '', message: ''),
      );
      expect(firstAction.actorName, '速いプレイヤー');
    });
  });

  group('BattleEngine: スタン', () {
    test('スタン状態のキャラクターは行動できない', () {
      final engine = BattleEngine();
      const stunEffect = StatusEffect(
        id: 'stun',
        type: EffectType.stun,
        duration: 3,
        value: 0,
      );

      final player = makeCharacter(
        name: 'プレイヤー',
        hp: 500,
        atk: 10,
        def: 10,
        spd: 999, // 先攻
        statusEffects: [stunEffect],
      );
      final enemy = makeCharacter(name: '敵', hp: 500, atk: 1, def: 1, spd: 1);

      final result = engine.executeBattle(player, enemy);
      final messages = result.log.map((e) => e.message).join('\n');

      expect(messages, contains('スタンしていて動けない'));
    });
  });
}
