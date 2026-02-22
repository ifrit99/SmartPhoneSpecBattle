import '../models/player_currency.dart';
import '../../data/local_storage_service.dart';
import '../services/enemy_generator.dart';

/// ゲーム内通貨の管理サービス
class CurrencyService {
  final LocalStorageService _storage;

  CurrencyService(this._storage);

  /// 保存されている通貨情報を読み込む
  PlayerCurrency load() {
    return PlayerCurrency(
      coins: _storage.getCoins(),
      premiumGems: _storage.getPremiumGems(),
    );
  }

  /// 通貨情報を保存する
  Future<void> save(PlayerCurrency currency) async {
    await _storage.saveCoins(currency.coins);
    await _storage.savePremiumGems(currency.premiumGems);
  }

  /// バトル勝利時のコイン報酬を計算する
  ///
  /// 基本報酬: 30 + level * 5
  /// 難易度ボーナス: easy=0, normal=10, hard=25, boss=50
  static int calcBattleCoins({
    required bool won,
    required int playerLevel,
    EnemyDifficulty difficulty = EnemyDifficulty.normal,
  }) {
    if (!won) {
      // 敗北時は少量のコイン
      return 5 + playerLevel;
    }

    final base = 30 + playerLevel * 5;
    final difficultyBonus = switch (difficulty) {
      EnemyDifficulty.easy   => 0,
      EnemyDifficulty.normal => 10,
      EnemyDifficulty.hard   => 25,
      EnemyDifficulty.boss   => 50,
    };
    return base + difficultyBonus;
  }

  /// コインを加算して保存する
  Future<PlayerCurrency> addCoins(int amount) async {
    final current = load();
    final updated = current.addCoins(amount);
    await save(updated);
    return updated;
  }

  /// コインを消費して保存する（不足時はnullを返す）
  Future<PlayerCurrency?> spendCoins(int amount) async {
    final current = load();
    if (current.coins < amount) return null;
    final updated = current.spendCoins(amount);
    await save(updated);
    return updated;
  }
}
