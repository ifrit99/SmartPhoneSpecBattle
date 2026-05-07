import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';

void main() {
  late LocalStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
  });

  test('バックアップコードで主要な進行状況を復元できる', () async {
    await storage.saveExperience(4, 80, 250);
    await storage.incrementBattleCount();
    await storage.incrementWinCount();
    await storage.saveBattleHistoryEntry(
      const BattleHistoryEntry(
        id: 'battle_1',
        happenedAt: '2026-05-05T12:30:00.000',
        playerWon: true,
        playerName: 'プレイヤーA',
        enemyName: '強敵B',
        modeLabel: 'CPU',
        difficultyLabel: 'HARD',
        turnsPlayed: 8,
        expGained: 50,
        coinsGained: 65,
        tacticLabel: 'バースト',
        supportLabel: '攻撃支援',
        rewardSummary: '+65 Coin / +15 Gems',
      ),
    );
    await storage.saveDefeatedEnemy('normal_01');
    await storage.saveCoins(320);
    await storage.savePremiumGems(45);
    await storage.saveGachaCharacters(['{"id":"gacha_1"}']);
    await storage.saveEquippedGachaCharacterId('gacha_1');
    await storage.setPremiumFeaturedMisses(4);
    await storage.setEventLimitedMisses(2);
    await storage.setOnboardingCompleted();
    await storage.setFirstBattleCompleted();
    await storage.setLastLoginRewardDate('2026-05-05');
    await storage.setLastBattleRewardDate('2026-05-05');
    await storage.setLoginStreakDays(7);
    await storage.saveClaimedRankRewards(['hunter']);
    await storage.setRivalRoadClearedStage(3);
    await storage.setRivalRoadBestTurnsForStage(1, 9);
    await storage.setRivalRoadBestTurnsForStage(2, 12);
    await storage.setDailyMissionDate('2026-05-05');
    await storage.setDailyMissionBattles(2);
    await storage.setDailyMissionWins(1);
    await storage.setDailyMissionGachaPulls(3);
    await storage.saveClaimedDailyMissions(['battle_1']);
    await storage.setDailyShopDate('2026-05-05');
    await storage.savePurchasedDailyShopOffers(['training_report']);
    await storage.setWeeklyChallengeWeekId('2026-05-04');
    await storage.setWeeklyChallengeHighDifficultyWins(2);
    await storage.setWeeklyChallengeClaimed(true);
    await storage.setLimitedEventWeekId('2026-05-04');
    await storage.setLimitedEventWins(4);
    await storage.setLimitedEventClaimed(true);
    await storage.saveClaimedLimitedEventMilestones(['event_2_wins']);
    await storage.setSeasonPassId('2026-05');
    await storage.setSeasonPassXp(260);
    await storage.saveClaimedSeasonPassRewards(['season_100']);
    await storage.setLastBossBountyDate('2026-05-05');
    await storage.setBossBestTurns(12);
    await storage.saveClaimedAchievements(['first_battle']);
    await storage.setBgmMuted(true);
    await storage.setSeMuted(true);

    final code = await storage.exportBackupCode();

    await storage.clearAll();
    expect(storage.getCoins(), 0);
    expect(storage.getGachaCharacters(), isEmpty);

    await storage.importBackupCode(code);

    expect(storage.getLevel(), 4);
    expect(storage.getCurrentExp(), 80);
    expect(storage.getExpToNext(), 250);
    expect(storage.getBattleCount(), 1);
    expect(storage.getWinCount(), 1);
    expect(storage.getBattleHistory(), hasLength(1));
    expect(storage.getBattleHistory().first.enemyName, '強敵B');
    expect(
        storage.getBattleHistory().first.rewardSummary, '+65 Coin / +15 Gems');
    expect(storage.getDefeatedEnemies(), ['normal_01']);
    expect(storage.getCoins(), 320);
    expect(storage.getPremiumGems(), 45);
    expect(storage.getGachaCharacters(), ['{"id":"gacha_1"}']);
    expect(storage.getEquippedGachaCharacterId(), 'gacha_1');
    expect(storage.getPremiumFeaturedMisses(), 4);
    expect(storage.getEventLimitedMisses(), 2);
    expect(storage.isOnboardingCompleted(), isTrue);
    expect(storage.isFirstBattleCompleted(), isTrue);
    expect(storage.getLastLoginRewardDate(), '2026-05-05');
    expect(storage.getLastBattleRewardDate(), '2026-05-05');
    expect(storage.getLoginStreakDays(), 7);
    expect(storage.getClaimedRankRewards(), ['hunter']);
    expect(storage.getRivalRoadClearedStage(), 3);
    expect(storage.getRivalRoadBestTurnsForStage(1), 9);
    expect(storage.getRivalRoadBestTurnsForStage(2), 12);
    expect(storage.getDailyMissionDate(), '2026-05-05');
    expect(storage.getDailyMissionBattles(), 2);
    expect(storage.getDailyMissionWins(), 1);
    expect(storage.getDailyMissionGachaPulls(), 3);
    expect(storage.getClaimedDailyMissions(), ['battle_1']);
    expect(storage.getDailyShopDate(), '2026-05-05');
    expect(storage.getPurchasedDailyShopOffers(), ['training_report']);
    expect(storage.getWeeklyChallengeWeekId(), '2026-05-04');
    expect(storage.getWeeklyChallengeHighDifficultyWins(), 2);
    expect(storage.isWeeklyChallengeClaimed(), isTrue);
    expect(storage.getLimitedEventWeekId(), '2026-05-04');
    expect(storage.getLimitedEventWins(), 4);
    expect(storage.isLimitedEventClaimed(), isTrue);
    expect(storage.getClaimedLimitedEventMilestones(), ['event_2_wins']);
    expect(storage.getSeasonPassId(), '2026-05');
    expect(storage.getSeasonPassXp(), 260);
    expect(storage.getClaimedSeasonPassRewards(), ['season_100']);
    expect(storage.getLastBossBountyDate(), '2026-05-05');
    expect(storage.getBossBestTurns(), 12);
    expect(storage.getClaimedAchievements(), ['first_battle']);
    expect(storage.isBgmMuted(), isTrue);
    expect(storage.isSeMuted(), isTrue);
  });

  test('prefixなしのバックアップ本文も復元できる', () async {
    await storage.saveCoins(120);
    final code = await storage.exportBackupCode();
    final body = code.replaceFirst('SPEC-BATTLE-BACKUP:', '');

    await storage.clearAll();
    await storage.importBackupCode(body);

    expect(storage.getCoins(), 120);
  });

  test('対戦履歴は直近20件だけ保持する', () async {
    for (var i = 0; i < 25; i++) {
      await storage.saveBattleHistoryEntry(
        BattleHistoryEntry(
          id: 'battle_$i',
          happenedAt: '2026-05-05T12:${i.toString().padLeft(2, '0')}:00.000',
          playerWon: i.isEven,
          playerName: 'プレイヤー',
          enemyName: '敵$i',
          modeLabel: 'CPU',
          difficultyLabel: 'NORMAL',
          turnsPlayed: i + 1,
          expGained: 30,
          coinsGained: 40,
          tacticLabel: 'バランス',
          supportLabel: '支援なし',
          rewardSummary: '+40 Coin',
        ),
      );
    }

    final history = storage.getBattleHistory();

    expect(history, hasLength(LocalStorageService.maxBattleHistoryEntries));
    expect(history.first.enemyName, '敵24');
    expect(history.last.enemyName, '敵5');
  });

  test('不正なバックアップコードはFormatExceptionになる', () async {
    expect(
      () => storage.importBackupCode('not-a-backup'),
      throwsA(isA<FormatException>()),
    );
  });
}
