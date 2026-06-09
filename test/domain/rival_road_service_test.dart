import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';
import 'package:spec_battle_game/domain/services/rival_road_service.dart';

void main() {
  late LocalStorageService storage;
  late CurrencyService currencyService;
  late RivalRoadService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    currencyService = CurrencyService(storage);
    service = RivalRoadService(storage, currencyService);
  });

  test('初期状態では最初のステージが次の目標になる', () {
    final road = service.loadRoad();

    expect(road.clearedStageCount, 0);
    expect(road.completed, isFalse);
    expect(road.nextStage, RivalRoadService.stages.first);
  });

  test('次ステージのCPU勝利で一度だけ進捗と報酬を付与する', () async {
    final stage = RivalRoadService.stages.first;

    final result = await service.recordBattle(
      won: true,
      isCpuBattle: true,
      enemyDeviceId: stage.enemyDeviceId,
      turnsPlayed: 11,
    );
    final duplicate = await service.recordBattle(
      won: true,
      isCpuBattle: true,
      enemyDeviceId: stage.enemyDeviceId,
      turnsPlayed: 15,
    );

    expect(result, isNotNull);
    expect(result!.clearedStageCount, 1);
    expect(result.stageCleared, isTrue);
    expect(result.bestTurnsUpdated, isTrue);
    expect(result.bestTurns, 11);
    expect(duplicate, isNull);
    expect(storage.getRivalRoadClearedStage(), 1);
    expect(storage.getRivalRoadBestTurnsForStage(stage.index), 11);
    expect(storage.getCoins(), stage.rewardCoins);
    expect(storage.getPremiumGems(), stage.rewardGems);
  });

  test('クリア済みステージの再戦で最短ターンだけ更新できる', () async {
    final stage = RivalRoadService.stages.first;
    await storage.setRivalRoadClearedStage(1);
    await storage.setRivalRoadBestTurnsForStage(stage.index, 12);

    final slower = await service.recordBattle(
      won: true,
      isCpuBattle: true,
      enemyDeviceId: stage.enemyDeviceId,
      turnsPlayed: 13,
    );
    final faster = await service.recordBattle(
      won: true,
      isCpuBattle: true,
      enemyDeviceId: stage.enemyDeviceId,
      turnsPlayed: 9,
    );

    expect(slower, isNull);
    expect(faster, isNotNull);
    expect(faster!.stageCleared, isFalse);
    expect(faster.bestTurnsUpdated, isTrue);
    expect(faster.previousBestTurns, 12);
    expect(faster.bestTurns, 9);
    expect(storage.getRivalRoadClearedStage(), 1);
    expect(storage.getRivalRoadBestTurnsForStage(stage.index), 9);
    expect(storage.getCoins(), 0);
    expect(storage.getPremiumGems(), 0);
  });

  test('敗北・フレンド戦・次ステージ以外では進まない', () async {
    final stage = RivalRoadService.stages.first;

    expect(
      await service.recordBattle(
        won: false,
        isCpuBattle: true,
        enemyDeviceId: stage.enemyDeviceId,
        turnsPlayed: 10,
      ),
      isNull,
    );
    expect(
      await service.recordBattle(
        won: true,
        isCpuBattle: false,
        enemyDeviceId: stage.enemyDeviceId,
        turnsPlayed: 10,
      ),
      isNull,
    );
    expect(
      await service.recordBattle(
        won: true,
        isCpuBattle: true,
        enemyDeviceId: RivalRoadService.stages[1].enemyDeviceId,
        turnsPlayed: 10,
      ),
      isNull,
    );
    expect(storage.getRivalRoadClearedStage(), 0);
  });

  test('全ステージクリア後はcompletedになる', () async {
    for (final stage in RivalRoadService.stages) {
      final result = await service.recordBattle(
        won: true,
        isCpuBattle: true,
        enemyDeviceId: stage.enemyDeviceId,
        turnsPlayed: stage.index + 8,
      );
      expect(result, isNotNull);
    }

    final road = service.loadRoad();

    expect(road.completed, isTrue);
    expect(road.nextStage, isNull);
    expect(road.progressRatio, 1.0);
    expect(road.bestTurnsByStage, hasLength(RivalRoadService.stages.length));
  });
}
