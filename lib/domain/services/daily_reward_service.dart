import '../../data/local_storage_service.dart';
import 'currency_service.dart';

/// デイリー報酬の種別
enum DailyRewardType { login, battle }

/// デイリー報酬の付与結果
class DailyRewardResult {
  final DailyRewardType type;
  final int gemsAwarded;
  final int baseGems;
  final int bonusGems;
  final int loginStreakDays;
  final int loginCycleDay;

  const DailyRewardResult({
    required this.type,
    required this.gemsAwarded,
    this.baseGems = 0,
    this.bonusGems = 0,
    this.loginStreakDays = 0,
    this.loginCycleDay = 0,
  });
}

/// デイリーログイン報酬・1日1回バトル報酬を管理するサービス
class DailyRewardService {
  final LocalStorageService _storage;
  final CurrencyService _currencyService;
  final DateTime Function() _now;

  /// ログイン報酬のジェム数
  static const int loginRewardGems = 10;

  /// 1日1回バトル報酬のジェム数
  static const int battleRewardGems = 15;

  /// 連続ログインの節目ボーナス。
  static const int streakDay3BonusGems = 10;
  static const int streakDay7BonusGems = 20;

  static const int streakCycleDays = 7;

  DailyRewardService(
    this._storage,
    this._currencyService, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// 端末日付から今日の日付文字列を取得（yyyy-MM-dd）
  static String todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _todayString() => _formatDate(_now());

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// ログイン報酬が受取可能か
  bool canClaimLoginReward() {
    final last = _storage.getLastLoginRewardDate();
    return last != _todayString();
  }

  /// バトル報酬が受取可能か
  bool canClaimBattleReward() {
    final last = _storage.getLastBattleRewardDate();
    return last != _todayString();
  }

  /// 現在の連続ログイン日数。
  int getLoginStreakDays() => _storage.getLoginStreakDays();

  /// 次回ログイン報酬で何日目として扱われるか。
  int previewNextLoginStreakDays() {
    if (!canClaimLoginReward()) return getLoginStreakDays();
    return _nextLoginStreakDays(_storage.getLastLoginRewardDate());
  }

  /// 7日サイクル上の表示日数。
  int loginCycleDay(int streakDays) {
    if (streakDays <= 0) return 0;
    return ((streakDays - 1) % streakCycleDays) + 1;
  }

  /// 指定日数のログイン報酬ボーナス。
  int loginStreakBonusFor(int streakDays) {
    final cycleDay = loginCycleDay(streakDays);
    return switch (cycleDay) {
      3 => streakDay3BonusGems,
      7 => streakDay7BonusGems,
      _ => 0,
    };
  }

  /// ログイン報酬を付与する（既に受取済みならnull）
  Future<DailyRewardResult?> claimLoginReward() async {
    if (!canClaimLoginReward()) return null;
    final streakDays = _nextLoginStreakDays(_storage.getLastLoginRewardDate());
    final bonusGems = loginStreakBonusFor(streakDays);
    final totalGems = loginRewardGems + bonusGems;

    await _storage.setLastLoginRewardDate(_todayString());
    await _storage.setLoginStreakDays(streakDays);
    await _currencyService.addGems(totalGems);

    return DailyRewardResult(
      type: DailyRewardType.login,
      gemsAwarded: totalGems,
      baseGems: loginRewardGems,
      bonusGems: bonusGems,
      loginStreakDays: streakDays,
      loginCycleDay: loginCycleDay(streakDays),
    );
  }

  /// バトル報酬を付与する（既に受取済みならnull）
  Future<DailyRewardResult?> claimBattleReward() async {
    if (!canClaimBattleReward()) return null;
    await _storage.setLastBattleRewardDate(_todayString());
    await _currencyService.addGems(battleRewardGems);
    return const DailyRewardResult(
      type: DailyRewardType.battle,
      gemsAwarded: battleRewardGems,
      baseGems: battleRewardGems,
    );
  }

  int _nextLoginStreakDays(String? lastClaimDate) {
    if (lastClaimDate == null) return 1;

    final today = DateTime(_now().year, _now().month, _now().day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (lastClaimDate == _formatDate(yesterday)) {
      return _storage.getLoginStreakDays() + 1;
    }
    return 1;
  }
}
