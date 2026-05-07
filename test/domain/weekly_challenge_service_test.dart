import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';
import 'package:spec_battle_game/domain/services/enemy_generator.dart';
import 'package:spec_battle_game/domain/services/weekly_challenge_service.dart';

void main() {
  late LocalStorageService storage;
  late CurrencyService currencyService;
  late WeeklyChallengeService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    currencyService = CurrencyService(storage);
    service = WeeklyChallengeService(
      storage,
      currencyService,
      now: () => DateTime(2026, 5, 5),
    );
  });

  test('初期状態では今週の高難度勝利が未達成', () {
    final challenge = service.loadChallenge();

    expect(challenge.weekId, '2026-05-04');
    expect(challenge.wins, 0);
    expect(challenge.targetWins, 3);
    expect(challenge.completed, isFalse);
    expect(challenge.claimable, isFalse);
  });

  test('CPUのHARD/BOSS勝利だけを週次チャレンジに記録する', () async {
    await service.recordBattle(
      won: true,
      isCpuBattle: true,
      difficulty: EnemyDifficulty.normal,
    );
    await service.recordBattle(
      won: false,
      isCpuBattle: true,
      difficulty: EnemyDifficulty.hard,
    );
    await service.recordBattle(
      won: true,
      isCpuBattle: false,
      difficulty: EnemyDifficulty.boss,
    );
    await service.recordBattle(
      won: true,
      isCpuBattle: true,
      difficulty: EnemyDifficulty.hard,
    );
    await service.recordBattle(
      won: true,
      isCpuBattle: true,
      difficulty: EnemyDifficulty.boss,
    );

    expect(storage.getWeeklyChallengeHighDifficultyWins(), 2);
    expect(service.loadChallenge().claimable, isFalse);
  });

  test('週3回の高難度勝利で報酬を受け取れる', () async {
    for (var i = 0; i < WeeklyChallengeService.targetHighDifficultyWins; i++) {
      await service.recordBattle(
        won: true,
        isCpuBattle: true,
        difficulty: EnemyDifficulty.hard,
      );
    }

    final challenge = service.loadChallenge();
    expect(challenge.claimable, isTrue);

    final result = await service.claim();

    expect(result, isNotNull);
    expect(result!.coinsAwarded, WeeklyChallengeService.rewardCoins);
    expect(result.gemsAwarded, WeeklyChallengeService.rewardGems);
    expect(storage.getCoins(), WeeklyChallengeService.rewardCoins);
    expect(storage.getPremiumGems(), WeeklyChallengeService.rewardGems);
    expect(storage.isWeeklyChallengeClaimed(), isTrue);
    expect(service.loadChallenge().claimable, isFalse);
  });

  test('週が変わると進捗と受取状態をリセットする', () async {
    await storage.setWeeklyChallengeWeekId('2026-04-27');
    await storage.setWeeklyChallengeHighDifficultyWins(3);
    await storage.setWeeklyChallengeClaimed(true);

    await service.recordBattle(
      won: true,
      isCpuBattle: true,
      difficulty: EnemyDifficulty.hard,
    );

    expect(storage.getWeeklyChallengeWeekId(), '2026-05-04');
    expect(storage.getWeeklyChallengeHighDifficultyWins(), 1);
    expect(storage.isWeeklyChallengeClaimed(), isFalse);
  });
}
