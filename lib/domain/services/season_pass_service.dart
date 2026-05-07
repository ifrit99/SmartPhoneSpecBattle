import '../../data/local_storage_service.dart';
import 'currency_service.dart';
import 'enemy_generator.dart';

class SeasonPassRewardDefinition {
  final String id;
  final String title;
  final int requiredXp;
  final int coinsReward;
  final int gemsReward;

  const SeasonPassRewardDefinition({
    required this.id,
    required this.title,
    required this.requiredXp,
    this.coinsReward = 0,
    this.gemsReward = 0,
  });
}

class SeasonPassRewardSnapshot {
  final SeasonPassRewardDefinition definition;
  final int currentXp;
  final bool claimed;

  const SeasonPassRewardSnapshot({
    required this.definition,
    required this.currentXp,
    required this.claimed,
  });

  bool get unlocked => currentXp >= definition.requiredXp;
  bool get claimable => unlocked && !claimed;
  double get progress => (currentXp / definition.requiredXp).clamp(0.0, 1.0);
}

class SeasonPassSnapshot {
  final String seasonId;
  final int xp;
  final int daysRemaining;
  final List<SeasonPassRewardSnapshot> rewards;

  const SeasonPassSnapshot({
    required this.seasonId,
    required this.xp,
    required this.daysRemaining,
    required this.rewards,
  });

  int get claimedCount => rewards.where((reward) => reward.claimed).length;
  int get claimableCount => rewards.where((reward) => reward.claimable).length;
  SeasonPassRewardSnapshot? get nextReward {
    for (final reward in rewards) {
      if (!reward.claimed) return reward;
    }
    return null;
  }

  bool get completed => rewards.every((reward) => reward.claimed);
}

class SeasonPassClaimResult {
  final int claimedCount;
  final int coinsAwarded;
  final int gemsAwarded;

  const SeasonPassClaimResult({
    required this.claimedCount,
    required this.coinsAwarded,
    required this.gemsAwarded,
  });
}

class SeasonPassService {
  static const int baseBattleXp = 35;
  static const int winBonusXp = 25;
  static const int cpuBattleBonusXp = 10;
  static const int highDifficultyBonusXp = 30;

  static const List<SeasonPassRewardDefinition> rewards = [
    SeasonPassRewardDefinition(
      id: 'season_100',
      title: 'スターター補給',
      requiredXp: 100,
      coinsReward: 200,
    ),
    SeasonPassRewardDefinition(
      id: 'season_250',
      title: 'プレミアム解析券',
      requiredXp: 250,
      gemsReward: 25,
    ),
    SeasonPassRewardDefinition(
      id: 'season_450',
      title: '強化資金',
      requiredXp: 450,
      coinsReward: 500,
    ),
    SeasonPassRewardDefinition(
      id: 'season_700',
      title: '限定補給',
      requiredXp: 700,
      coinsReward: 700,
      gemsReward: 40,
    ),
    SeasonPassRewardDefinition(
      id: 'season_1000',
      title: 'シーズン完走報酬',
      requiredXp: 1000,
      coinsReward: 1200,
      gemsReward: 80,
    ),
  ];

  final LocalStorageService _storage;
  final CurrencyService _currencyService;
  final DateTime Function() _now;

  SeasonPassService(
    this._storage,
    this._currencyService, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  String get currentSeasonId {
    final date = _now();
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  int get daysRemaining {
    final today = _dateOnly(_now());
    final nextMonth = DateTime(today.year, today.month + 1, 1);
    return nextMonth.difference(today).inDays.clamp(1, 31);
  }

  SeasonPassSnapshot loadPass() {
    final isCurrentSeason = _storage.getSeasonPassId() == currentSeasonId;
    final xp = isCurrentSeason ? _storage.getSeasonPassXp() : 0;
    final claimed = isCurrentSeason
        ? _storage.getClaimedSeasonPassRewards().toSet()
        : <String>{};

    return SeasonPassSnapshot(
      seasonId: currentSeasonId,
      xp: xp,
      daysRemaining: daysRemaining,
      rewards: rewards
          .map(
            (reward) => SeasonPassRewardSnapshot(
              definition: reward,
              currentXp: xp,
              claimed: claimed.contains(reward.id),
            ),
          )
          .toList(),
    );
  }

  Future<int> recordBattle({
    required bool won,
    required bool isCpuBattle,
    required EnemyDifficulty difficulty,
  }) async {
    await _ensureCurrentSeason();

    final earned = baseBattleXp +
        (won ? winBonusXp : 0) +
        (isCpuBattle ? cpuBattleBonusXp : 0) +
        (_isHighDifficulty(difficulty) && won ? highDifficultyBonusXp : 0);
    await _storage.setSeasonPassXp(_storage.getSeasonPassXp() + earned);
    return earned;
  }

  Future<SeasonPassClaimResult?> claimAllAvailable() async {
    await _ensureCurrentSeason();
    final snapshot = loadPass();
    final claimable = snapshot.rewards
        .where((reward) => reward.claimable)
        .map((reward) => reward.definition)
        .toList();
    if (claimable.isEmpty) return null;

    final coins = claimable.fold<int>(
      0,
      (total, reward) => total + reward.coinsReward,
    );
    final gems = claimable.fold<int>(
      0,
      (total, reward) => total + reward.gemsReward,
    );

    if (coins > 0) await _currencyService.addCoins(coins);
    if (gems > 0) await _currencyService.addGems(gems);

    final claimed = _storage.getClaimedSeasonPassRewards().toSet()
      ..addAll(claimable.map((reward) => reward.id));
    await _storage.saveClaimedSeasonPassRewards(claimed.toList());

    return SeasonPassClaimResult(
      claimedCount: claimable.length,
      coinsAwarded: coins,
      gemsAwarded: gems,
    );
  }

  Future<void> _ensureCurrentSeason() async {
    if (_storage.getSeasonPassId() == currentSeasonId) return;
    await _storage.setSeasonPassId(currentSeasonId);
    await _storage.setSeasonPassXp(0);
    await _storage.saveClaimedSeasonPassRewards(const []);
  }

  bool _isHighDifficulty(EnemyDifficulty difficulty) =>
      difficulty == EnemyDifficulty.hard || difficulty == EnemyDifficulty.boss;

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
