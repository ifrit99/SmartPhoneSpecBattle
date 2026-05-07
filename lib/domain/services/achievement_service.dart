import '../../data/local_storage_service.dart';
import 'currency_service.dart';

class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final int target;
  final int coinsReward;
  final int gemsReward;
  final int Function(LocalStorageService storage) progress;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.progress,
    this.coinsReward = 0,
    this.gemsReward = 0,
  });
}

class AchievementSnapshot {
  final AchievementDefinition definition;
  final int progress;
  final bool claimed;

  const AchievementSnapshot({
    required this.definition,
    required this.progress,
    required this.claimed,
  });

  bool get completed => progress >= definition.target;
  bool get claimable => completed && !claimed;
  double get progressRatio =>
      definition.target <= 0 ? 1 : (progress / definition.target).clamp(0, 1);
}

class AchievementClaimResult {
  final int coinsAwarded;
  final int gemsAwarded;

  const AchievementClaimResult({
    required this.coinsAwarded,
    required this.gemsAwarded,
  });
}

class AchievementService {
  final LocalStorageService _storage;
  final CurrencyService _currencyService;

  AchievementService(this._storage, this._currencyService);

  static final List<AchievementDefinition> definitions = [
    AchievementDefinition(
      id: 'first_battle',
      title: '初陣',
      description: 'CPU戦を1回プレイ',
      target: 1,
      coinsReward: 100,
      progress: (storage) => storage.getBattleCount(),
    ),
    AchievementDefinition(
      id: 'first_win',
      title: '初勝利',
      description: 'CPU戦で1回勝利',
      target: 1,
      gemsReward: 5,
      progress: (storage) => storage.getWinCount(),
    ),
    AchievementDefinition(
      id: 'battle_5',
      title: 'スペック検証班',
      description: 'CPU戦を5回プレイ',
      target: 5,
      coinsReward: 300,
      progress: (storage) => storage.getBattleCount(),
    ),
    AchievementDefinition(
      id: 'win_3',
      title: '連勝への足場',
      description: 'CPU戦で3回勝利',
      target: 3,
      gemsReward: 10,
      progress: (storage) => storage.getWinCount(),
    ),
    AchievementDefinition(
      id: 'collection_4',
      title: '端末ハンター',
      description: '敵端末を4種類発見',
      target: 4,
      gemsReward: 15,
      progress: (storage) => storage.getDefeatedEnemies().length,
    ),
    AchievementDefinition(
      id: 'roster_3',
      title: '編成の始まり',
      description: 'ガチャキャラを3体所持',
      target: 3,
      coinsReward: 300,
      progress: (storage) => storage.getGachaCharacters().length,
    ),
    AchievementDefinition(
      id: 'rival_road_1',
      title: 'ロード開通',
      description: 'ライバルロードを1ステージ突破',
      target: 1,
      coinsReward: 250,
      progress: (storage) => storage.getRivalRoadClearedStage(),
    ),
    AchievementDefinition(
      id: 'rival_road_clear',
      title: 'ライバル制覇',
      description: 'ライバルロードを全ステージ突破',
      target: 5,
      coinsReward: 900,
      gemsReward: 40,
      progress: (storage) => storage.getRivalRoadClearedStage(),
    ),
  ];

  List<AchievementSnapshot> loadAchievements() {
    final claimedIds = _storage.getClaimedAchievements().toSet();
    return definitions.map((definition) {
      return AchievementSnapshot(
        definition: definition,
        progress: definition.progress(_storage),
        claimed: claimedIds.contains(definition.id),
      );
    }).toList();
  }

  int claimableCount() =>
      loadAchievements().where((achievement) => achievement.claimable).length;

  Future<AchievementClaimResult?> claim(String id) async {
    AchievementSnapshot? snapshot;
    for (final achievement in loadAchievements()) {
      if (achievement.definition.id == id) {
        snapshot = achievement;
        break;
      }
    }
    if (snapshot == null || !snapshot.claimable) return null;

    final definition = snapshot.definition;
    if (definition.coinsReward > 0) {
      await _currencyService.addCoins(definition.coinsReward);
    }
    if (definition.gemsReward > 0) {
      await _currencyService.addGems(definition.gemsReward);
    }

    final claimed = _storage.getClaimedAchievements().toSet()..add(id);
    await _storage.saveClaimedAchievements(claimed.toList());

    return AchievementClaimResult(
      coinsAwarded: definition.coinsReward,
      gemsAwarded: definition.gemsReward,
    );
  }
}
