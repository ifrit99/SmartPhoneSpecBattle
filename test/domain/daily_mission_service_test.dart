import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';
import 'package:spec_battle_game/domain/services/daily_mission_service.dart';

void main() {
  late LocalStorageService storage;
  late CurrencyService currencyService;
  late DailyMissionService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    currencyService = CurrencyService(storage);
    service = DailyMissionService(
      storage,
      currencyService,
      now: () => DateTime(2026, 5, 5),
    );
  });

  DailyMissionSnapshot findMission(String id) {
    return service.loadMissions().singleWhere(
          (mission) => mission.definition.id == id,
        );
  }

  test('初期状態では全ミッションが未達成', () {
    final missions = service.loadMissions();

    expect(missions.length, 3);
    expect(missions.every((mission) => mission.progress == 0), isTrue);
    expect(missions.every((mission) => !mission.claimable), isTrue);
    expect(service.claimableCount(), 0);
  });

  test('敗北バトルはバトル回数だけを達成にする', () async {
    await service.recordBattle(won: false);

    expect(findMission('battle_1').claimable, isTrue);
    expect(findMission('win_1').claimable, isFalse);
    expect(storage.getDailyMissionBattles(), 1);
    expect(storage.getDailyMissionWins(), 0);
  });

  test('勝利バトルはバトル回数と勝利を達成にする', () async {
    await service.recordBattle(won: true);

    expect(findMission('battle_1').claimable, isTrue);
    expect(findMission('win_1').claimable, isTrue);
    expect(service.claimableCount(), 2);
  });

  test('ガチャ回数を記録するとガチャミッションが達成になる', () async {
    await service.recordGachaPulls(10);

    expect(findMission('gacha_1').claimable, isTrue);
    expect(storage.getDailyMissionGachaPulls(), 10);
  });

  test('達成済みミッションを受け取ると報酬と受取済み状態を保存する', () async {
    await service.recordBattle(won: false);

    final result = await service.claim('battle_1');
    final secondClaim = await service.claim('battle_1');

    expect(result, isNotNull);
    expect(result!.coinsAwarded, 80);
    expect(result.gemsAwarded, 0);
    expect(storage.getCoins(), 80);
    expect(storage.getClaimedDailyMissions(), ['battle_1']);
    expect(findMission('battle_1').claimed, isTrue);
    expect(secondClaim, isNull);
  });

  test('未達成ミッションは受け取れない', () async {
    final result = await service.claim('win_1');

    expect(result, isNull);
    expect(storage.getPremiumGems(), 0);
  });

  test('受け取り可能なミッションを一括受取できる', () async {
    await service.recordBattle(won: true);
    await service.recordGachaPulls(1);

    final result = await service.claimAllAvailable();
    final secondClaim = await service.claimAllAvailable();

    expect(result, isNotNull);
    expect(result!.claimedCount, 3);
    expect(result.coinsAwarded, 200);
    expect(result.gemsAwarded, 5);
    expect(storage.getCoins(), 200);
    expect(storage.getPremiumGems(), 5);
    expect(
      storage.getClaimedDailyMissions(),
      containsAll(['battle_1', 'win_1', 'gacha_1']),
    );
    expect(service.claimableCount(), 0);
    expect(secondClaim, isNull);
  });

  test('一括受取は未達成ミッションを受け取らない', () async {
    await service.recordBattle(won: false);

    final result = await service.claimAllAvailable();

    expect(result, isNotNull);
    expect(result!.claimedCount, 1);
    expect(result.coinsAwarded, 80);
    expect(result.gemsAwarded, 0);
    expect(storage.getClaimedDailyMissions(), ['battle_1']);
    expect(findMission('win_1').claimed, isFalse);
  });

  test('日付が変わると進捗と受取済み状態をリセットしてから記録する', () async {
    await storage.setDailyMissionDate('2026-05-04');
    await storage.setDailyMissionBattles(3);
    await storage.setDailyMissionWins(2);
    await storage.setDailyMissionGachaPulls(5);
    await storage.saveClaimedDailyMissions(['battle_1', 'win_1']);

    await service.recordBattle(won: false);

    expect(storage.getDailyMissionDate(), '2026-05-05');
    expect(storage.getDailyMissionBattles(), 1);
    expect(storage.getDailyMissionWins(), 0);
    expect(storage.getDailyMissionGachaPulls(), 0);
    expect(storage.getClaimedDailyMissions(), isEmpty);
    expect(findMission('battle_1').claimable, isTrue);
    expect(findMission('win_1').claimable, isFalse);
  });
}
