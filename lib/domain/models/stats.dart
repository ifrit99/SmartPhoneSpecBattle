/// キャラクターのステータス
class Stats {
  final int hp;     // 現在HP
  final int maxHp;  // 最大HP
  final int atk;    // 攻撃力
  final int def;    // 防御力
  final int spd;    // 素早さ

  const Stats({
    this.hp = 100,
    this.maxHp = 100,
    this.atk = 10,
    this.def = 10,
    this.spd = 10,
  });

  /// HPを更新したコピーを返す
  Stats copyWithHp(int newHp) {
    return Stats(
      hp: newHp.clamp(0, maxHp),
      maxHp: maxHp,
      atk: atk,
      def: def,
      spd: spd,
    );
  }

  /// レベルに応じてステータスを上昇させる
  Stats levelUp(int level) {
    final multiplier = 1.0 + (level - 1) * 0.1;
    return Stats(
      hp: (maxHp * multiplier).round(),
      maxHp: (maxHp * multiplier).round(),
      atk: (atk * multiplier).round(),
      def: (def * multiplier).round(),
      spd: (spd * multiplier).round(),
    );
  }

  /// HP残量の割合（0.0〜1.0）
  double get hpPercentage => maxHp > 0 ? hp / maxHp : 0.0;

  /// 生存判定
  bool get isAlive => hp > 0;

  @override
  String toString() => 'Stats(HP:$hp/$maxHp ATK:$atk DEF:$def SPD:$spd)';
}
