import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';
import 'package:spec_battle_game/domain/services/enemy_generator.dart';
import 'package:spec_battle_game/domain/services/season_pass_service.dart';

void main() {
  late LocalStorageService storage;
  late CurrencyService currencyService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    currencyService = CurrencyService(storage);
  });

  SeasonPassService serviceFor(DateTime date) {
    return SeasonPassService(
      storage,
      currencyService,
      now: () => date,
    );
  }

  test('初期状態では今月のシーズンパスが未進行', () {
    final service = serviceFor(DateTime(2026, 5, 5));
    final pass = service.loadPass();

    expect(pass.seasonId, '2026-05');
    expect(pass.xp, 0);
    expect(pass.claimableCount, 0);
    expect(pass.rewards.first.definition.requiredXp, 100);
  });

  test('バトル結果でシーズンポイントが加算される', () async {
    final service = serviceFor(DateTime(2026, 5, 5));

    final normalWin = await service.recordBattle(
      won: true,
      isCpuBattle: true,
      difficulty: EnemyDifficulty.normal,
    );
    final bossWin = await service.recordBattle(
      won: true,
      isCpuBattle: true,
      difficulty: EnemyDifficulty.boss,
    );

    expect(
      normalWin,
      SeasonPassService.baseBattleXp +
          SeasonPassService.winBonusXp +
          SeasonPassService.cpuBattleBonusXp,
    );
    expect(bossWin, normalWin + SeasonPassService.highDifficultyBonusXp);
    expect(storage.getSeasonPassId(), '2026-05');
    expect(storage.getSeasonPassXp(), normalWin + bossWin);
    expect(service.loadPass().claimableCount, 1);
  });

  test('解放済み報酬をまとめて受け取れる', () async {
    final service = serviceFor(DateTime(2026, 5, 5));
    await storage.setSeasonPassId('2026-05');
    await storage.setSeasonPassXp(260);

    final result = await service.claimAllAvailable();
    final second = await service.claimAllAvailable();

    expect(result, isNotNull);
    expect(result!.claimedCount, 2);
    expect(result.coinsAwarded, 200);
    expect(result.gemsAwarded, 25);
    expect(storage.getCoins(), 200);
    expect(storage.getPremiumGems(), 25);
    expect(storage.getClaimedSeasonPassRewards(), contains('season_100'));
    expect(storage.getClaimedSeasonPassRewards(), contains('season_250'));
    expect(second, isNull);
  });

  test('月が変わると進捗と受取状態をリセットする', () async {
    await storage.setSeasonPassId('2026-05');
    await storage.setSeasonPassXp(700);
    await storage.saveClaimedSeasonPassRewards(['season_100']);

    final juneService = serviceFor(DateTime(2026, 6, 1));
    await juneService.recordBattle(
      won: false,
      isCpuBattle: false,
      difficulty: EnemyDifficulty.normal,
    );

    expect(storage.getSeasonPassId(), '2026-06');
    expect(storage.getSeasonPassXp(), SeasonPassService.baseBattleXp);
    expect(storage.getClaimedSeasonPassRewards(), isEmpty);
  });
}
