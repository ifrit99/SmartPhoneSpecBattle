import '../../data/local_storage_service.dart';
import 'currency_service.dart';
import 'enemy_generator.dart';

class LimitedEventDefinition {
  final String id;
  final String title;
  final String description;
  final int targetWins;
  final int rewardCoins;
  final int rewardGems;
  final String rivalEnemyId;

  const LimitedEventDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.targetWins,
    required this.rewardCoins,
    required this.rewardGems,
    required this.rivalEnemyId,
  });

  EnemyDeviceSpec get rivalEnemy {
    final enemy = EnemyGenerator.findById(rivalEnemyId);
    if (enemy == null) {
      throw StateError('イベントライバルが見つかりません: $rivalEnemyId');
    }
    return enemy;
  }
}

class LimitedEventMilestoneDefinition {
  final String id;
  final String title;
  final int requiredWins;
  final int rewardCoins;
  final int rewardGems;

  const LimitedEventMilestoneDefinition({
    required this.id,
    required this.title,
    required this.requiredWins,
    this.rewardCoins = 0,
    this.rewardGems = 0,
  });
}

class LimitedEventMilestoneSnapshot {
  final LimitedEventMilestoneDefinition definition;
  final int wins;
  final bool claimed;

  const LimitedEventMilestoneSnapshot({
    required this.definition,
    required this.wins,
    required this.claimed,
  });

  bool get unlocked => wins >= definition.requiredWins;
  bool get claimable => unlocked && !claimed;
  double get progress =>
      (wins / definition.requiredWins).clamp(0.0, 1.0).toDouble();
}

class LimitedEventSnapshot {
  final LimitedEventDefinition definition;
  final String weekId;
  final int wins;
  final bool claimed;
  final int daysRemaining;
  final List<LimitedEventMilestoneSnapshot> milestones;

  const LimitedEventSnapshot({
    required this.definition,
    required this.weekId,
    required this.wins,
    required this.claimed,
    required this.daysRemaining,
    required this.milestones,
  });

  bool get completed => wins >= definition.targetWins;
  bool get claimable => completed && !claimed;
  int get claimableMilestoneCount =>
      milestones.where((milestone) => milestone.claimable).length;
  double get progress =>
      (wins / definition.targetWins).clamp(0.0, 1.0).toDouble();
}

class LimitedEventClaimResult {
  final int claimedCount;
  final int coinsAwarded;
  final int gemsAwarded;

  const LimitedEventClaimResult({
    this.claimedCount = 1,
    required this.coinsAwarded,
    required this.gemsAwarded,
  });
}

class LimitedEventService {
  static const List<LimitedEventMilestoneDefinition> milestones = [
    LimitedEventMilestoneDefinition(
      id: 'event_2_wins',
      title: 'ライバル接近',
      requiredWins: 2,
      rewardCoins: 200,
    ),
    LimitedEventMilestoneDefinition(
      id: 'event_4_wins',
      title: '限定解析準備',
      requiredWins: 4,
      rewardGems: 20,
    ),
  ];

  static const List<LimitedEventDefinition> eventRotation = [
    LimitedEventDefinition(
      id: 'overclock_cup',
      title: 'オーバークロック杯',
      description: 'CPU戦で勝利を重ねて、週替わりの特別報酬を狙うイベント',
      targetWins: 5,
      rewardCoins: 1000,
      rewardGems: 80,
      rivalEnemyId: 'hard_02',
    ),
    LimitedEventDefinition(
      id: 'benchmark_rush',
      title: 'ベンチマークラッシュ',
      description: '短期集中でバトルを走り、プレミアム解析用ジェムを回収',
      targetWins: 5,
      rewardCoins: 900,
      rewardGems: 90,
      rivalEnemyId: 'boss_03',
    ),
    LimitedEventDefinition(
      id: 'silicon_league',
      title: 'シリコンリーグ',
      description: '今週のCPU戦績を積み上げて、次の主力育成につなげる',
      targetWins: 5,
      rewardCoins: 1200,
      rewardGems: 70,
      rivalEnemyId: 'hard_04',
    ),
  ];

  final LocalStorageService _storage;
  final CurrencyService _currencyService;
  final DateTime Function() _now;

  LimitedEventService(
    this._storage,
    this._currencyService, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  String get currentWeekId {
    final today = _dateOnly(_now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return _formatDate(monday);
  }

  LimitedEventDefinition get currentDefinition {
    final monday = DateTime.parse(currentWeekId);
    final rotationIndex =
        monday.difference(DateTime(2026, 1, 5)).inDays.abs() ~/ 7;
    return eventRotation[rotationIndex % eventRotation.length];
  }

  LimitedEventSnapshot loadEvent() {
    final isCurrentWeek = _storage.getLimitedEventWeekId() == currentWeekId;
    final wins = isCurrentWeek ? _storage.getLimitedEventWins() : 0;
    final claimedMilestones = isCurrentWeek
        ? _storage.getClaimedLimitedEventMilestones().toSet()
        : <String>{};
    return LimitedEventSnapshot(
      definition: currentDefinition,
      weekId: currentWeekId,
      wins: wins,
      claimed: isCurrentWeek ? _storage.isLimitedEventClaimed() : false,
      daysRemaining: _daysRemainingInWeek(),
      milestones: milestones
          .map(
            (milestone) => LimitedEventMilestoneSnapshot(
              definition: milestone,
              wins: wins,
              claimed: claimedMilestones.contains(milestone.id),
            ),
          )
          .toList(),
    );
  }

  Future<void> recordBattle({
    required bool won,
    required bool isCpuBattle,
    String? enemyDeviceId,
  }) async {
    await _ensureCurrentWeek();
    if (!won || !isCpuBattle) return;

    final event = currentDefinition;
    final current = _storage.getLimitedEventWins();
    final progress = enemyDeviceId == event.rivalEnemyId ? 2 : 1;
    await _storage.setLimitedEventWins(
      (current + progress).clamp(0, event.targetWins).toInt(),
    );
  }

  Future<LimitedEventClaimResult?> claim() async {
    await _ensureCurrentWeek();
    final snapshot = loadEvent();
    if (!snapshot.claimable) return null;

    await _currencyService.addCoins(snapshot.definition.rewardCoins);
    await _currencyService.addGems(snapshot.definition.rewardGems);
    await _storage.setLimitedEventClaimed(true);

    return LimitedEventClaimResult(
      coinsAwarded: snapshot.definition.rewardCoins,
      gemsAwarded: snapshot.definition.rewardGems,
    );
  }

  Future<LimitedEventClaimResult?> claimAvailableMilestones() async {
    await _ensureCurrentWeek();
    final snapshot = loadEvent();
    final claimable = snapshot.milestones
        .where((milestone) => milestone.claimable)
        .map((milestone) => milestone.definition)
        .toList();
    if (claimable.isEmpty) return null;

    final coins = claimable.fold<int>(
      0,
      (total, milestone) => total + milestone.rewardCoins,
    );
    final gems = claimable.fold<int>(
      0,
      (total, milestone) => total + milestone.rewardGems,
    );

    if (coins > 0) await _currencyService.addCoins(coins);
    if (gems > 0) await _currencyService.addGems(gems);

    final claimed = _storage.getClaimedLimitedEventMilestones().toSet()
      ..addAll(claimable.map((milestone) => milestone.id));
    await _storage.saveClaimedLimitedEventMilestones(claimed.toList());

    return LimitedEventClaimResult(
      claimedCount: claimable.length,
      coinsAwarded: coins,
      gemsAwarded: gems,
    );
  }

  Future<void> _ensureCurrentWeek() async {
    if (_storage.getLimitedEventWeekId() == currentWeekId) return;
    await _storage.setLimitedEventWeekId(currentWeekId);
    await _storage.setLimitedEventWins(0);
    await _storage.setLimitedEventClaimed(false);
    await _storage.saveClaimedLimitedEventMilestones(const []);
  }

  int _daysRemainingInWeek() {
    final today = _dateOnly(_now());
    final nextMonday = today.add(Duration(days: 8 - today.weekday));
    return nextMonday.difference(today).inDays;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
