import '../models/player_currency.dart';
import '../../data/local_storage_service.dart';
import '../services/enemy_generator.dart';
import 'serial_executor.dart';

/// ゲーム内通貨の管理サービス
class CurrencyService {
  final LocalStorageService _storage;
  final SerialExecutor _serial = SerialExecutor();

  CurrencyService(this._storage);

  /// 保存されている通貨情報を読み込む
  PlayerCurrency load() {
    return PlayerCurrency(
      coins: _storage.getCoins(),
      premiumGems: _storage.getPremiumGems(),
    );
  }

  /// 通貨情報を保存する。失敗時は呼び出し前の残高へ戻してから投げ直す。
  Future<void> save(PlayerCurrency currency) async {
    final snapshot = load();
    try {
      await _storage.saveCoins(currency.coins);
      await _storage.savePremiumGems(currency.premiumGems);
    } catch (_) {
      await _restoreSnapshot(snapshot);
      rethrow;
    }
  }

  /// saveCoins がキャッシュ更新後に失敗すると gems まで届かないため、独立に戻す。
  Future<void> _restoreSnapshot(PlayerCurrency snapshot) async {
    try {
      await _storage.saveCoins(snapshot.coins);
    } catch (_) {
      // キャッシュは setInt が先に更新するため、ここでの失敗は無視する。
    }
    try {
      await _storage.savePremiumGems(snapshot.premiumGems);
    } catch (_) {
      // 同上。coins 側の失敗で gems の書き戻しが飛ばないようにする。
    }
  }

  /// バトル勝利時のコイン報酬を計算する
  ///
  /// 基本報酬: 30 + level * 5
  /// 難易度ボーナス: easy=0, normal=10, hard=25, boss=50
  static int calcBattleCoins({
    required bool won,
    required int playerLevel,
    EnemyDifficulty difficulty = EnemyDifficulty.normal,
    double rewardMultiplier = 1.0,
  }) {
    if (!won) {
      // 敗北時は少量のコイン
      return 5 + playerLevel;
    }

    final base = 30 + playerLevel * 5;
    final difficultyBonus = switch (difficulty) {
      EnemyDifficulty.easy => 0,
      EnemyDifficulty.normal => 10,
      EnemyDifficulty.hard => 25,
      EnemyDifficulty.boss => 50,
    };
    return ((base + difficultyBonus) * rewardMultiplier).round();
  }

  /// コインを加算して保存する
  Future<PlayerCurrency> addCoins(int amount) {
    return _serial.run(() async {
      final current = load();
      final updated = current.addCoins(amount);
      await save(updated);
      return updated;
    });
  }

  /// コインを消費して保存する（不足時はnullを返す）
  Future<PlayerCurrency?> spendCoins(int amount) {
    return _serial.run(() async {
      final current = load();
      if (current.coins < amount) return null;
      final updated = current.spendCoins(amount);
      await save(updated);
      return updated;
    });
  }

  /// ジェムを消費して保存する（不足時はnullを返す）
  Future<PlayerCurrency?> spendGems(int amount) {
    return _serial.run(() async {
      final current = load();
      if (current.premiumGems < amount) return null;
      final updated = current.spendGems(amount);
      await save(updated);
      return updated;
    });
  }

  /// ジェムを加算して保存する
  Future<PlayerCurrency> addGems(int amount) {
    return _serial.run(() async {
      final current = load();
      final updated = current.addGems(amount);
      await save(updated);
      return updated;
    });
  }
}
