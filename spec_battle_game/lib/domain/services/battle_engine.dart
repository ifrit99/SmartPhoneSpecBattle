import 'dart:math';
import '../models/character.dart';
import '../models/skill.dart';
import '../models/experience.dart';
import '../enums/element_type.dart';

/// バトルアクションの種類
enum BattleActionType {
  attack,   // 通常攻撃
  defend,   // 防御
  skill,    // スキル使用
}

/// バトルログの1エントリ
class BattleLogEntry {
  final String actorName;
  final BattleActionType? actionType;
  final String actionName;
  final int damage;
  final int healing;
  final String message;

  BattleLogEntry({
    required this.actorName,
    this.actionType,
    this.actionName = '',
    this.damage = 0,
    this.healing = 0,
    this.message = '',
  });

  @override
  String toString() => message;
}

/// バトルの結果
class BattleResult {
  final bool playerWon;
  final int turnsPlayed;
  final int expGained;
  final List<BattleLogEntry> log;

  BattleResult({
    required this.playerWon,
    this.turnsPlayed = 0,
    this.expGained = 0,
    this.log = const [],
  });
}

/// 自動バトルエンジン
class BattleEngine {
  final Random _random = Random();

  // スキルクールダウン管理
  Map<String, int> _playerCooldowns = {};
  Map<String, int> _enemyCooldowns = {};

  /// 自動バトルを実行し、結果を返す
  BattleResult executeBattle(Character player, Character enemy) {
    // バトル用ステータスの初期化
    var playerStats = player.battleStats;
    var enemyStats = enemy.battleStats;

    var currentPlayer = player.withHp(playerStats.hp);
    var currentEnemy = enemy.withHp(enemyStats.hp);

    _playerCooldowns = {};
    _enemyCooldowns = {};

    final log = <BattleLogEntry>[];
    int turn = 0;
    final maxTurns = 50; // 無限ループ防止

    log.add(BattleLogEntry(
      actorName: 'システム',
      message: '⚔️ バトル開始！ ${player.name} vs ${enemy.name}',
    ));

    while (currentPlayer.currentStats.isAlive &&
        currentEnemy.currentStats.isAlive &&
        turn < maxTurns) {
      turn++;
      log.add(BattleLogEntry(
        actorName: 'システム',
        message: '\n--- ターン $turn ---',
      ));

      // SPDの高い方が先攻
      final playerFirst =
          currentPlayer.currentStats.spd >= currentEnemy.currentStats.spd;

      if (playerFirst) {
        currentEnemy = _executeAction(
            currentPlayer, currentEnemy, true, log);
        if (!currentEnemy.currentStats.isAlive) break;

        currentPlayer = _executeAction(
            currentEnemy, currentPlayer, false, log);
      } else {
        currentPlayer = _executeAction(
            currentEnemy, currentPlayer, false, log);
        if (!currentPlayer.currentStats.isAlive) break;

        currentEnemy = _executeAction(
            currentPlayer, currentEnemy, true, log);
      }

      // クールダウンを減らす
      _reduceCooldowns(_playerCooldowns);
      _reduceCooldowns(_enemyCooldowns);
    }

    final playerWon = currentPlayer.currentStats.isAlive;
    final expGained = Experience.calcBattleExp(
      won: playerWon,
      enemyLevel: enemy.level,
    );

    log.add(BattleLogEntry(
      actorName: 'システム',
      message: playerWon
          ? '\n🎉 ${player.name} の勝利！ 経験値 +$expGained'
          : '\n💀 ${enemy.name} の勝利… 経験値 +$expGained',
    ));

    return BattleResult(
      playerWon: playerWon,
      turnsPlayed: turn,
      expGained: expGained,
      log: log,
    );
  }

  /// AIが行動を選択して実行
  Character _executeAction(
      Character attacker, Character defender, bool isPlayer,
      List<BattleLogEntry> log) {
    final action = _selectAction(attacker, defender, isPlayer);

    switch (action) {
      case BattleActionType.attack:
        return _doAttack(attacker, defender, log);
      case BattleActionType.defend:
        return _doDefend(attacker, defender, log);
      case BattleActionType.skill:
        return _doSkill(attacker, defender, isPlayer, log);
    }
  }

  /// AIの行動選択ロジック
  BattleActionType _selectAction(
      Character attacker, Character defender, bool isPlayer) {
    final cooldowns = isPlayer ? _playerCooldowns : _enemyCooldowns;

    // 使用可能なスキルがあるか確認
    final hasAvailableSkill = attacker.skills.any(
        (s) => (cooldowns[s.name] ?? 0) <= 0);

    // HP残量に応じて行動を決定
    final hpRatio = attacker.currentStats.hpPercentage;

    if (hpRatio < 0.3 && _random.nextDouble() < 0.4) {
      return BattleActionType.defend; // HP低い時は防御確率UP
    }

    if (hasAvailableSkill && _random.nextDouble() < 0.35) {
      return BattleActionType.skill;
    }

    if (_random.nextDouble() < 0.15) {
      return BattleActionType.defend;
    }

    return BattleActionType.attack;
  }

  /// 通常攻撃
  Character _doAttack(
      Character attacker, Character defender, List<BattleLogEntry> log) {
    final elemMult =
        elementMultiplier(attacker.element, defender.element);
    final rawDamage =
        (attacker.currentStats.atk * 1.0 * elemMult -
            defender.currentStats.def * 0.5);
    final damage = max(1, rawDamage.round());
    final newHp = defender.currentStats.hp - damage;

    String elemMsg = '';
    if (elemMult > 1.0) elemMsg = ' 効果抜群！';
    if (elemMult < 1.0) elemMsg = ' いまひとつ…';

    log.add(BattleLogEntry(
      actorName: attacker.name,
      actionType: BattleActionType.attack,
      actionName: '攻撃',
      damage: damage,
      message: '${attacker.name} の攻撃！ $damage ダメージ！$elemMsg',
    ));

    return defender.withHp(newHp);
  }

  /// 防御（次のダメージを半減する代わりにHPを少し回復）
  Character _doDefend(
      Character attacker, Character defender, List<BattleLogEntry> log) {
    final healAmount = (attacker.currentStats.maxHp * 0.05).round();

    log.add(BattleLogEntry(
      actorName: attacker.name,
      actionType: BattleActionType.defend,
      actionName: '防御',
      healing: healAmount,
      message: '${attacker.name} は防御の構えをとった！ HP $healAmount 回復！',
    ));

    // 注意: ここではattackerのHPを回復して返す
    // defender側は変更なし
    return defender;
  }

  /// スキル使用
  Character _doSkill(Character attacker, Character defender,
      bool isPlayer, List<BattleLogEntry> log) {
    final cooldowns = isPlayer ? _playerCooldowns : _enemyCooldowns;

    // 使用可能なスキルを選択
    final availableSkills = attacker.skills
        .where((s) => (cooldowns[s.name] ?? 0) <= 0)
        .toList();

    if (availableSkills.isEmpty) {
      // スキルが使えない場合は通常攻撃にフォールバック
      return _doAttack(attacker, defender, log);
    }

    final skill = availableSkills[_random.nextInt(availableSkills.length)];
    cooldowns[skill.name] = skill.cooldown;

    switch (skill.category) {
      case SkillCategory.attack:
        final elemMult =
            elementMultiplier(skill.element, defender.element);
        final rawDamage =
            (attacker.currentStats.atk * skill.multiplier * elemMult -
                defender.currentStats.def * 0.3);
        final damage = max(1, rawDamage.round());
        final newHp = defender.currentStats.hp - damage;

        log.add(BattleLogEntry(
          actorName: attacker.name,
          actionType: BattleActionType.skill,
          actionName: skill.name,
          damage: damage,
          message: '${attacker.name} の ${skill.name}！ $damage ダメージ！',
        ));

        return defender.withHp(newHp);

      case SkillCategory.defense:
        log.add(BattleLogEntry(
          actorName: attacker.name,
          actionType: BattleActionType.skill,
          actionName: skill.name,
          message: '${attacker.name} の ${skill.name}！ 防御力が上がった！',
        ));
        return defender;

      case SkillCategory.special:
        // 特殊スキル（回復系など）
        final healAmount =
            (attacker.currentStats.maxHp * skill.multiplier).round();
        log.add(BattleLogEntry(
          actorName: attacker.name,
          actionType: BattleActionType.skill,
          actionName: skill.name,
          healing: healAmount,
          message:
              '${attacker.name} の ${skill.name}！ HP $healAmount 回復！',
        ));
        return defender;
    }
  }

  /// クールダウンを1減らす
  void _reduceCooldowns(Map<String, int> cooldowns) {
    final keys = cooldowns.keys.toList();
    for (final key in keys) {
      cooldowns[key] = max(0, cooldowns[key]! - 1);
    }
  }
}
