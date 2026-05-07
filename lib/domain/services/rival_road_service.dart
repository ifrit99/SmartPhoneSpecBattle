import '../../data/local_storage_service.dart';
import 'currency_service.dart';
import 'enemy_generator.dart';

class RivalRoadStageDefinition {
  final int index;
  final String title;
  final String enemyDeviceId;
  final int rewardCoins;
  final int rewardGems;

  const RivalRoadStageDefinition({
    required this.index,
    required this.title,
    required this.enemyDeviceId,
    required this.rewardCoins,
    required this.rewardGems,
  });

  EnemyDeviceSpec get enemyDevice {
    final device = EnemyGenerator.findById(enemyDeviceId);
    if (device == null) {
      throw StateError('Rival Road enemy not found: $enemyDeviceId');
    }
    return device;
  }
}

class RivalRoadSnapshot {
  final int clearedStageCount;
  final List<RivalRoadStageDefinition> stages;
  final Map<int, int> bestTurnsByStage;

  const RivalRoadSnapshot({
    required this.clearedStageCount,
    required this.stages,
    required this.bestTurnsByStage,
  });

  int get totalStageCount => stages.length;
  bool get completed => clearedStageCount >= stages.length;
  double get progressRatio =>
      stages.isEmpty ? 1 : (clearedStageCount / stages.length).clamp(0, 1);

  RivalRoadStageDefinition? get nextStage {
    if (completed) return null;
    return stages[clearedStageCount];
  }

  int? bestTurnsFor(RivalRoadStageDefinition stage) =>
      bestTurnsByStage[stage.index];
}

class RivalRoadClearResult {
  final RivalRoadStageDefinition stage;
  final int clearedStageCount;
  final bool completed;
  final bool stageCleared;
  final int? previousBestTurns;
  final int? bestTurns;

  const RivalRoadClearResult({
    required this.stage,
    required this.clearedStageCount,
    required this.completed,
    required this.stageCleared,
    required this.previousBestTurns,
    required this.bestTurns,
  });

  bool get bestTurnsUpdated =>
      bestTurns != null &&
      (previousBestTurns == null || bestTurns! < previousBestTurns!);
}

class RivalRoadService {
  static const List<RivalRoadStageDefinition> stages = [
    RivalRoadStageDefinition(
      index: 1,
      title: 'Entry Gate',
      enemyDeviceId: 'easy_03',
      rewardCoins: 160,
      rewardGems: 5,
    ),
    RivalRoadStageDefinition(
      index: 2,
      title: 'Midrange Wall',
      enemyDeviceId: 'normal_02',
      rewardCoins: 240,
      rewardGems: 8,
    ),
    RivalRoadStageDefinition(
      index: 3,
      title: 'Pro Trial',
      enemyDeviceId: 'hard_01',
      rewardCoins: 360,
      rewardGems: 12,
    ),
    RivalRoadStageDefinition(
      index: 4,
      title: 'Ultra Check',
      enemyDeviceId: 'hard_04',
      rewardCoins: 480,
      rewardGems: 16,
    ),
    RivalRoadStageDefinition(
      index: 5,
      title: 'Flagship Crown',
      enemyDeviceId: 'boss_04',
      rewardCoins: 800,
      rewardGems: 30,
    ),
  ];

  final LocalStorageService _storage;
  final CurrencyService _currencyService;

  RivalRoadService(this._storage, this._currencyService);

  RivalRoadSnapshot loadRoad() {
    final cleared =
        _storage.getRivalRoadClearedStage().clamp(0, stages.length).toInt();
    return RivalRoadSnapshot(
      clearedStageCount: cleared,
      stages: stages,
      bestTurnsByStage: _storage.getRivalRoadBestTurns(),
    );
  }

  Future<RivalRoadClearResult?> recordBattle({
    required bool won,
    required bool isCpuBattle,
    required String? enemyDeviceId,
    required int turnsPlayed,
  }) async {
    if (!won || !isCpuBattle || enemyDeviceId == null) return null;

    final road = loadRoad();
    final stage = _stageByEnemyDeviceId(enemyDeviceId);
    if (stage == null) return null;
    if (stage.index > road.clearedStageCount + 1) return null;

    final previousBestTurns = _storage.getRivalRoadBestTurnsForStage(
      stage.index,
    );
    int? bestTurns;
    if (turnsPlayed > 0 &&
        (previousBestTurns == null || turnsPlayed < previousBestTurns)) {
      bestTurns = turnsPlayed;
      await _storage.setRivalRoadBestTurnsForStage(stage.index, turnsPlayed);
    }

    final nextStage = road.nextStage;
    final stageCleared =
        nextStage != null && nextStage.enemyDeviceId == enemyDeviceId;
    if (!stageCleared && bestTurns == null) return null;

    final nextCleared =
        stageCleared ? road.clearedStageCount + 1 : road.clearedStageCount;
    if (stageCleared) {
      await _storage.setRivalRoadClearedStage(nextCleared);
      await _currencyService.addCoins(stage.rewardCoins);
      if (stage.rewardGems > 0) {
        await _currencyService.addGems(stage.rewardGems);
      }
    }

    return RivalRoadClearResult(
      stage: stage,
      clearedStageCount: nextCleared,
      completed: nextCleared >= stages.length,
      stageCleared: stageCleared,
      previousBestTurns: previousBestTurns,
      bestTurns: bestTurns,
    );
  }

  RivalRoadStageDefinition? _stageByEnemyDeviceId(String enemyDeviceId) {
    for (final stage in stages) {
      if (stage.enemyDeviceId == enemyDeviceId) return stage;
    }
    return null;
  }
}
