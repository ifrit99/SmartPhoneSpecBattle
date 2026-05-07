import '../../data/local_storage_service.dart';
import 'currency_service.dart';

class DailyMissionDefinition {
  final String id;
  final String title;
  final String description;
  final int target;
  final int coinsReward;
  final int gemsReward;
  final int Function(LocalStorageService storage) progress;

  const DailyMissionDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.progress,
    this.coinsReward = 0,
    this.gemsReward = 0,
  });
}

class DailyMissionSnapshot {
  final DailyMissionDefinition definition;
  final int progress;
  final bool claimed;

  const DailyMissionSnapshot({
    required this.definition,
    required this.progress,
    required this.claimed,
  });

  bool get completed => progress >= definition.target;
  bool get claimable => completed && !claimed;
  double get progressRatio =>
      definition.target <= 0 ? 1 : (progress / definition.target).clamp(0, 1);
}

class DailyMissionClaimResult {
  final int coinsAwarded;
  final int gemsAwarded;

  const DailyMissionClaimResult({
    required this.coinsAwarded,
    required this.gemsAwarded,
  });
}

class DailyMissionClaimAllResult {
  final int claimedCount;
  final int coinsAwarded;
  final int gemsAwarded;

  const DailyMissionClaimAllResult({
    required this.claimedCount,
    required this.coinsAwarded,
    required this.gemsAwarded,
  });
}

class DailyMissionService {
  final LocalStorageService _storage;
  final CurrencyService _currencyService;
  final DateTime Function() _now;

  DailyMissionService(
    this._storage,
    this._currencyService, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static final List<DailyMissionDefinition> definitions = [
    DailyMissionDefinition(
      id: 'battle_1',
      title: '今日の腕試し',
      description: 'バトルを1回プレイ',
      target: 1,
      coinsReward: 80,
      progress: (storage) => storage.getDailyMissionBattles(),
    ),
    DailyMissionDefinition(
      id: 'win_1',
      title: '勝利ボーナス',
      description: 'バトルで1回勝利',
      target: 1,
      gemsReward: 5,
      progress: (storage) => storage.getDailyMissionWins(),
    ),
    DailyMissionDefinition(
      id: 'gacha_1',
      title: '解析チェック',
      description: 'ガチャを1回実行',
      target: 1,
      coinsReward: 120,
      progress: (storage) => storage.getDailyMissionGachaPulls(),
    ),
  ];

  String get todayString => _formatDate(_now());

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool get _isToday => _storage.getDailyMissionDate() == todayString;

  List<DailyMissionSnapshot> loadMissions() {
    final claimedIds =
        _isToday ? _storage.getClaimedDailyMissions().toSet() : <String>{};
    return definitions.map((definition) {
      return DailyMissionSnapshot(
        definition: definition,
        progress: _isToday ? definition.progress(_storage) : 0,
        claimed: claimedIds.contains(definition.id),
      );
    }).toList();
  }

  int claimableCount() =>
      loadMissions().where((mission) => mission.claimable).length;

  Future<void> recordBattle({required bool won}) async {
    await _ensureToday();
    await _storage.setDailyMissionBattles(
      _storage.getDailyMissionBattles() + 1,
    );
    if (won) {
      await _storage.setDailyMissionWins(_storage.getDailyMissionWins() + 1);
    }
  }

  Future<void> recordGachaPulls(int count) async {
    if (count <= 0) return;
    await _ensureToday();
    await _storage.setDailyMissionGachaPulls(
      _storage.getDailyMissionGachaPulls() + count,
    );
  }

  Future<DailyMissionClaimResult?> claim(String id) async {
    await _ensureToday();

    DailyMissionSnapshot? snapshot;
    for (final mission in loadMissions()) {
      if (mission.definition.id == id) {
        snapshot = mission;
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

    final claimed = _storage.getClaimedDailyMissions().toSet()..add(id);
    await _storage.saveClaimedDailyMissions(claimed.toList());

    return DailyMissionClaimResult(
      coinsAwarded: definition.coinsReward,
      gemsAwarded: definition.gemsReward,
    );
  }

  Future<DailyMissionClaimAllResult?> claimAllAvailable() async {
    await _ensureToday();

    final claimable = loadMissions()
        .where((mission) => mission.claimable)
        .map((mission) => mission.definition)
        .toList();
    if (claimable.isEmpty) return null;

    final coins = claimable.fold<int>(
      0,
      (total, definition) => total + definition.coinsReward,
    );
    final gems = claimable.fold<int>(
      0,
      (total, definition) => total + definition.gemsReward,
    );

    if (coins > 0) {
      await _currencyService.addCoins(coins);
    }
    if (gems > 0) {
      await _currencyService.addGems(gems);
    }

    final claimed = _storage.getClaimedDailyMissions().toSet()
      ..addAll(claimable.map((definition) => definition.id));
    await _storage.saveClaimedDailyMissions(claimed.toList());

    return DailyMissionClaimAllResult(
      claimedCount: claimable.length,
      coinsAwarded: coins,
      gemsAwarded: gems,
    );
  }

  Future<void> _ensureToday() async {
    if (_isToday) return;
    await _storage.setDailyMissionDate(todayString);
    await _storage.setDailyMissionBattles(0);
    await _storage.setDailyMissionWins(0);
    await _storage.setDailyMissionGachaPulls(0);
    await _storage.saveClaimedDailyMissions(const []);
  }
}
