import '../../data/local_storage_service.dart';
import 'currency_service.dart';
import 'serial_executor.dart';

class BossBountyResult {
  final int coinsAwarded;
  final int gemsAwarded;

  const BossBountyResult({
    required this.coinsAwarded,
    required this.gemsAwarded,
  });
}

class BossBountyService {
  static const int dailyBossCoins = 300;
  static const int dailyBossGems = 30;

  final LocalStorageService _storage;
  final CurrencyService _currencyService;
  final DateTime Function() _now;
  final SerialExecutor _serial = SerialExecutor();

  BossBountyService(
    this._storage,
    this._currencyService, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  String get todayString => _formatDate(_now());

  bool get canReceiveToday => _storage.getLastBossBountyDate() != todayString;

  Future<BossBountyResult?> claimForBossWin() {
    return _serial.run(() async {
      if (!canReceiveToday) return null;

      await _storage.setLastBossBountyDate(todayString);
      await _currencyService.addCoins(dailyBossCoins);
      await _currencyService.addGems(dailyBossGems);

      return const BossBountyResult(
        coinsAwarded: dailyBossCoins,
        gemsAwarded: dailyBossGems,
      );
    });
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
