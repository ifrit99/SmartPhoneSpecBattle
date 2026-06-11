import 'dart:math';
import '../models/battle_statistics.dart';
import '../models/character.dart';
import '../models/skill.dart';
import '../models/experience.dart';
import '../models/status_effect.dart';
import '../enums/element_type.dart';
import '../enums/effect_type.dart';
import '../enums/battle_tactic.dart';

/// バトルアクションの種類
enum BattleActionType {
  attack, // 通常攻撃
  defend, // 防御
  skill, // スキル使用
}

/// バトル開始時にプレイヤーが選べる一度きりの支援コマンド
enum BattleSupportCommand {
  none,
  overdrive,
  barrier,
}

extension BattleSupportCommandExtension on BattleSupportCommand {
  String get label {
    return switch (this) {
      BattleSupportCommand.none => '支援なし',
      BattleSupportCommand.overdrive => '攻撃支援',
      BattleSupportCommand.barrier => '防御支援',
    };
  }

  String get description {
    return switch (this) {
      BattleSupportCommand.none => '通常状態で開始',
      BattleSupportCommand.overdrive => '3ターン攻撃力+25% / 素早さ+15%',
      BattleSupportCommand.barrier => '3ターン防御力+35% / 毎ターン5%回復',
    };
  }
}

/// バトルログの1エントリ
class BattleLogEntry {
  final String actorName;
  final BattleActionType? actionType;
  final String actionName;
  final int damage;
  final int healing;
  final String message;
  final bool isCritical;

  const BattleLogEntry({
    required this.actorName,
    this.actionType,
    this.actionName = '',
    this.damage = 0,
    this.healing = 0,
    this.message = '',
    this.isCritical = false,
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
  final int finalPlayerHp;
  final int finalEnemyHp;
  final BattleTactic playerTactic;
  final BattleSupportCommand supportCommand;
  final BattleStatistics statistics;

  const BattleResult({
    required this.playerWon,
    this.turnsPlayed = 0,
    this.expGained = 0,
    this.log = const [],
    this.finalPlayerHp = 0,
    this.finalEnemyHp = 0,
    this.playerTactic = BattleTactic.balanced,
    this.supportCommand = BattleSupportCommand.none,
    this.statistics = const BattleStatistics(),
  });
}

/// バトル進行中に統計値を加算するための内部ビルダー
class _BattleStatsBuilder {
  int playerDamageDealt = 0;
  int enemyDamageDealt = 0;
  int playerCriticalHits = 0;
  int playerSkillCount = 0;
  int playerSkillDamage = 0;
  int playerHealing = 0;
  int elementBonusDamage = 0;
  int elementPenaltyDamage = 0;
  int enemyElementBonusDamage = 0;
  int tacticBonusDamage = 0;
  int tacticGuardedDamage = 0;
  int supportHealing = 0;

  BattleStatistics build() {
    return BattleStatistics(
      playerDamageDealt: playerDamageDealt,
      enemyDamageDealt: enemyDamageDealt,
      playerCriticalHits: playerCriticalHits,
      playerSkillCount: playerSkillCount,
      playerSkillDamage: playerSkillDamage,
      playerHealing: playerHealing,
      elementBonusDamage: elementBonusDamage,
      elementPenaltyDamage: elementPenaltyDamage,
      enemyElementBonusDamage: enemyElementBonusDamage,
      tacticBonusDamage: tacticBonusDamage,
      tacticGuardedDamage: tacticGuardedDamage,
      supportHealing: supportHealing,
    );
  }
}

/// 自動バトルエンジン
class BattleEngine {
  final Random _random = Random();

  // スキルクールダウン管理
  final Map<String, int> _playerCooldowns = {};
  final Map<String, int> _enemyCooldowns = {};

  // バトル統計の収集（executeBattle ごとにリセット）
  _BattleStatsBuilder _stats = _BattleStatsBuilder();

  /// 自動バトルを実行し、結果を返す
  BattleResult executeBattle(
    Character player,
    Character enemy, {
    BattleTactic playerTactic = BattleTactic.balanced,
    BattleSupportCommand supportCommand = BattleSupportCommand.none,
  }) {
    // バトル用ステータスの初期化
    var currentPlayer = player.withHp(player.battleStats.hp);
    var currentEnemy = enemy.withHp(enemy.battleStats.hp);
    _playerCooldowns.clear();
    _enemyCooldowns.clear();
    _stats = _BattleStatsBuilder();

    final log = <BattleLogEntry>[];
    int turn = 0;
    const maxTurns = 50; // 無限ループ防止

    log.add(BattleLogEntry(
      actorName: 'システム',
      message: '⚔️ バトル開始！ ${player.name} vs ${enemy.name}',
    ));
    log.add(BattleLogEntry(
      actorName: 'システム',
      message: '戦術: ${playerTactic.label} - ${playerTactic.description}',
    ));
    if (supportCommand != BattleSupportCommand.none) {
      currentPlayer = _applySupportCommand(currentPlayer, supportCommand, log);
    }

    while (currentPlayer.currentStats.isAlive &&
        currentEnemy.currentStats.isAlive &&
        turn < maxTurns) {
      turn++;
      log.add(
          BattleLogEntry(actorName: 'システム', message: '\n--- ターン $turn ---'));

      // SPDの高い方が先攻（effectiveStatsを使用）
      final playerSpd = currentPlayer.effectiveStats.spd;
      final enemySpd = currentEnemy.effectiveStats.spd;
      final playerFirst = playerSpd >= enemySpd;

      if (playerFirst) {
        // プレイヤーの行動
        final result1 = _executeAction(
          currentPlayer,
          currentEnemy,
          true,
          log,
          playerTactic,
        );
        currentPlayer = result1.$1;
        currentEnemy = result1.$2;

        if (!currentEnemy.currentStats.isAlive) break;

        // 敵の行動
        final result2 = _executeAction(
          currentEnemy,
          currentPlayer,
          false,
          log,
          playerTactic,
        );
        currentEnemy = result2.$1;
        currentPlayer = result2.$2;
      } else {
        // 敵の行動
        final result1 = _executeAction(
          currentEnemy,
          currentPlayer,
          false,
          log,
          playerTactic,
        );
        currentEnemy = result1.$1;
        currentPlayer = result1.$2;

        if (!currentPlayer.currentStats.isAlive) break;

        // プレイヤーの行動
        final result2 = _executeAction(
          currentPlayer,
          currentEnemy,
          true,
          log,
          playerTactic,
        );
        currentPlayer = result2.$1;
        currentEnemy = result2.$2;
      }

      // ターン終了時の処理（バフ経過、クールダウン減少）
      currentPlayer =
          _onTurnEnd(currentPlayer, _playerCooldowns, log, isPlayer: true);
      currentEnemy =
          _onTurnEnd(currentEnemy, _enemyCooldowns, log, isPlayer: false);
    }

    final reachedTurnLimit = turn >= maxTurns &&
        currentPlayer.currentStats.isAlive &&
        currentEnemy.currentStats.isAlive;
    final playerWon = reachedTurnLimit
        ? _resolveTimeoutWinner(currentPlayer, currentEnemy, log)
        : currentPlayer.currentStats.isAlive;
    final expGained =
        Experience.calcBattleExp(won: playerWon, enemyLevel: enemy.level);

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
      finalPlayerHp: currentPlayer.currentStats.hp,
      finalEnemyHp: currentEnemy.currentStats.hp,
      playerTactic: playerTactic,
      supportCommand: supportCommand,
      statistics: _stats.build(),
    );
  }

  /// ダメージイベントを統計に記録する。
  ///
  /// [neutralDamage] は属性倍率を等倍(1.0)にして計算した場合のダメージ、
  /// [untacticDamage] は戦術倍率を適用しない場合のダメージ。
  /// 実ダメージとの差分から属性・戦術それぞれの寄与を求める。
  void _recordDamage({
    required bool attackerIsPlayer,
    required int damage,
    required int neutralDamage,
    required int untacticDamage,
    required double elemMult,
    bool isCritical = false,
    bool isSkill = false,
  }) {
    if (attackerIsPlayer) {
      _stats.playerDamageDealt += damage;
      if (isCritical) _stats.playerCriticalHits++;
      if (isSkill) _stats.playerSkillDamage += damage;
      if (elemMult > 1.0) {
        _stats.elementBonusDamage += damage - neutralDamage;
      } else if (elemMult < 1.0) {
        _stats.elementPenaltyDamage += neutralDamage - damage;
      }
      _stats.tacticBonusDamage += damage - untacticDamage;
    } else {
      _stats.enemyDamageDealt += damage;
      if (elemMult > 1.0) {
        _stats.enemyElementBonusDamage += damage - neutralDamage;
      }
      _stats.tacticGuardedDamage += untacticDamage - damage;
    }
  }

  Character _applySupportCommand(
    Character player,
    BattleSupportCommand supportCommand,
    List<BattleLogEntry> log,
  ) {
    log.add(BattleLogEntry(
      actorName: 'システム',
      message: 'サポート: ${supportCommand.label} - ${supportCommand.description}',
    ));

    switch (supportCommand) {
      case BattleSupportCommand.none:
        return player;
      case BattleSupportCommand.overdrive:
        return _addStatusEffect(
          _addStatusEffect(
            player,
            const StatusEffect(
              id: 'support_overdrive_atk',
              type: EffectType.attackUp,
              duration: 3,
              value: 25,
            ),
          ),
          const StatusEffect(
            id: 'support_overdrive_spd',
            type: EffectType.speedUp,
            duration: 3,
            value: 15,
          ),
        );
      case BattleSupportCommand.barrier:
        return _addStatusEffect(
          _addStatusEffect(
            player,
            const StatusEffect(
              id: 'support_barrier_def',
              type: EffectType.defenseUp,
              duration: 3,
              value: 35,
            ),
          ),
          const StatusEffect(
            id: 'support_barrier_regen',
            type: EffectType.regen,
            duration: 3,
            value: 5,
          ),
        );
    }
  }

  /// ターン終了処理（ステータス効果更新、クールダウン減少）
  Character _onTurnEnd(
    Character char,
    Map<String, int> cooldowns,
    List<BattleLogEntry> log, {
    required bool isPlayer,
  }) {
    // クールダウン減少
    for (final key in cooldowns.keys.toList()) {
      cooldowns[key] = max(0, cooldowns[key]! - 1);
    }

    // ステータス効果の経過
    final newEffects = <StatusEffect>[];
    var currentHp = char.currentStats.hp;
    final maxHp = char.currentStats.maxHp;

    for (final effect in char.statusEffects) {
      // regen: maxHp * value% 回復
      if (effect.type == EffectType.regen) {
        final healAmt = (maxHp * effect.value / 100).round();
        // HP上限で丸めた後の実回復量を統計・ログに使う（満タン時の過大計上を防ぐ）
        final actualHeal = min(maxHp, currentHp + healAmt) - currentHp;
        currentHp += actualHeal;
        if (isPlayer) {
          _stats.playerHealing += actualHeal;
          // 支援コマンド由来のリジェネは個別に記録する
          if (effect.id.startsWith('support_')) {
            _stats.supportHealing += actualHeal;
          }
        }
        if (actualHeal > 0) {
          log.add(BattleLogEntry(
            actorName: char.name,
            healing: actualHeal,
            message:
                '${char.name} は ${effect.type.label} で HP $actualHeal 回復した！',
          ));
        }
      }
      // poison: maxHp * value% ダメージ
      else if (effect.type == EffectType.poison) {
        final dmgAmt = (maxHp * effect.value / 100).round();
        currentHp = max(0, currentHp - dmgAmt);
        log.add(BattleLogEntry(
          actorName: char.name,
          damage: dmgAmt,
          message: '${char.name} は ${effect.type.label} で $dmgAmt ダメージを受けた！',
        ));
      }

      final newEffect = effect.decreaseDuration();
      if (newEffect.duration > 0) {
        newEffects.add(newEffect);
      } else {
        log.add(BattleLogEntry(
          actorName: char.name,
          message: '${char.name} の ${effect.type.label} 効果が切れた。',
        ));
      }
    }
    return char.withHp(currentHp).copyWith(statusEffects: newEffects);
  }

  bool _resolveTimeoutWinner(
    Character player,
    Character enemy,
    List<BattleLogEntry> log,
  ) {
    final playerRatio = player.currentStats.hpPercentage;
    final enemyRatio = enemy.currentStats.hpPercentage;

    log.add(const BattleLogEntry(
      actorName: 'システム',
      message: '\n⏳ 50ターン経過。残HP割合で勝敗を判定する。',
    ));

    if (playerRatio != enemyRatio) {
      return playerRatio > enemyRatio;
    }

    if (player.currentStats.hp != enemy.currentStats.hp) {
      return player.currentStats.hp > enemy.currentStats.hp;
    }

    log.add(const BattleLogEntry(
      actorName: 'システム',
      message: '判定が同率のため、防衛側有利で敵の勝利。',
    ));
    return false;
  }

  /// AIが行動を選択して実行 (戻り値: (Attacker, Defender))
  (Character, Character) _executeAction(
    Character attacker,
    Character defender,
    bool isPlayer,
    List<BattleLogEntry> log,
    BattleTactic playerTactic,
  ) {
    // スタン判定
    if (attacker.statusEffects.any((e) => e.type == EffectType.stun)) {
      log.add(BattleLogEntry(
        actorName: attacker.name,
        message: '${attacker.name} はスタンしていて動けない！',
      ));
      return (attacker, defender);
    }

    final action = _selectAction(attacker, defender, isPlayer, playerTactic);
    switch (action) {
      case BattleActionType.attack:
        return _doAttack(attacker, defender, isPlayer, log, playerTactic);
      case BattleActionType.defend:
        return _doDefend(attacker, defender, isPlayer, log);
      case BattleActionType.skill:
        return _doSkill(attacker, defender, isPlayer, log, playerTactic);
    }
  }

  // ... (省略: _selectAction は変更なし、後で全体を確認)

  /// AIの行動選択ロジック
  BattleActionType _selectAction(
    Character attacker,
    Character defender,
    bool isPlayer,
    BattleTactic playerTactic,
  ) {
    final cooldowns = isPlayer ? _playerCooldowns : _enemyCooldowns;
    final tactic = isPlayer ? playerTactic : BattleTactic.balanced;

    // 使用可能なスキルがあるか確認
    final hasAvailableSkill =
        attacker.skills.any((s) => (cooldowns[s.name] ?? 0) <= 0);

    // HP残量に応じて行動を決定
    final hpRatio = attacker.currentStats.hpPercentage;

    if (hpRatio < 0.3 && _random.nextDouble() < tactic.lowHpDefendChance) {
      return BattleActionType.defend; // HP低い時は防御確率UP
    }
    if (hasAvailableSkill && _random.nextDouble() < tactic.skillChance) {
      // スキル使用確率ちょい上げ
      return BattleActionType.skill;
    }
    if (_random.nextDouble() < tactic.defendChance) {
      return BattleActionType.defend;
    }
    return BattleActionType.attack;
  }

  /// 通常攻撃
  (Character, Character) _doAttack(
    Character attacker,
    Character defender,
    bool isPlayer,
    List<BattleLogEntry> log,
    BattleTactic playerTactic,
  ) {
    final elemMult = elementMultiplier(attacker.element, defender.element);
    final attackerSpd = attacker.effectiveStats.spd;
    final defenderSpd = defender.effectiveStats.spd;

    // クリティカル判定: SPDが相手の1.2倍以上 OR 属性有利で25%の確率
    final critEligible = attackerSpd >= defenderSpd * 1.2 || elemMult > 1.0;
    final isCritical = critEligible && _random.nextDouble() < 0.25;
    final critMult = isCritical ? 1.5 : 1.0;

    // effectiveStatsを使用してダメージ計算
    final rawDamage = attacker.effectiveStats.atk * 1.0 * elemMult * critMult -
        defender.effectiveStats.def * 0.5;
    final damage = _applyTacticDamage(
      max(1, rawDamage.round()),
      attackerIsPlayer: isPlayer,
      defenderIsPlayer: !isPlayer,
      playerTactic: playerTactic,
    );

    // 統計収集: 属性等倍で計算した場合のダメージとの差分で属性寄与を求める
    final neutralRaw = attacker.effectiveStats.atk * 1.0 * critMult -
        defender.effectiveStats.def * 0.5;
    _recordDamage(
      attackerIsPlayer: isPlayer,
      damage: damage,
      neutralDamage: _applyTacticDamage(
        max(1, neutralRaw.round()),
        attackerIsPlayer: isPlayer,
        defenderIsPlayer: !isPlayer,
        playerTactic: playerTactic,
      ),
      untacticDamage: max(1, rawDamage.round()),
      elemMult: elemMult,
      isCritical: isCritical,
    );

    // 属性相性メッセージ
    String elemMsg = '';
    if (elemMult > 1.0) elemMsg = ' 効果抜群！';
    if (elemMult < 1.0) elemMsg = ' いまひとつ…';
    final critMsg = isCritical ? ' クリティカル！' : '';

    log.add(BattleLogEntry(
      actorName: attacker.name,
      actionType: BattleActionType.attack,
      actionName: '攻撃',
      damage: damage,
      message: '${attacker.name} の攻撃！$critMsg $damage ダメージ！$elemMsg',
      isCritical: isCritical,
    ));

    // 相手のHPを減らす
    return (attacker, defender.withHp(defender.currentStats.hp - damage));
  }

  /// 防御（HP微回復 + 防御バフもつける？）
  (Character, Character) _doDefend(
    Character attacker,
    Character defender,
    bool isPlayer,
    List<BattleLogEntry> log,
  ) {
    // 防御時は最大HPの5%回復（HP上限で丸めた実回復量を統計・ログに使う）
    final healAmount = (attacker.currentStats.maxHp * 0.05).round();
    final actualHeal = min(attacker.currentStats.maxHp,
            attacker.currentStats.hp + healAmount) -
        attacker.currentStats.hp;
    if (isPlayer) _stats.playerHealing += actualHeal;

    log.add(BattleLogEntry(
      actorName: attacker.name,
      actionType: BattleActionType.defend,
      actionName: '防御',
      healing: actualHeal,
      message: actualHeal > 0
          ? '${attacker.name} は防御の構えをとった！ HP $actualHeal 回復！'
          : '${attacker.name} は防御の構えをとった！',
    ));

    // 自分のHPを回復
    return (attacker.withHp(attacker.currentStats.hp + actualHeal), defender);
  }

  /// スキル使用
  (Character, Character) _doSkill(
    Character attacker,
    Character defender,
    bool isPlayer,
    List<BattleLogEntry> log,
    BattleTactic playerTactic,
  ) {
    final cooldowns = isPlayer ? _playerCooldowns : _enemyCooldowns;
    final availableSkills =
        attacker.skills.where((s) => (cooldowns[s.name] ?? 0) <= 0).toList();

    // 使用可能スキルがなければ通常攻撃にフォールバック
    if (availableSkills.isEmpty) {
      return _doAttack(attacker, defender, isPlayer, log, playerTactic);
    }

    final skill = availableSkills[_random.nextInt(availableSkills.length)];
    cooldowns[skill.name] = skill.cooldown;
    if (isPlayer) _stats.playerSkillCount++;

    Character newAttacker = attacker;
    Character newDefender = defender;

    // バフ・デバフの付与処理
    final effect = skill.effect;
    if (effect != null) {
      if (skill.isSelfTarget) {
        newAttacker = _addStatusEffect(newAttacker, effect);
        log.add(BattleLogEntry(
          actorName: attacker.name,
          message: '${attacker.name} に ${effect.description} が付与された！',
        ));
      } else {
        newDefender = _addStatusEffect(newDefender, effect);
        log.add(BattleLogEntry(
          actorName: attacker.name,
          message: '${defender.name} に ${effect.description} が付与された！',
        ));
      }
    }

    switch (skill.category) {
      case SkillCategory.attack:
        final elemMult = elementMultiplier(skill.element, defender.element);
        // effectiveStatsを使用
        final rawDamage =
            newAttacker.effectiveStats.atk * skill.multiplier * elemMult -
                newDefender.effectiveStats.def * 0.3;
        final damage = _applyTacticDamage(
          max(1, rawDamage.round()),
          attackerIsPlayer: isPlayer,
          defenderIsPlayer: !isPlayer,
          playerTactic: playerTactic,
        );

        // 統計収集: 属性等倍計算との差分で属性寄与を求める
        final neutralRaw = newAttacker.effectiveStats.atk * skill.multiplier -
            newDefender.effectiveStats.def * 0.3;
        _recordDamage(
          attackerIsPlayer: isPlayer,
          damage: damage,
          neutralDamage: _applyTacticDamage(
            max(1, neutralRaw.round()),
            attackerIsPlayer: isPlayer,
            defenderIsPlayer: !isPlayer,
            playerTactic: playerTactic,
          ),
          untacticDamage: max(1, rawDamage.round()),
          elemMult: elemMult,
          isSkill: true,
        );

        log.add(BattleLogEntry(
          actorName: attacker.name,
          actionType: BattleActionType.skill,
          actionName: skill.name,
          damage: damage,
          message: '${attacker.name} の ${skill.name}！ $damage ダメージ！',
        ));
        newDefender = newDefender.withHp(newDefender.currentStats.hp - damage);
        break;

      case SkillCategory.defense:
        // 防御スキルの場合、ロジック自体はStatusEffectで処理されることが多いが
        // 追加のメッセージや即時効果があればここに記述
        log.add(BattleLogEntry(
          actorName: attacker.name,
          actionType: BattleActionType.skill,
          actionName: skill.name,
          message: '${attacker.name} の ${skill.name}！',
        ));
        break;

      case SkillCategory.special:
        // 回復スキルなど
        if (skill.isSelfTarget && skill.multiplier > 0) {
          // HP上限で丸めた実回復量を統計・ログに使う
          final healAmount =
              (newAttacker.currentStats.maxHp * skill.multiplier).round();
          final actualHeal = min(newAttacker.currentStats.maxHp,
                  newAttacker.currentStats.hp + healAmount) -
              newAttacker.currentStats.hp;
          newAttacker =
              newAttacker.withHp(newAttacker.currentStats.hp + actualHeal);
          if (isPlayer) _stats.playerHealing += actualHeal;

          log.add(BattleLogEntry(
            actorName: attacker.name,
            actionType: BattleActionType.skill,
            actionName: skill.name,
            healing: actualHeal, // ここでヒール数値を渡す
            message: '${attacker.name} の ${skill.name}！ HP $actualHeal 回復！',
          ));
        } else if (!skill.isSelfTarget &&
            skill.multiplier > 0 &&
            skill.category == SkillCategory.special) {
          // HP吸収スキル（isDrain == true）: 敵にダメージを与え、その分だけ自分を回復する
          if (skill.isDrain) {
            final rawDamage = newAttacker.effectiveStats.atk * skill.multiplier;
            final dmg = _applyTacticDamage(
              max(1, rawDamage.round()),
              attackerIsPlayer: isPlayer,
              defenderIsPlayer: !isPlayer,
              playerTactic: playerTactic,
            );

            newDefender = newDefender.withHp(newDefender.currentStats.hp - dmg);
            // 吸収した分だけ回復
            final heal = dmg;
            final newHp = min(newAttacker.currentStats.maxHp,
                newAttacker.currentStats.hp + heal);
            // 統計にはHP上限で丸めた実回復量を使う
            // （ログは「吸収量 = ダメージ量」という演出仕様のため heal のまま）
            final actualHeal = newHp - newAttacker.currentStats.hp;
            newAttacker = newAttacker.withHp(newHp);

            // 統計収集: ドレインは属性・防御を無視するため等倍扱い
            _recordDamage(
              attackerIsPlayer: isPlayer,
              damage: dmg,
              neutralDamage: dmg,
              untacticDamage: max(1, rawDamage.round()),
              elemMult: 1.0,
              isSkill: true,
            );
            if (isPlayer) _stats.playerHealing += actualHeal;

            log.add(BattleLogEntry(
              actorName: attacker.name,
              actionType: BattleActionType.skill,
              actionName: skill.name,
              damage: dmg,
              healing: heal,
              message: '${attacker.name} の ${skill.name}！ $dmg ダメージを与え、体力を奪った！',
            ));
          } else {
            // その他の特殊スキル (バフのみ・デバフのみの場合はここ)
            log.add(BattleLogEntry(
              actorName: attacker.name,
              actionType: BattleActionType.skill,
              actionName: skill.name,
              message: '${attacker.name} の ${skill.name}！',
            ));
          }
        }
        break;
    }

    return (newAttacker, newDefender);
  }

  int _applyTacticDamage(
    int damage, {
    required bool attackerIsPlayer,
    required bool defenderIsPlayer,
    required BattleTactic playerTactic,
  }) {
    var multiplier = 1.0;
    if (attackerIsPlayer) {
      multiplier *= playerTactic.outgoingDamageMultiplier;
    }
    if (defenderIsPlayer) {
      multiplier *= playerTactic.incomingDamageMultiplier;
    }
    return max(1, (damage * multiplier).round());
  }

  Character _addStatusEffect(Character char, StatusEffect effect) {
    final effects = List<StatusEffect>.from(char.statusEffects);
    // 同じIDの効果があれば削除（上書き）
    effects.removeWhere((e) => e.id == effect.id);
    effects.add(effect);
    return char.copyWith(statusEffects: effects);
  }
}
