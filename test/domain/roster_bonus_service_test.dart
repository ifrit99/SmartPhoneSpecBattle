import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/data/gacha_device_catalog.dart';
import 'package:spec_battle_game/domain/enums/rarity.dart';
import 'package:spec_battle_game/domain/models/gacha_character.dart';
import 'package:spec_battle_game/domain/services/roster_bonus_service.dart';

void main() {
  late LocalStorageService storage;
  late RosterBonusService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    service = RosterBonusService(storage);
  });

  test('空ロスターでは収集ボーナスなし', () {
    final summary = service.loadSummary();

    expect(summary.rosterCount, 0);
    expect(summary.unlockedCount, 0);
    expect(summary.coinBonusPercent, 0);
    expect(summary.coinMultiplier, 1.0);
  });

  test('端末種・SSR・限定・覚醒数からコインボーナスを計算する', () {
    final roster = [
      GachaCharacter.fromDevice(gachaDeviceCatalog[0]),
      GachaCharacter.fromDevice(gachaDeviceCatalog[1]),
      GachaCharacter.fromDevice(gachaDeviceCatalog[2]),
      GachaCharacter.fromDevice(gachaDevicesByRarity(Rarity.ssr).first),
      GachaCharacter.fromDevice(eventLimitedDeviceCatalog.first)
          .awaken()
          .awaken()
          .awaken(),
    ];

    final summary = service.calculate(roster);

    expect(summary.uniqueDevices, 5);
    expect(summary.ssrOwned, 2);
    expect(summary.limitedOwned, 1);
    expect(summary.awakeningTotal, 3);
    expect(summary.coinBonusPercent, 15);
    expect(summary.coinMultiplier, 1.15);
  });

  test('保存済みロスターから収集ボーナスを読み込む', () async {
    await storage.saveGachaCharacters([
      GachaCharacter.fromDevice(gachaDeviceCatalog[0]).toJsonString(),
      GachaCharacter.fromDevice(gachaDeviceCatalog[1]).toJsonString(),
      GachaCharacter.fromDevice(gachaDeviceCatalog[2]).toJsonString(),
    ]);

    final summary = service.loadSummary();

    expect(summary.uniqueDevices, 3);
    expect(summary.coinBonusPercent, 3);
  });
}
