import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/models/player_currency.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';
import 'package:spec_battle_game/domain/services/daily_mission_service.dart';
import 'package:spec_battle_game/domain/services/daily_reward_service.dart';
import 'package:spec_battle_game/domain/services/enemy_generator.dart';
import 'package:spec_battle_game/domain/services/gacha_service.dart';
import 'package:spec_battle_game/domain/services/limited_event_service.dart';
import 'package:spec_battle_game/domain/services/season_pass_service.dart';
import 'package:spec_battle_game/domain/services/weekly_challenge_service.dart';

void main() {
  group('Economy balance regression', () {
    test('初回セッションのCPU勝利で単発ガチャとイベント解析に届く', () {
      final battleCoins = CurrencyService.calcBattleCoins(
        won: true,
        playerLevel: 1,
        difficulty: EnemyDifficulty.normal,
      );
      final missionCoins = _dailyMissionCoins('battle_1');
      final firstSessionCoins = battleCoins + missionCoins;

      final firstDayGems = DailyRewardService.loginRewardGems +
          DailyRewardService.battleRewardGems +
          _dailyMissionGems('win_1');

      expect(firstSessionCoins,
          greaterThanOrEqualTo(PlayerCurrency.singlePullCost));
      expect(
          firstDayGems, greaterThanOrEqualTo(PlayerCurrency.premiumPullCost));
      expect(
        firstDayGems,
        greaterThanOrEqualTo(PlayerCurrency.eventLimitedPullCost),
      );
    });

    test('通常CPU勝利3回で単発ガチャ1回分のコインに届く', () {
      final coins = List.generate(
        3,
        (_) => CurrencyService.calcBattleCoins(
          won: true,
          playerLevel: 1,
          difficulty: EnemyDifficulty.normal,
        ),
      ).fold<int>(0, (total, reward) => total + reward);

      expect(coins, greaterThanOrEqualTo(PlayerCurrency.singlePullCost));
      expect(coins ~/ PlayerCurrency.singlePullCost, 1);
    });

    test('7日間のログインとCPU勝利で各ジェム天井を1回ずつ狙える', () {
      final firstWeekLoginGems = DailyRewardService.loginRewardGems * 7 +
          DailyRewardService.streakDay3BonusGems +
          DailyRewardService.streakDay7BonusGems;
      final firstWeekBattleGems = DailyRewardService.battleRewardGems * 7;
      final firstWeekWinMissionGems = _dailyMissionGems('win_1') * 7;
      final firstWeekGems =
          firstWeekLoginGems + firstWeekBattleGems + firstWeekWinMissionGems;

      final premiumFeaturedPityCost = PlayerCurrency.premiumPullCost *
          GachaService.premiumFeaturedPityThreshold;
      final eventLimitedPityCost = PlayerCurrency.eventLimitedPullCost *
          GachaService.eventLimitedPityThreshold;

      expect(firstWeekGems, greaterThanOrEqualTo(premiumFeaturedPityCost));
      expect(firstWeekGems, greaterThanOrEqualTo(eventLimitedPityCost));
      expect(
        firstWeekGems,
        greaterThanOrEqualTo(premiumFeaturedPityCost + eventLimitedPityCost),
      );
    });

    test('週替わりイベント報酬は最低でもイベント解析2回分を返す', () {
      final minEventGems = LimitedEventService.eventRotation
          .map((event) => event.rewardGems)
          .reduce(min);

      expect(
        minEventGems,
        greaterThanOrEqualTo(PlayerCurrency.eventLimitedPullCost * 2),
      );
      expect(
        LimitedEventService.eventRotation.map((event) => event.targetWins),
        everyElement(5),
      );
    });

    test('週次高難度チャレンジ報酬は高難度挑戦の継続に足りる', () {
      expect(
        WeeklyChallengeService.rewardCoins,
        greaterThanOrEqualTo(PlayerCurrency.singlePullCost * 6),
      );
      expect(
        WeeklyChallengeService.rewardGems,
        greaterThanOrEqualTo(PlayerCurrency.premiumPullCost * 2),
      );
      expect(
        WeeklyChallengeService.targetHighDifficultyWins,
        lessThanOrEqualTo(3),
      );
    });

    test('シーズンパス完走報酬は月間プレイの追加目標として成立する', () {
      final totalCoins = SeasonPassService.rewards.fold<int>(
        0,
        (total, reward) => total + reward.coinsReward,
      );
      final totalGems = SeasonPassService.rewards.fold<int>(
        0,
        (total, reward) => total + reward.gemsReward,
      );
      final normalCpuWinXp = SeasonPassService.baseBattleXp +
          SeasonPassService.winBonusXp +
          SeasonPassService.cpuBattleBonusXp;

      expect(totalCoins, greaterThanOrEqualTo(PlayerCurrency.tenPullCost * 2));
      expect(
        totalGems,
        greaterThanOrEqualTo(
          PlayerCurrency.eventLimitedPullCost *
              GachaService.eventLimitedPityThreshold,
        ),
      );
      expect(
        SeasonPassService.rewards.last.requiredXp,
        lessThanOrEqualTo(normalCpuWinXp * 15),
      );
    });
  });
}

int _dailyMissionCoins(String id) => _dailyMission(id).coinsReward;

int _dailyMissionGems(String id) => _dailyMission(id).gemsReward;

DailyMissionDefinition _dailyMission(String id) {
  return DailyMissionService.definitions.firstWhere(
    (definition) => definition.id == id,
  );
}
