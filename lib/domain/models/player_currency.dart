/// プレイヤーの所持通貨
class PlayerCurrency {
  final int coins;
  final int premiumGems;

  /// 単発ガチャのコイン消費
  static const int singlePullCost = 100;

  /// 10連ガチャのコイン消費（10%割引）
  static const int tenPullCost = 900;

  const PlayerCurrency({
    this.coins = 0,
    this.premiumGems = 0,
  });

  /// コインが足りるか判定
  bool canAffordSingle() => coins >= singlePullCost;
  bool canAffordTenPull() => coins >= tenPullCost;

  /// コインを消費した新しいインスタンスを返す
  PlayerCurrency spendCoins(int amount) {
    assert(coins >= amount, 'コインが不足しています');
    return PlayerCurrency(
      coins: coins - amount,
      premiumGems: premiumGems,
    );
  }

  /// コインを加算した新しいインスタンスを返す
  PlayerCurrency addCoins(int amount) {
    return PlayerCurrency(
      coins: coins + amount,
      premiumGems: premiumGems,
    );
  }

  /// プレミアムジェムを加算
  PlayerCurrency addGems(int amount) {
    return PlayerCurrency(
      coins: coins,
      premiumGems: premiumGems + amount,
    );
  }

  @override
  String toString() => 'PlayerCurrency(coins: $coins, gems: $premiumGems)';
}
