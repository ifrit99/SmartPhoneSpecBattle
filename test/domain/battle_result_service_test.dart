import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/data/gacha_device_catalog.dart';
import 'package:spec_battle_game/domain/enums/battle_tactic.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/enums/rarity.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/experience.dart';
import 'package:spec_battle_game/domain/models/gacha_character.dart';
import 'package:spec_battle_game/domain/models/skill.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/domain/services/battle_engine.dart';
import 'package:spec_battle_game/domain/services/battle_result_service.dart';
import 'package:spec_battle_game/domain/services/boss_bounty_service.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';
import 'package:spec_battle_game/domain/services/daily_mission_service.dart';
import 'package:spec_battle_game/domain/services/daily_reward_service.dart';
import 'package:spec_battle_game/domain/services/enemy_generator.dart';
import 'package:spec_battle_game/domain/services/experience_service.dart';
import 'package:spec_battle_game/domain/services/gacha_service.dart';
import 'package:spec_battle_game/domain/services/limited_event_service.dart';
import 'package:spec_battle_game/domain/services/roster_bonus_service.dart';
import 'package:spec_battle_game/domain/services/rival_road_service.dart';
import 'package:spec_battle_game/domain/services/season_pass_service.dart';
import 'package:spec_battle_game/domain/services/weekly_challenge_service.dart';

Character _makeCharacter({
  String name = 'テスト',
  int hp = 100,
  int atk = 20,
  int def = 10,
  int spd = 10,
  int level = 1,
}) {
  final baseStats = Stats(hp: hp, maxHp: hp, atk: atk, def: def, spd: spd);
  return Character(
    name: name,
    element: ElementType.fire,
    baseStats: baseStats,
    currentStats: baseStats.levelUp(level),
    skills: getSkillsForElement(ElementType.fire),
    experience: Experience(level: level),
    seed: 42,
  );
}

GachaCharacter _makeGachaCharacter({
  String id = 'gacha_1',
  int level = 1,
}) {
  return GachaCharacter(
    id: id,
    deviceName: 'Stellar S25',
    rarity: Rarity.sr,
    obtainedAt: DateTime.parse('2026-04-13T00:00:00Z'),
    character: _makeCharacter(name: 'ガチャ戦士', level: level),
  );
}

void main() {
  late LocalStorageService storage;
  late ExperienceService experienceService;
  late CurrencyService currencyService;
  late GachaService gachaService;
  late DailyRewardService dailyRewardService;
  late DailyMissionService dailyMissionService;
  late BossBountyService bossBountyService;
  late WeeklyChallengeService weeklyChallengeService;
  late LimitedEventService limitedEventService;
  late SeasonPassService seasonPassService;
  late RosterBonusService rosterBonusService;
  late RivalRoadService rivalRoadService;
  late BattleResultService battleResultService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    experienceService = ExperienceService(storage);
    currencyService = CurrencyService(storage);
    gachaService = GachaService(currencyService, storage);
    dailyRewardService = DailyRewardService(storage, currencyService);
    dailyMissionService = DailyMissionService(
      storage,
      currencyService,
      now: () => DateTime(2026, 5, 5),
    );
    bossBountyService = BossBountyService(
      storage,
      currencyService,
      now: () => DateTime(2026, 5, 5),
    );
    weeklyChallengeService = WeeklyChallengeService(
      storage,
      currencyService,
      now: () => DateTime(2026, 5, 5),
    );
    limitedEventService = LimitedEventService(
      storage,
      currencyService,
      now: () => DateTime(2026, 5, 5),
    );
    seasonPassService = SeasonPassService(
      storage,
      currencyService,
      now: () => DateTime(2026, 5, 5),
    );
    rosterBonusService = RosterBonusService(storage);
    rivalRoadService = RivalRoadService(storage, currencyService);
    battleResultService = BattleResultService(
      storage,
      experienceService,
      currencyService,
      gachaService,
      dailyRewardService,
      dailyMissionService,
      bossBountyService,
      weeklyChallengeService,
      limitedEventService,
      seasonPassService,
      rivalRoadService: rivalRoadService,
      rosterBonusService: rosterBonusService,
      now: () => DateTime(2026, 5, 5, 12, 30),
    );
  });

  test('実機キャラ使用時は共通経験値が成長する', () async {
    await storage.saveExperience(1, 0, 100);

    final persisted = await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 120),
      enemyDifficulty: EnemyDifficulty.normal,
      isCpuBattle: false,
    );

    final updated = experienceService.loadExperience();
    expect(persisted.levelBefore, 1);
    expect(persisted.levelAfter, 2);
    expect(updated.level, 2);
    expect(updated.currentExp, 20);
  });

  test('装備中ガチャキャラがいるときはそのキャラだけが成長する', () async {
    final gacha = _makeGachaCharacter(level: 1);
    await storage.saveExperience(3, 40, 200);
    await storage.saveGachaCharacters([gacha.toJsonString()]);
    await storage.saveEquippedGachaCharacterId(gacha.id);

    final persisted = await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 120),
      enemyDifficulty: EnemyDifficulty.normal,
      isCpuBattle: false,
    );

    final updatedGacha = gachaService.findById(gacha.id);
    final globalExp = experienceService.loadExperience();

    expect(persisted.levelBefore, 1);
    expect(persisted.levelAfter, 2);
    expect(updatedGacha, isNotNull);
    expect(updatedGacha!.character.level, 2);
    expect(updatedGacha.character.experience.currentExp, 20);
    expect(globalExp.level, 3);
    expect(globalExp.currentExp, 40);
    expect(globalExp.expToNext, 200);
  });

  test('初回バトル時は完了フラグを立てて isFirstBattle を返す', () async {
    expect(storage.isFirstBattleCompleted(), isFalse);

    final persisted = await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: false, expGained: 20),
      enemyDifficulty: EnemyDifficulty.normal,
      isCpuBattle: false,
    );

    expect(persisted.isFirstBattle, isTrue);
    expect(storage.isFirstBattleCompleted(), isTrue);
  });

  test('勝利かつ enemyDeviceId 指定時は撃破済み敵を保存する', () async {
    final persisted = await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 50),
      enemyDifficulty: EnemyDifficulty.hard,
      isCpuBattle: false,
      enemyDeviceId: 'boss_01',
    );

    expect(storage.getDefeatedEnemies(), contains('boss_01'));
    expect(persisted.enemyDiscoveryBonus, isNotNull);
    expect(
      persisted.enemyDiscoveryBonus!.coinsAwarded,
      BattleResultService.firstDefeatBonusCoins,
    );
    expect(
      persisted.enemyDiscoveryBonus!.gemsAwarded,
      BattleResultService.firstDefeatBonusGems,
    );
    expect(
      storage.getCoins(),
      persisted.coinsGained + BattleResultService.firstDefeatBonusCoins,
    );
    expect(storage.getPremiumGems(), BattleResultService.firstDefeatBonusGems);
  });

  test('撃破済みの敵や敗北時は初回撃破ボーナスを付与しない', () async {
    await storage.saveDefeatedEnemy('hard_01');

    final duplicate = await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 50),
      enemyDifficulty: EnemyDifficulty.hard,
      isCpuBattle: false,
      enemyDeviceId: 'hard_01',
    );
    final lost = await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: false, expGained: 20),
      enemyDifficulty: EnemyDifficulty.hard,
      isCpuBattle: false,
      enemyDeviceId: 'hard_02',
    );

    expect(duplicate.enemyDiscoveryBonus, isNull);
    expect(lost.enemyDiscoveryBonus, isNull);
    expect(storage.getDefeatedEnemies(), isNot(contains('hard_02')));
  });

  test('CPU対戦時はデイリーバトル報酬を返す', () async {
    final persisted = await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 50),
      enemyDifficulty: EnemyDifficulty.normal,
      isCpuBattle: true,
    );

    expect(persisted.dailyBattleReward, isNotNull);
    expect(persisted.dailyBattleReward!.gemsAwarded, 15);
  });

  test('装備中ガチャキャラのレベルを基準にコインを計算する', () async {
    final gacha = _makeGachaCharacter(level: 4);
    await storage.saveExperience(10, 0, 550);
    await storage.saveGachaCharacters([gacha.toJsonString()]);
    await storage.saveEquippedGachaCharacterId(gacha.id);

    final persisted = await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 30),
      enemyDifficulty: EnemyDifficulty.normal,
      isCpuBattle: false,
    );

    expect(
      persisted.coinsGained,
      CurrencyService.calcBattleCoins(
        won: true,
        playerLevel: 4,
        difficulty: EnemyDifficulty.normal,
      ),
    );
  });

  test('CPU対戦勝利時は戦術報酬倍率をコインに適用する', () async {
    final persisted = await battleResultService.persistResult(
      battleResult: const BattleResult(
        playerWon: true,
        expGained: 30,
        playerTactic: BattleTactic.overclock,
      ),
      enemyDifficulty: EnemyDifficulty.normal,
      isCpuBattle: true,
    );

    expect(
      persisted.coinsGained,
      CurrencyService.calcBattleCoins(
        won: true,
        playerLevel: 1,
        difficulty: EnemyDifficulty.normal,
        rewardMultiplier: BattleTactic.overclock.rewardMultiplier,
      ),
    );
  });

  test('CPU対戦勝利時はロスター収集ボーナスをコインに適用する', () async {
    await storage.saveGachaCharacters([
      GachaCharacter.fromDevice(gachaDeviceCatalog[0]).toJsonString(),
      GachaCharacter.fromDevice(gachaDeviceCatalog[1]).toJsonString(),
      GachaCharacter.fromDevice(gachaDeviceCatalog[2]).toJsonString(),
    ]);

    final persisted = await battleResultService.persistResult(
      battleResult: const BattleResult(
        playerWon: true,
        expGained: 30,
        playerTactic: BattleTactic.balanced,
      ),
      enemyDifficulty: EnemyDifficulty.normal,
      isCpuBattle: true,
    );

    expect(
      persisted.coinsGained,
      CurrencyService.calcBattleCoins(
        won: true,
        playerLevel: 1,
        difficulty: EnemyDifficulty.normal,
        rewardMultiplier: 1.03,
      ),
    );
  });

  test('バトル結果保存時にデイリーミッションのバトル進捗を記録する', () async {
    await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 30),
      enemyDifficulty: EnemyDifficulty.normal,
      isCpuBattle: false,
    );

    expect(storage.getDailyMissionBattles(), 1);
    expect(storage.getDailyMissionWins(), 1);
  });

  test('バトル結果保存時に直近履歴を記録する', () async {
    await battleResultService.persistResult(
      battleResult: const BattleResult(
        playerWon: true,
        turnsPlayed: 8,
        expGained: 50,
        playerTactic: BattleTactic.burst,
        supportCommand: BattleSupportCommand.overdrive,
      ),
      enemyDifficulty: EnemyDifficulty.hard,
      isCpuBattle: true,
      playerName: 'プレイヤーA',
      enemyName: '強敵B',
    );

    final history = storage.getBattleHistory();

    expect(history, hasLength(1));
    expect(history.first.happenedAt, '2026-05-05T12:30:00.000');
    expect(history.first.playerWon, isTrue);
    expect(history.first.playerName, 'プレイヤーA');
    expect(history.first.enemyName, '強敵B');
    expect(history.first.modeLabel, 'CPU');
    expect(history.first.difficultyLabel, 'HARD');
    expect(history.first.turnsPlayed, 8);
    expect(history.first.expGained, 50);
    expect(history.first.tacticLabel, 'バースト');
    expect(history.first.supportLabel, '攻撃支援');
    expect(history.first.rewardSummary, contains('Coin'));
    expect(history.first.rewardSummary, contains('Gems'));
    expect(history.first.rewardSummary, contains('SP'));
  });

  test('CPUの高難度勝利時は週次チャレンジの進捗を記録する', () async {
    await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 30),
      enemyDifficulty: EnemyDifficulty.hard,
      isCpuBattle: true,
    );
    await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 30),
      enemyDifficulty: EnemyDifficulty.boss,
      isCpuBattle: true,
    );
    await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: false, expGained: 20),
      enemyDifficulty: EnemyDifficulty.hard,
      isCpuBattle: true,
    );

    expect(storage.getWeeklyChallengeWeekId(), '2026-05-04');
    expect(storage.getWeeklyChallengeHighDifficultyWins(), 2);
  });

  test('CPU勝利時は期間イベントの進捗を記録する', () async {
    await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 30),
      enemyDifficulty: EnemyDifficulty.normal,
      isCpuBattle: true,
    );
    await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: false, expGained: 20),
      enemyDifficulty: EnemyDifficulty.normal,
      isCpuBattle: true,
    );
    await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 30),
      enemyDifficulty: EnemyDifficulty.normal,
      isCpuBattle: false,
    );

    expect(storage.getLimitedEventWeekId(), '2026-05-04');
    expect(storage.getLimitedEventWins(), 1);
  });

  test('イベント専用ライバル勝利時は期間イベントを2勝分進める', () async {
    final eventRivalId =
        limitedEventService.loadEvent().definition.rivalEnemyId;

    await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 30),
      enemyDifficulty: EnemyDifficulty.hard,
      enemyDeviceId: eventRivalId,
      isCpuBattle: true,
    );

    expect(storage.getLimitedEventWins(), 2);
  });

  test('ライバルロードの次ステージ勝利時は進捗と報酬を付与する', () async {
    final stage = RivalRoadService.stages.first;

    final persisted = await battleResultService.persistResult(
      battleResult:
          const BattleResult(playerWon: true, expGained: 30, turnsPlayed: 10),
      enemyDifficulty: stage.enemyDevice.difficulty,
      isCpuBattle: true,
      enemyDeviceId: stage.enemyDeviceId,
    );

    expect(storage.getRivalRoadClearedStage(), 1);
    expect(persisted.rivalRoadClearResult, isNotNull);
    expect(persisted.rivalRoadClearResult!.stage.enemyDeviceId,
        stage.enemyDeviceId);
    expect(persisted.rivalRoadClearResult!.stageCleared, isTrue);
    expect(persisted.rivalRoadClearResult!.bestTurnsUpdated, isTrue);
    expect(storage.getRivalRoadBestTurnsForStage(stage.index), 10);
    expect(
      storage.getCoins(),
      persisted.coinsGained +
          stage.rewardCoins +
          BattleResultService.firstDefeatBonusCoins,
    );
    expect(
      storage.getPremiumGems(),
      DailyRewardService.battleRewardGems +
          stage.rewardGems +
          BattleResultService.firstDefeatBonusGems,
    );
  });

  test('クリア済みライバルロード再戦の最短ターン更新を記録する', () async {
    final stage = RivalRoadService.stages.first;
    await storage.setRivalRoadClearedStage(1);
    await storage.setRivalRoadBestTurnsForStage(stage.index, 12);

    final persisted = await battleResultService.persistResult(
      battleResult:
          const BattleResult(playerWon: true, expGained: 30, turnsPlayed: 8),
      enemyDifficulty: stage.enemyDevice.difficulty,
      isCpuBattle: true,
      enemyDeviceId: stage.enemyDeviceId,
    );

    expect(storage.getRivalRoadClearedStage(), 1);
    expect(persisted.rivalRoadClearResult, isNotNull);
    expect(persisted.rivalRoadClearResult!.stageCleared, isFalse);
    expect(persisted.rivalRoadClearResult!.previousBestTurns, 12);
    expect(persisted.rivalRoadClearResult!.bestTurns, 8);
    expect(storage.getRivalRoadBestTurnsForStage(stage.index), 8);
    expect(
        storage.getBattleHistory().first.rewardSummary, contains('Road最短 8T'));
  });

  test('ライバルロードは次ステージ以外の勝利では進まない', () async {
    await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 30),
      enemyDifficulty: EnemyDifficulty.normal,
      isCpuBattle: true,
      enemyDeviceId: 'normal_02',
    );

    expect(storage.getRivalRoadClearedStage(), 0);
  });

  test('バトル結果保存時にシーズンパス進捗を記録する', () async {
    final persisted = await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 30),
      enemyDifficulty: EnemyDifficulty.hard,
      isCpuBattle: true,
    );

    expect(
      persisted.seasonPassXpGained,
      SeasonPassService.baseBattleXp +
          SeasonPassService.winBonusXp +
          SeasonPassService.cpuBattleBonusXp +
          SeasonPassService.highDifficultyBonusXp,
    );
    expect(storage.getSeasonPassId(), '2026-05');
    expect(
      storage.getSeasonPassXp(),
      SeasonPassService.baseBattleXp +
          SeasonPassService.winBonusXp +
          SeasonPassService.cpuBattleBonusXp +
          SeasonPassService.highDifficultyBonusXp,
    );
  });

  test('CPUのBOSS勝利時は1日1回のBOSS撃破報酬を付与する', () async {
    final persisted = await battleResultService.persistResult(
      battleResult:
          const BattleResult(playerWon: true, turnsPlayed: 12, expGained: 30),
      enemyDifficulty: EnemyDifficulty.boss,
      isCpuBattle: true,
    );
    final second = await battleResultService.persistResult(
      battleResult:
          const BattleResult(playerWon: true, turnsPlayed: 14, expGained: 30),
      enemyDifficulty: EnemyDifficulty.boss,
      isCpuBattle: true,
    );

    final baseCoins = CurrencyService.calcBattleCoins(
      won: true,
      playerLevel: 1,
      difficulty: EnemyDifficulty.boss,
    );

    expect(persisted.bossBountyReward, isNotNull);
    expect(
      persisted.bossBountyReward!.coinsAwarded,
      BossBountyService.dailyBossCoins,
    );
    expect(
      persisted.bossBountyReward!.gemsAwarded,
      BossBountyService.dailyBossGems,
    );
    expect(second.bossBountyReward, isNull);
    expect(storage.getLastBossBountyDate(), '2026-05-05');
    expect(persisted.bossRecordUpdate, isNotNull);
    expect(persisted.bossRecordUpdate!.bestTurns, 12);
    expect(persisted.bossRecordUpdate!.previousBestTurns, isNull);
    expect(second.bossRecordUpdate, isNull);
    expect(storage.getBossBestTurns(), 12);
    expect(
        storage.getCoins(), baseCoins * 2 + BossBountyService.dailyBossCoins);
    expect(
      storage.getPremiumGems(),
      DailyRewardService.battleRewardGems + BossBountyService.dailyBossGems,
    );
  });

  test('CPUのBOSS勝利で自己ベストを短縮した場合だけ更新する', () async {
    await storage.setBossBestTurns(18);

    final slower = await battleResultService.persistResult(
      battleResult:
          const BattleResult(playerWon: true, turnsPlayed: 20, expGained: 30),
      enemyDifficulty: EnemyDifficulty.boss,
      isCpuBattle: true,
    );
    final faster = await battleResultService.persistResult(
      battleResult:
          const BattleResult(playerWon: true, turnsPlayed: 15, expGained: 30),
      enemyDifficulty: EnemyDifficulty.boss,
      isCpuBattle: true,
    );

    expect(slower.bossRecordUpdate, isNull);
    expect(faster.bossRecordUpdate, isNotNull);
    expect(faster.bossRecordUpdate!.previousBestTurns, 18);
    expect(faster.bossRecordUpdate!.bestTurns, 15);
    expect(storage.getBossBestTurns(), 15);
  });

  test('敗北やCPU以外のBOSS戦ではBOSS撃破報酬を付与しない', () async {
    final lost = await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: false, expGained: 20),
      enemyDifficulty: EnemyDifficulty.boss,
      isCpuBattle: true,
    );
    final friendBoss = await battleResultService.persistResult(
      battleResult: const BattleResult(playerWon: true, expGained: 30),
      enemyDifficulty: EnemyDifficulty.boss,
      isCpuBattle: false,
    );

    expect(lost.bossBountyReward, isNull);
    expect(friendBoss.bossBountyReward, isNull);
    expect(storage.getLastBossBountyDate(), isNull);
  });

  test('CPU対戦以外では戦術報酬倍率をコインに適用しない', () async {
    final persisted = await battleResultService.persistResult(
      battleResult: const BattleResult(
        playerWon: true,
        expGained: 30,
        playerTactic: BattleTactic.overclock,
      ),
      enemyDifficulty: EnemyDifficulty.normal,
      isCpuBattle: false,
    );

    expect(
      persisted.coinsGained,
      CurrencyService.calcBattleCoins(
        won: true,
        playerLevel: 1,
        difficulty: EnemyDifficulty.normal,
      ),
    );
  });
}
