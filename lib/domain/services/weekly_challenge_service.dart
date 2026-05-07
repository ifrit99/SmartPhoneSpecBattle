import '../../data/local_storage_service.dart';
import 'currency_service.dart';
import 'enemy_generator.dart';

class WeeklyChallengeSnapshot {
  final String weekId;
  final int wins;
  final int targetWins;
  final bool claimed;

  const WeeklyChallengeSnapshot({
    required this.weekId,
    required this.wins,
    required this.targetWins,
    required this.claimed,
  });

  bool get completed => wins >= targetWins;
  bool get claimable => completed && !claimed;
  double get progress => (wins / targetWins).clamp(0.0, 1.0);
}

class WeeklyChallengeClaimResult {
  final int coinsAwarded;
  final int gemsAwarded;

  const WeeklyChallengeClaimResult({
    required this.coinsAwarded,
    required this.gemsAwarded,
  });
}

class WeeklyChallengeService {
  static const int targetHighDifficultyWins = 3;
  static const int rewardCoins = 600;
  static const int rewardGems = 50;

  final LocalStorageService _storage;
  final CurrencyService _currencyService;
  final DateTime Function() _now;

  WeeklyChallengeService(
    this._storage,
    this._currencyService, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  String get currentWeekId {
    final today = _dateOnly(_now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return _formatDate(monday);
  }

  WeeklyChallengeSnapshot loadChallenge() {
    final isCurrentWeek = _storage.getWeeklyChallengeWeekId() == currentWeekId;
    return WeeklyChallengeSnapshot(
      weekId: currentWeekId,
      wins: isCurrentWeek ? _storage.getWeeklyChallengeHighDifficultyWins() : 0,
      targetWins: targetHighDifficultyWins,
      claimed: isCurrentWeek ? _storage.isWeeklyChallengeClaimed() : false,
    );
  }

  Future<void> recordBattle({
    required bool won,
    required bool isCpuBattle,
    required EnemyDifficulty difficulty,
  }) async {
    await _ensureCurrentWeek();
    if (!won || !isCpuBattle || !_isHighDifficulty(difficulty)) return;

    final current = _storage.getWeeklyChallengeHighDifficultyWins();
    await _storage.setWeeklyChallengeHighDifficultyWins(
      (current + 1).clamp(0, targetHighDifficultyWins).toInt(),
    );
  }

  Future<WeeklyChallengeClaimResult?> claim() async {
    await _ensureCurrentWeek();
    final snapshot = loadChallenge();
    if (!snapshot.claimable) return null;

    await _currencyService.addCoins(rewardCoins);
    await _currencyService.addGems(rewardGems);
    await _storage.setWeeklyChallengeClaimed(true);

    return const WeeklyChallengeClaimResult(
      coinsAwarded: rewardCoins,
      gemsAwarded: rewardGems,
    );
  }

  bool _isHighDifficulty(EnemyDifficulty difficulty) {
    return difficulty == EnemyDifficulty.hard ||
        difficulty == EnemyDifficulty.boss;
  }

  Future<void> _ensureCurrentWeek() async {
    if (_storage.getWeeklyChallengeWeekId() == currentWeekId) return;
    await _storage.setWeeklyChallengeWeekId(currentWeekId);
    await _storage.setWeeklyChallengeHighDifficultyWins(0);
    await _storage.setWeeklyChallengeClaimed(false);
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
