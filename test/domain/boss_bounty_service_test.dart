import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/boss_bounty_service.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';

import 'support/throwing_currency_service.dart';

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

  test('claimForBossWinを並列実行しても報酬は二重加算されない', () async {
    final results = await Future.wait([
      service.claimForBossWin(),
      service.claimForBossWin(),
    ]);

    final successful = results.whereType<BossBountyResult>().toList();
    expect(successful.length, 1);
    expect(successful.first.coinsAwarded, BossBountyService.dailyBossCoins);
    expect(successful.first.gemsAwarded, BossBountyService.dailyBossGems);
    expect(storage.getCoins(), BossBountyService.dailyBossCoins);
    expect(storage.getPremiumGems(), BossBountyService.dailyBossGems);
    expect(storage.getLastBossBountyDate(), '2026-05-05');
  });

  test('通貨加算が失敗しても受取済みは残り再受取できない', () async {
    final failingService = BossBountyService(
      storage,
      ThrowingCurrencyService(storage),
      now: () => DateTime(2026, 5, 5),
    );

    await expectLater(
      failingService.claimForBossWin(),
      throwsA(isA<StateError>()),
    );
    expect(storage.getLastBossBountyDate(), '2026-05-05');
    expect(storage.getCoins(), 0);
    expect(storage.getPremiumGems(), 0);
    expect(await failingService.claimForBossWin(), isNull);
  });
}
