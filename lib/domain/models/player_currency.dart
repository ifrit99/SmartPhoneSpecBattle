/// プレイヤーの所持通貨
class PlayerCurrency {
  final int coins;
  final int premiumGems;

  /// 単発ガチャのコイン消費
  static const int singlePullCost = 100;

  /// 10連ガチャのコイン消費（10%割引）
  static const int tenPullCost = 900;

  /// プレミアム解析ガチャのジェム消費（SR以上確定）
  static const int premiumPullCost = 20;

  /// 期間限定イベント解析ガチャのジェム消費（SR以上・限定SSRあり）
  static const int eventLimitedPullCost = 30;

  const PlayerCurrency({
    this.coins = 0,
    this.premiumGems = 0,
  });

  /// コインが足りるか判定
  bool canAffordSingle() => coins >= singlePullCost;
  bool canAffordTenPull() => coins >= tenPullCost;
  bool canAffordPremiumPull() => premiumGems >= premiumPullCost;
  bool canAffordEventLimitedPull() => premiumGems >= eventLimitedPullCost;

  /// コインを消費した新しいインスタンスを返す
  PlayerCurrency spendCoins(int amount) {
    if (coins < amount) {
      throw StateError('コインが不足しています（所持: $coins, 必要: $amount）');
    }
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

  /// プレミアムジェムを消費した新しいインスタンスを返す
  PlayerCurrency spendGems(int amount) {
    if (premiumGems < amount) {
      throw StateError('ジェムが不足しています（所持: $premiumGems, 必要: $amount）');
    }
    return PlayerCurrency(
      coins: coins,
      premiumGems: premiumGems - amount,
    );
  }

  @override
  String toString() => 'PlayerCurrency(coins: $coins, gems: $premiumGems)';
}
