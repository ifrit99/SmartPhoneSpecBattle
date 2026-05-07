import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';
import 'package:spec_battle_game/domain/services/limited_event_service.dart';

void main() {
  late LocalStorageService storage;
  late CurrencyService currencyService;
  late LimitedEventService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    currencyService = CurrencyService(storage);
    service = LimitedEventService(
      storage,
      currencyService,
      now: () => DateTime(2026, 5, 5),
    );
  });

  test('初期状態では今週の期間イベントが未達成', () {
    final event = service.loadEvent();

    expect(event.weekId, '2026-05-04');
    expect(event.definition.title, isNotEmpty);
    expect(event.wins, 0);
    expect(event.definition.targetWins, 5);
    expect(event.daysRemaining, 6);
    expect(event.milestones, hasLength(2));
    expect(event.claimableMilestoneCount, 0);
    expect(event.completed, isFalse);
    expect(event.claimable, isFalse);
  });

  test('CPU勝利だけを期間イベントに記録する', () async {
    await service.recordBattle(won: false, isCpuBattle: true);
    await service.recordBattle(won: true, isCpuBattle: false);
    await service.recordBattle(won: true, isCpuBattle: true);
    await service.recordBattle(won: true, isCpuBattle: true);

    expect(storage.getLimitedEventWins(), 2);
    expect(service.loadEvent().claimable, isFalse);
  });

  test('イベント専用ライバルへの勝利は2勝分進む', () async {
    final event = service.loadEvent();

    await service.recordBattle(
      won: true,
      isCpuBattle: true,
      enemyDeviceId: event.definition.rivalEnemyId,
    );

    expect(storage.getLimitedEventWins(), 2);
    expect(event.definition.rivalEnemy.deviceName, isNotEmpty);
    expect(service.loadEvent().claimableMilestoneCount, 1);
  });

  test('解放済みのイベント段階報酬をまとめて受け取れる', () async {
    await service.recordBattle(
      won: true,
      isCpuBattle: true,
      enemyDeviceId: service.loadEvent().definition.rivalEnemyId,
    );

    final result = await service.claimAvailableMilestones();

    expect(result, isNotNull);
    expect(result!.claimedCount, 1);
    expect(result.coinsAwarded, 200);
    expect(result.gemsAwarded, 0);
    expect(storage.getCoins(), 200);
    expect(storage.getClaimedLimitedEventMilestones(), ['event_2_wins']);
    expect(service.loadEvent().claimableMilestoneCount, 0);
  });

  test('目標勝利数でイベント報酬を受け取れる', () async {
    final targetWins = service.loadEvent().definition.targetWins;
    for (var i = 0; i < targetWins; i++) {
      await service.recordBattle(won: true, isCpuBattle: true);
    }

    final event = service.loadEvent();
    expect(event.claimable, isTrue);

    final result = await service.claim();

    expect(result, isNotNull);
    expect(result!.coinsAwarded, event.definition.rewardCoins);
    expect(result.gemsAwarded, event.definition.rewardGems);
    expect(storage.getCoins(), event.definition.rewardCoins);
    expect(storage.getPremiumGems(), event.definition.rewardGems);
    expect(storage.isLimitedEventClaimed(), isTrue);
    expect(service.loadEvent().claimable, isFalse);
  });

  test('週が変わると進捗と受取状態をリセットする', () async {
    await storage.setLimitedEventWeekId('2026-04-27');
    await storage.setLimitedEventWins(5);
    await storage.setLimitedEventClaimed(true);
    await storage.saveClaimedLimitedEventMilestones(['event_2_wins']);

    await service.recordBattle(won: true, isCpuBattle: true);

    expect(storage.getLimitedEventWeekId(), '2026-05-04');
    expect(storage.getLimitedEventWins(), 1);
    expect(storage.isLimitedEventClaimed(), isFalse);
    expect(storage.getClaimedLimitedEventMilestones(), isEmpty);
  });
}
