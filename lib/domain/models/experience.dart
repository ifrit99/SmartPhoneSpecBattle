/// 経験値とレベルの管理
class Experience {
  final int level;
  final int currentExp;
  final int expToNext;

  const Experience({
    this.level = 1,
    this.currentExp = 0,
    this.expToNext = 100,
  });

  /// 経験値を加算して新しいExperienceを返す
  Experience addExp(int amount) {
    int newExp = currentExp + amount;
    int newLevel = level;
    int nextRequired = expToNext;

    // レベルアップ判定をループで処理
    while (newExp >= nextRequired) {
      newExp -= nextRequired;
      newLevel++;
      nextRequired = _calcExpToNext(newLevel);
    }

    return Experience(
      level: newLevel,
      currentExp: newExp,
      expToNext: nextRequired,
    );
  }

  /// レベルに応じた次レベルまでの必要経験値
  static int _calcExpToNext(int level) {
    // レベルが上がるほど必要経験値が増加する
    return (100 * (1.0 + (level - 1) * 0.5)).round();
  }

  /// 経験値バーの進捗割合（0.0〜1.0）
  double get progressPercentage =>
      expToNext > 0 ? currentExp / expToNext : 0.0;

  /// バトル結果から獲得経験値を計算
  static int calcBattleExp({required bool won, int enemyLevel = 1}) {
    final base = won ? 50 : 20;
    return (base * (1.0 + (enemyLevel - 1) * 0.2)).round();
  }

  @override
  String toString() => 'Lv.$level ($currentExp/$expToNext)';
}
