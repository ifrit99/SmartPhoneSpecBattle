import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/data/gacha_device_catalog.dart';
import 'package:spec_battle_game/domain/models/gacha_character.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';
import 'package:spec_battle_game/domain/services/daily_shop_service.dart';
import 'package:spec_battle_game/domain/services/gacha_service.dart';

void main() {
  late LocalStorageService storage;
  late CurrencyService currencyService;
  late GachaService gachaService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    currencyService = CurrencyService(storage);
    gachaService = GachaService(currencyService, storage);
  });

  DailyShopService serviceFor(DateTime date) {
    return DailyShopService(
      storage,
      currencyService,
      gachaService,
      now: () => date,
    );
  }

  Future<GachaCharacter> equipFirstDevice() async {
    final character =
        GachaCharacter.fromDevice(gachaDeviceCatalog.first).withBattery(45);
    await storage.saveGachaCharacters([character.toJsonString()]);
    await storage.saveEquippedGachaCharacterId(character.id);
    return character;
  }

  test('装備キャラが必要な商品は未装備では購入できない', () async {
    await currencyService.addCoins(1000);
    final service = serviceFor(DateTime(2026, 5, 5));

    final result = await service.purchase('training_report');

    expect(result, isNull);
    final training = service.loadShop().offers.firstWhere(
          (offer) => offer.definition.id == 'training_report',
        );
    expect(training.blockedReason, '装備キャラが必要');
    expect(storage.getCoins(), 1000);
  });

  test('戦術レポートはCoinを消費して装備キャラにEXPを付与する', () async {
    final before = await equipFirstDevice();
    await currencyService.addCoins(500);
    final service = serviceFor(DateTime(2026, 5, 5));

    final result = await service.purchase('training_report');
    final updated = gachaService.findById(before.id);
    final second = await service.purchase('training_report');

    expect(result, isNotNull);
    expect(result!.updatedCurrency.coins, 260);
    expect(updated!.character.experience.currentExp, greaterThan(0));
    expect(storage.getPurchasedDailyShopOffers(), contains('training_report'));
    expect(second, isNull);
    expect(storage.getCoins(), 260);
  });

  test('急速充電パックはBatteryを100まで回復し満タン時は購入不可', () async {
    final before = await equipFirstDevice();
    await currencyService.addCoins(500);
    final service = serviceFor(DateTime(2026, 5, 5));

    final result = await service.purchase('battery_pack');
    final updated = gachaService.findById(before.id);

    expect(result, isNotNull);
    expect(updated!.character.batteryLevel, 85);

    final full = updated.withBattery(100);
    await gachaService.updateCharacter(full);
    final tomorrow = serviceFor(DateTime(2026, 5, 6));
    final offer = tomorrow.loadShop().offers.firstWhere(
          (candidate) => candidate.definition.id == 'battery_pack',
        );

    expect(offer.blockedReason, 'Battery満タン');
  });

  test('解析GemパックはCoinをGemsに変換し日付変更で再購入できる', () async {
    await currencyService.addCoins(800);
    final service = serviceFor(DateTime(2026, 5, 5));

    final first = await service.purchase('gem_cache');
    final duplicate = await service.purchase('gem_cache');
    final tomorrow = serviceFor(DateTime(2026, 5, 6));
    final secondDay = await tomorrow.purchase('gem_cache');

    expect(first, isNotNull);
    expect(first!.updatedCurrency.coins, 440);
    expect(first.updatedCurrency.premiumGems, 8);
    expect(duplicate, isNull);
    expect(secondDay, isNotNull);
    expect(secondDay!.updatedCurrency.coins, 80);
    expect(secondDay.updatedCurrency.premiumGems, 16);
  });
}
