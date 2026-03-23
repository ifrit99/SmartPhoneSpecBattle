import '../../data/local_storage_service.dart';
import 'currency_service.dart';

/// デイリー報酬の種別
enum DailyRewardType { login, battle }

/// デイリー報酬の付与結果
class DailyRewardResult {
  final DailyRewardType type;
  final int gemsAwarded;

  const DailyRewardResult({required this.type, required this.gemsAwarded});
}

/// デイリーログイン報酬・1日1回バトル報酬を管理するサービス
class DailyRewardService {
  final LocalStorageService _storage;
  final CurrencyService _currencyService;

  /// ログイン報酬のジェム数
  static const int loginRewardGems = 10;

  /// 1日1回バトル報酬のジェム数
  static const int battleRewardGems = 15;

  DailyRewardService(this._storage, this._currencyService);

  /// 端末日付から今日の日付文字列を取得（yyyy-MM-dd）
  static String todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// ログイン報酬が受取可能か
  bool canClaimLoginReward() {
    final last = _storage.getLastLoginRewardDate();
    return last != todayString();
  }

  /// バトル報酬が受取可能か
  bool canClaimBattleReward() {
    final last = _storage.getLastBattleRewardDate();
    return last != todayString();
  }

  /// ログイン報酬を付与する（既に受取済みならnull）
  Future<DailyRewardResult?> claimLoginReward() async {
    if (!canClaimLoginReward()) return null;
    await _storage.setLastLoginRewardDate(todayString());
    await _currencyService.addGems(loginRewardGems);
    return const DailyRewardResult(
      type: DailyRewardType.login,
      gemsAwarded: loginRewardGems,
    );
  }

  /// バトル報酬を付与する（既に受取済みならnull）
  Future<DailyRewardResult?> claimBattleReward() async {
    if (!canClaimBattleReward()) return null;
    await _storage.setLastBattleRewardDate(todayString());
    await _currencyService.addGems(battleRewardGems);
    return const DailyRewardResult(
      type: DailyRewardType.battle,
      gemsAwarded: battleRewardGems,
    );
  }
}
