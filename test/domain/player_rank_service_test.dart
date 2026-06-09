import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/data/gacha_device_catalog.dart';
import 'package:spec_battle_game/domain/models/gacha_character.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';
import 'package:spec_battle_game/domain/services/player_rank_service.dart';

void main() {
  late LocalStorageService storage;
  late CurrencyService currencyService;
  late PlayerRankService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    currencyService = CurrencyService(storage);
    service = PlayerRankService(storage, currencyService);
  });

  test('初期状態はルーキーランク', () {
    final rank = service.loadRank();

    expect(rank.current.id, 'rookie');
    expect(rank.score, 0);
    expect(rank.next!.id, 'hunter');
    expect(rank.progressToNext, 0);
    expect(rank.claimableRewardCount, 0);
  });

  test('戦績と収集状況からランクポイントを計算する', () async {
    for (var i = 0; i < 8; i++) {
      await storage.incrementBattleCount();
    }
    for (var i = 0; i < 5; i++) {
      await storage.incrementWinCount();
    }
    await storage.saveDefeatedEnemy('easy_01');
    await storage.saveDefeatedEnemy('normal_01');
    await storage.setBossBestTurns(18);

    final rank = service.loadRank();

    expect(rank.score, greaterThanOrEqualTo(120));
    expect(rank.current.id, 'hunter');
    expect(rank.wins, 5);
    expect(rank.discoveredEnemies, 2);
    expect(rank.bossBestTurns, 18);
    expect(rank.claimableRewardCount, 1);
  });

  test('ライバルロード進捗をランクポイントに反映する', () async {
    await storage.setRivalRoadClearedStage(3);

    final rank = service.loadRank();

    expect(rank.rivalRoadClearedStage, 3);
    expect(rank.score, 3 * PlayerRankService.rivalRoadStageScore);
    expect(rank.current.id, 'hunter');
  });

  test('到達済みランク報酬を一回だけ受け取れる', () async {
    for (var i = 0; i < 8; i++) {
      await storage.incrementBattleCount();
    }
    for (var i = 0; i < 5; i++) {
      await storage.incrementWinCount();
    }
    await storage.saveDefeatedEnemy('easy_01');
    await storage.saveDefeatedEnemy('normal_01');
    await storage.setBossBestTurns(18);

    final result = await service.claimAvailableRewards();
    final second = await service.claimAvailableRewards();

    expect(result, isNotNull);
    expect(result!.claimedCount, 1);
    expect(result.coinsAwarded, 300);
    expect(result.gemsAwarded, 10);
    expect(storage.getCoins(), 300);
    expect(storage.getPremiumGems(), 10);
    expect(storage.getClaimedRankRewards(), ['hunter']);
    expect(second, isNull);
  });

  test('イベント限定端末の所持数を重複なしでスコアに反映する', () async {
    final limited = GachaCharacter.fromDevice(eventLimitedDeviceCatalog.first);
    await storage.saveGachaCharacters([
      limited.toJsonString(),
      limited.awaken().toJsonString(),
      GachaCharacter.fromDevice(eventLimitedDeviceCatalog.last).toJsonString(),
    ]);

    final rank = service.loadRank();

    expect(rank.rosterCount, 3);
    expect(rank.limitedOwned, 2);
    expect(
      rank.score,
      3 * PlayerRankService.rosterScore +
          2 * PlayerRankService.limitedOwnedScore,
    );
  });

  test('最高ランクでは次ランクがnullになる', () async {
    for (var i = 0; i < 80; i++) {
      await storage.incrementBattleCount();
    }
    for (var i = 0; i < 60; i++) {
      await storage.incrementWinCount();
    }
    for (var i = 0; i < 16; i++) {
      await storage.saveDefeatedEnemy('enemy_$i');
    }
    await storage.saveGachaCharacters(
      List.generate(
        30,
        (index) => GachaCharacter.fromDevice(
          gachaDeviceCatalog[index % gachaDeviceCatalog.length],
        ).toJsonString(),
      ),
    );
    await storage.setBossBestTurns(12);

    final rank = service.loadRank();

    expect(rank.current.id, 'legend');
    expect(rank.next, isNull);
    expect(rank.progressToNext, 1);
  });
}
