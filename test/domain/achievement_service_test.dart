import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/achievement_service.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';

void main() {
  late LocalStorageService storage;
  late CurrencyService currencyService;
  late AchievementService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    currencyService = CurrencyService(storage);
    service = AchievementService(storage, currencyService);
  });

  test('未達成の実績は受け取れない', () async {
    final result = await service.claim('first_battle');

    expect(result, isNull);
    expect(storage.getClaimedAchievements(), isEmpty);
    expect(currencyService.load().coins, 0);
  });

  test('達成済み実績を受け取ると報酬と受取済み状態が保存される', () async {
    await storage.incrementBattleCount();

    final result = await service.claim('first_battle');

    expect(result, isNotNull);
    expect(result!.coinsAwarded, 100);
    expect(result.gemsAwarded, 0);
    expect(currencyService.load().coins, 100);
    expect(storage.getClaimedAchievements(), contains('first_battle'));
  });

  test('同じ実績は二重に受け取れない', () async {
    await storage.incrementBattleCount();

    final first = await service.claim('first_battle');
    final second = await service.claim('first_battle');

    expect(first, isNotNull);
    expect(second, isNull);
    expect(currencyService.load().coins, 100);
  });

  test('実績一覧は進捗・達成・受取状態を返す', () async {
    await storage.incrementBattleCount();
    await service.claim('first_battle');

    final achievements = service.loadAchievements();
    final firstBattle = achievements.firstWhere(
      (achievement) => achievement.definition.id == 'first_battle',
    );
    final battle5 = achievements.firstWhere(
      (achievement) => achievement.definition.id == 'battle_5',
    );

    expect(firstBattle.completed, isTrue);
    expect(firstBattle.claimed, isTrue);
    expect(firstBattle.claimable, isFalse);
    expect(battle5.progress, 1);
    expect(battle5.completed, isFalse);
  });

  test('受け取り可能な実績数を返す', () async {
    await storage.incrementBattleCount();
    await storage.incrementWinCount();

    expect(service.claimableCount(), 2);

    await service.claim('first_battle');

    expect(service.claimableCount(), 1);
  });

  test('ライバルロード進捗で専用実績を達成する', () async {
    await storage.setRivalRoadClearedStage(5);

    final achievements = service.loadAchievements();
    final firstStage = achievements.firstWhere(
      (achievement) => achievement.definition.id == 'rival_road_1',
    );
    final clear = achievements.firstWhere(
      (achievement) => achievement.definition.id == 'rival_road_clear',
    );

    expect(firstStage.completed, isTrue);
    expect(clear.completed, isTrue);

    final result = await service.claim('rival_road_clear');

    expect(result, isNotNull);
    expect(result!.coinsAwarded, 900);
    expect(result.gemsAwarded, 40);
    expect(storage.getClaimedAchievements(), contains('rival_road_clear'));
  });
}
