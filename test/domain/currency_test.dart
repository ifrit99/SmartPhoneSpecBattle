import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/models/player_currency.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';
import 'package:spec_battle_game/domain/services/enemy_generator.dart';

void main() {
  group('PlayerCurrency', () {
    test('初期値はコイン0、ジェム0', () {
      const currency = PlayerCurrency();
      expect(currency.coins, 0);
      expect(currency.premiumGems, 0);
    });

    test('コインを加算できる', () {
      const currency = PlayerCurrency(coins: 100);
      final updated = currency.addCoins(50);
      expect(updated.coins, 150);
    });

    test('コインを消費できる', () {
      const currency = PlayerCurrency(coins: 200);
      final updated = currency.spendCoins(100);
      expect(updated.coins, 100);
    });

    test('canAffordSingle は 100コイン以上で true', () {
      expect(const PlayerCurrency(coins: 99).canAffordSingle(), false);
      expect(const PlayerCurrency(coins: 100).canAffordSingle(), true);
      expect(const PlayerCurrency(coins: 200).canAffordSingle(), true);
    });

    test('canAffordTenPull は 900コイン以上で true', () {
      expect(const PlayerCurrency(coins: 899).canAffordTenPull(), false);
      expect(const PlayerCurrency(coins: 900).canAffordTenPull(), true);
    });

    test('canAffordPremiumPull は 20ジェム以上で true', () {
      expect(
        const PlayerCurrency(premiumGems: 19).canAffordPremiumPull(),
        false,
      );
      expect(
        const PlayerCurrency(premiumGems: 20).canAffordPremiumPull(),
        true,
      );
    });

    test('canAffordEventLimitedPull は 30ジェム以上で true', () {
      expect(
        const PlayerCurrency(premiumGems: 29).canAffordEventLimitedPull(),
        false,
      );
      expect(
        const PlayerCurrency(premiumGems: 30).canAffordEventLimitedPull(),
        true,
      );
    });

    test('singlePullCost は 100', () {
      expect(PlayerCurrency.singlePullCost, 100);
    });

    test('tenPullCost は 900', () {
      expect(PlayerCurrency.tenPullCost, 900);
    });

    test('premiumPullCost は 20', () {
      expect(PlayerCurrency.premiumPullCost, 20);
    });

    test('eventLimitedPullCost は 30', () {
      expect(PlayerCurrency.eventLimitedPullCost, 30);
    });

    test('ジェムを加算できる', () {
      const currency = PlayerCurrency(premiumGems: 10);
      final updated = currency.addGems(5);
      expect(updated.premiumGems, 15);
    });

    test('ジェムを消費できる', () {
      const currency = PlayerCurrency(premiumGems: 25);
      final updated = currency.spendGems(20);
      expect(updated.premiumGems, 5);
      expect(updated.coins, 0);
    });
  });

  group('CurrencyService.calcBattleCoins', () {
    test('勝利時の基本報酬は 30 + level * 5', () {
      final coins = CurrencyService.calcBattleCoins(
        won: true,
        playerLevel: 1,
        difficulty: EnemyDifficulty.easy,
      );
      // 30 + 1*5 + 0(easy) = 35
      expect(coins, 35);
    });

    test('難易度ボーナスが正しく計算される', () {
      final easy = CurrencyService.calcBattleCoins(
        won: true,
        playerLevel: 5,
        difficulty: EnemyDifficulty.easy,
      );
      final normal = CurrencyService.calcBattleCoins(
        won: true,
        playerLevel: 5,
        difficulty: EnemyDifficulty.normal,
      );
      final hard = CurrencyService.calcBattleCoins(
        won: true,
        playerLevel: 5,
        difficulty: EnemyDifficulty.hard,
      );
      final boss = CurrencyService.calcBattleCoins(
        won: true,
        playerLevel: 5,
        difficulty: EnemyDifficulty.boss,
      );

      // base = 30 + 5*5 = 55
      expect(easy, 55); // +0
      expect(normal, 65); // +10
      expect(hard, 80); // +25
      expect(boss, 105); // +50
    });

    test('敗北時は少量のコインのみ', () {
      final coins = CurrencyService.calcBattleCoins(
        won: false,
        playerLevel: 5,
      );
      // 5 + 5 = 10
      expect(coins, 10);
    });

    test('勝利時は報酬倍率が適用される', () {
      final coins = CurrencyService.calcBattleCoins(
        won: true,
        playerLevel: 5,
        difficulty: EnemyDifficulty.normal,
        rewardMultiplier: 1.2,
      );

      // base 55 + normal 10 = 65, 65 * 1.2 = 78
      expect(coins, 78);
    });

    test('敗北時は報酬倍率が適用されない', () {
      final coins = CurrencyService.calcBattleCoins(
        won: false,
        playerLevel: 5,
        difficulty: EnemyDifficulty.normal,
        rewardMultiplier: 2.0,
      );

      expect(coins, 10);
    });

    test('レベルが上がるほど報酬が増える', () {
      final low = CurrencyService.calcBattleCoins(
        won: true,
        playerLevel: 1,
        difficulty: EnemyDifficulty.normal,
      );
      final high = CurrencyService.calcBattleCoins(
        won: true,
        playerLevel: 10,
        difficulty: EnemyDifficulty.normal,
      );
      expect(high, greaterThan(low));
    });
  });
}
