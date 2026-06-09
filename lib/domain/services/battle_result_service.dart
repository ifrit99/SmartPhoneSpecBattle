import '../../data/local_storage_service.dart';
import '../enums/battle_tactic.dart';
import '../models/gacha_character.dart';
import 'battle_engine.dart';
import 'boss_bounty_service.dart';
import 'currency_service.dart';
import 'daily_mission_service.dart';
import 'daily_reward_service.dart';
import 'enemy_generator.dart';
import 'experience_service.dart';
import 'gacha_service.dart';
import 'limited_event_service.dart';
import 'season_pass_service.dart';
import 'roster_bonus_service.dart';
import 'rival_road_service.dart';
import 'weekly_challenge_service.dart';

/// バトル結果の永続化後にUIへ返すサマリー。
class EnemyDiscoveryBonus {
  final int coinsAwarded;
  final int gemsAwarded;

  const EnemyDiscoveryBonus({
    required this.coinsAwarded,
    required this.gemsAwarded,
  });
}

class BossRecordUpdate {
  final int bestTurns;
  final int? previousBestTurns;

  const BossRecordUpdate({
    required this.bestTurns,
    required this.previousBestTurns,
  });
}

class PersistedBattleResult {
  final int levelBefore;
  final int levelAfter;
  final int coinsGained;
  final bool isFirstBattle;
  final DailyRewardResult? dailyBattleReward;
  final BossBountyResult? bossBountyReward;
  final EnemyDiscoveryBonus? enemyDiscoveryBonus;
  final BossRecordUpdate? bossRecordUpdate;
  final RivalRoadClearResult? rivalRoadClearResult;
  final int seasonPassXpGained;

  const PersistedBattleResult({
    required this.levelBefore,
    required this.levelAfter,
    required this.coinsGained,
    required this.isFirstBattle,
    required this.dailyBattleReward,
    required this.bossBountyReward,
    required this.enemyDiscoveryBonus,
    required this.bossRecordUpdate,
    required this.rivalRoadClearResult,
    required this.seasonPassXpGained,
  });
}

/// バトル終了後の経験値・報酬・戦績反映をまとめて処理するサービス。
class BattleResultService {
  static const int firstDefeatBonusCoins = 120;
  static const int firstDefeatBonusGems = 10;

  final LocalStorageService _storage;
  final ExperienceService _experienceService;
  final CurrencyService _currencyService;
  final GachaService _gachaService;
  final DailyRewardService _dailyRewardService;
  final DailyMissionService? _dailyMissionService;
  final BossBountyService? _bossBountyService;
  final WeeklyChallengeService? _weeklyChallengeService;
  final LimitedEventService? _limitedEventService;
  final SeasonPassService? _seasonPassService;
  final RivalRoadService? _rivalRoadService;
  final RosterBonusService? _rosterBonusService;
  final DateTime Function() _now;

  BattleResultService(
    this._storage,
    this._experienceService,
    this._currencyService,
    this._gachaService,
    this._dailyRewardService,
    this._dailyMissionService,
    this._bossBountyService,
    this._weeklyChallengeService,
    this._limitedEventService,
    this._seasonPassService, {
    RivalRoadService? rivalRoadService,
    RosterBonusService? rosterBonusService,
    DateTime Function()? now,
  })  : _rivalRoadService = rivalRoadService,
        _rosterBonusService = rosterBonusService,
        _now = now ?? DateTime.now;

  Future<PersistedBattleResult> persistResult({
    required BattleResult battleResult,
    required EnemyDifficulty enemyDifficulty,
    required bool isCpuBattle,
    String? enemyDeviceId,
    String? playerName,
    String? enemyName,
  }) async {
    final activeProgression = await _applyExperience(battleResult.expGained);

    final rosterBonusMultiplier = isCpuBattle
        ? (_rosterBonusService?.loadSummary().coinMultiplier ?? 1.0)
        : 1.0;
    final rewardMultiplier = isCpuBattle
        ? battleResult.playerTactic.rewardMultiplier * rosterBonusMultiplier
        : 1.0;
    final coins = CurrencyService.calcBattleCoins(
      won: battleResult.playerWon,
      // コイン報酬は共通レベルではなく、そのバトルで実際に使ったキャラのLv基準。
      playerLevel: activeProgression.$1,
      difficulty: enemyDifficulty,
      rewardMultiplier: rewardMultiplier,
    );
    await _currencyService.addCoins(coins);

    await _experienceService.recordBattle(battleResult.playerWon);
    await _dailyMissionService?.recordBattle(won: battleResult.playerWon);
    await _weeklyChallengeService?.recordBattle(
      won: battleResult.playerWon,
      isCpuBattle: isCpuBattle,
      difficulty: enemyDifficulty,
    );
    await _limitedEventService?.recordBattle(
      won: battleResult.playerWon,
      isCpuBattle: isCpuBattle,
      enemyDeviceId: enemyDeviceId,
    );
    final seasonPassXpGained = await _seasonPassService?.recordBattle(
          won: battleResult.playerWon,
          isCpuBattle: isCpuBattle,
          difficulty: enemyDifficulty,
        ) ??
        0;
    final rivalRoadClearResult = await _rivalRoadService?.recordBattle(
      won: battleResult.playerWon,
      isCpuBattle: isCpuBattle,
      enemyDeviceId: enemyDeviceId,
      turnsPlayed: battleResult.turnsPlayed,
    );

    final enemyDiscoveryBonus = await _recordEnemyDiscoveryBonus(
      won: battleResult.playerWon,
      enemyDeviceId: enemyDeviceId,
    );

    var isFirstBattle = false;
    if (!_storage.isFirstBattleCompleted()) {
      isFirstBattle = true;
      await _storage.setFirstBattleCompleted();
    }

    DailyRewardResult? dailyBattleReward;
    if (isCpuBattle) {
      dailyBattleReward = await _dailyRewardService.claimBattleReward();
    }

    BossBountyResult? bossBountyReward;
    if (isCpuBattle &&
        battleResult.playerWon &&
        enemyDifficulty == EnemyDifficulty.boss) {
      bossBountyReward = await _bossBountyService?.claimForBossWin();
    }

    final bossRecordUpdate = await _recordBossBestTurns(
      battleResult: battleResult,
      enemyDifficulty: enemyDifficulty,
      isCpuBattle: isCpuBattle,
    );

    await _recordBattleHistory(
      battleResult: battleResult,
      enemyDifficulty: enemyDifficulty,
      isCpuBattle: isCpuBattle,
      playerName: playerName,
      enemyName: enemyName,
      coinsGained: coins,
      dailyBattleReward: dailyBattleReward,
      bossBountyReward: bossBountyReward,
      enemyDiscoveryBonus: enemyDiscoveryBonus,
      bossRecordUpdate: bossRecordUpdate,
      rivalRoadClearResult: rivalRoadClearResult,
      seasonPassXpGained: seasonPassXpGained,
    );

    return PersistedBattleResult(
      levelBefore: activeProgression.$1,
      levelAfter: activeProgression.$2,
      coinsGained: coins,
      isFirstBattle: isFirstBattle,
      dailyBattleReward: dailyBattleReward,
      bossBountyReward: bossBountyReward,
      enemyDiscoveryBonus: enemyDiscoveryBonus,
      bossRecordUpdate: bossRecordUpdate,
      rivalRoadClearResult: rivalRoadClearResult,
      seasonPassXpGained: seasonPassXpGained,
    );
  }

  Future<void> _recordBattleHistory({
    required BattleResult battleResult,
    required EnemyDifficulty enemyDifficulty,
    required bool isCpuBattle,
    required String? playerName,
    required String? enemyName,
    required int coinsGained,
    required DailyRewardResult? dailyBattleReward,
    required BossBountyResult? bossBountyReward,
    required EnemyDiscoveryBonus? enemyDiscoveryBonus,
    required BossRecordUpdate? bossRecordUpdate,
    required RivalRoadClearResult? rivalRoadClearResult,
    required int seasonPassXpGained,
  }) async {
    final happenedAt = _now().toIso8601String();
    final battleCount = _storage.getBattleCount();
    final entry = BattleHistoryEntry(
      id: '$happenedAt#$battleCount',
      happenedAt: happenedAt,
      playerWon: battleResult.playerWon,
      playerName: playerName ?? 'プレイヤー',
      enemyName: enemyName ?? '敵',
      modeLabel: isCpuBattle ? 'CPU' : 'フレンド',
      difficultyLabel: enemyDifficulty.label,
      turnsPlayed: battleResult.turnsPlayed,
      expGained: battleResult.expGained,
      coinsGained: coinsGained,
      tacticLabel: battleResult.playerTactic.label,
      supportLabel: battleResult.supportCommand.label,
      rewardSummary: _buildRewardSummary(
        coinsGained: coinsGained,
        dailyBattleReward: dailyBattleReward,
        bossBountyReward: bossBountyReward,
        enemyDiscoveryBonus: enemyDiscoveryBonus,
        bossRecordUpdate: bossRecordUpdate,
        rivalRoadClearResult: rivalRoadClearResult,
        seasonPassXpGained: seasonPassXpGained,
      ),
    );
    await _storage.saveBattleHistoryEntry(entry);
  }

  String _buildRewardSummary({
    required int coinsGained,
    required DailyRewardResult? dailyBattleReward,
    required BossBountyResult? bossBountyReward,
    required EnemyDiscoveryBonus? enemyDiscoveryBonus,
    required BossRecordUpdate? bossRecordUpdate,
    required RivalRoadClearResult? rivalRoadClearResult,
    required int seasonPassXpGained,
  }) {
    final parts = <String>['+$coinsGained Coin'];
    if (seasonPassXpGained > 0) {
      parts.add('+$seasonPassXpGained SP');
    }
    if (dailyBattleReward != null) {
      parts.add('+${dailyBattleReward.gemsAwarded} Gems');
    }
    if (enemyDiscoveryBonus != null) {
      parts.add(
        '初回 +${enemyDiscoveryBonus.coinsAwarded} Coin/+${enemyDiscoveryBonus.gemsAwarded} Gems',
      );
    }
    if (bossBountyReward != null) {
      parts.add(
        'BOSS +${bossBountyReward.coinsAwarded} Coin/+${bossBountyReward.gemsAwarded} Gems',
      );
    }
    if (rivalRoadClearResult != null) {
      final stage = rivalRoadClearResult.stage;
      if (rivalRoadClearResult.stageCleared) {
        parts.add(
          'Road +${stage.rewardCoins} Coin/+${stage.rewardGems} Gems',
        );
      }
      if (rivalRoadClearResult.bestTurnsUpdated) {
        parts.add('Road最短 ${rivalRoadClearResult.bestTurns}T');
      }
    }
    if (bossRecordUpdate != null) {
      parts.add('最短 ${bossRecordUpdate.bestTurns}T');
    }
    return parts.join(' / ');
  }

  Future<BossRecordUpdate?> _recordBossBestTurns({
    required BattleResult battleResult,
    required EnemyDifficulty enemyDifficulty,
    required bool isCpuBattle,
  }) async {
    if (!battleResult.playerWon ||
        !isCpuBattle ||
        enemyDifficulty != EnemyDifficulty.boss ||
        battleResult.turnsPlayed <= 0) {
      return null;
    }

    final previous = _storage.getBossBestTurns();
    if (previous != null && previous <= battleResult.turnsPlayed) return null;

    await _storage.setBossBestTurns(battleResult.turnsPlayed);
    return BossRecordUpdate(
      bestTurns: battleResult.turnsPlayed,
      previousBestTurns: previous,
    );
  }

  Future<EnemyDiscoveryBonus?> _recordEnemyDiscoveryBonus({
    required bool won,
    required String? enemyDeviceId,
  }) async {
    if (!won || enemyDeviceId == null) return null;
    if (_storage.getDefeatedEnemies().contains(enemyDeviceId)) return null;

    await _storage.saveDefeatedEnemy(enemyDeviceId);
    await _currencyService.addCoins(firstDefeatBonusCoins);
    await _currencyService.addGems(firstDefeatBonusGems);

    return const EnemyDiscoveryBonus(
      coinsAwarded: firstDefeatBonusCoins,
      gemsAwarded: firstDefeatBonusGems,
    );
  }

  Future<(int, int)> _applyExperience(int expGained) async {
    final equippedId = _storage.getEquippedGachaCharacterId();
    if (equippedId != null) {
      final equipped = _gachaService.findById(equippedId);
      if (equipped != null) {
        return _applyGachaExperience(equipped, expGained);
      }
    }

    final currentExp = _experienceService.loadExperience();
    final updated = await _experienceService.addExp(currentExp, expGained);
    return (currentExp.level, updated.level);
  }

  Future<(int, int)> _applyGachaExperience(
    GachaCharacter equipped,
    int expGained,
  ) async {
    final updated = equipped.gainExp(expGained);
    await _gachaService.updateCharacter(updated);
    return (equipped.character.level, updated.character.level);
  }
}
