import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/boss_bounty_service.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';

void main() {
  late LocalStorageService storage;
  late CurrencyService currencyService;
  late BossBountyService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    currencyService = CurrencyService(storage);
    service = BossBountyService(
      storage,
      currencyService,
      now: () => DateTime(2026, 5, 5),
    );
  });

  test('BOSS撃破報酬は1日1回だけ受け取れる', () async {
    final first = await service.claimForBossWin();
    final second = await service.claimForBossWin();

    expect(first, isNotNull);
    expect(first!.coinsAwarded, BossBountyService.dailyBossCoins);
    expect(first.gemsAwarded, BossBountyService.dailyBossGems);
    expect(second, isNull);
    expect(storage.getCoins(), BossBountyService.dailyBossCoins);
    expect(storage.getPremiumGems(), BossBountyService.dailyBossGems);
    expect(storage.getLastBossBountyDate(), '2026-05-05');
  });

  test('日付が変わると再び受け取れる', () async {
    await storage.setLastBossBountyDate('2026-05-04');

    expect(service.canReceiveToday, isTrue);
    final result = await service.claimForBossWin();

    expect(result, isNotNull);
    expect(storage.getLastBossBountyDate(), '2026-05-05');
  });
}
