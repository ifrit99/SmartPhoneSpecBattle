/// バトル中の行動を集計した統計値。
///
/// 勝因・敗因分析（BattleInsightService）の材料として、
/// BattleEngine がダメージ計算と同時に収集する。
/// 属性・戦術の寄与は「倍率なしで計算した場合との差分」で算出するため、
/// 「属性有利で +120 ダメージ」のような定量表示に使える。
class BattleStatistics {
  /// プレイヤーが与えた総ダメージ
  final int playerDamageDealt;

  /// プレイヤーが受けた総ダメージ（毒などの継続ダメージは含まない）
  final int enemyDamageDealt;

  /// プレイヤーのクリティカル発生回数
  final int playerCriticalHits;

  /// プレイヤーのスキル使用回数
  final int playerSkillCount;

  /// プレイヤーがスキルで与えたダメージ
  final int playerSkillDamage;

  /// プレイヤーの総回復量（防御・回復スキル・ドレイン・リジェネ含む）
  final int playerHealing;

  /// 属性有利で上乗せできた与ダメージ（等倍計算との差分）
  final int elementBonusDamage;

  /// 属性不利で目減りした与ダメージ（等倍計算との差分）
  final int elementPenaltyDamage;

  /// 相手の属性有利によって増えた被ダメージ（等倍計算との差分）
  final int enemyElementBonusDamage;

  /// 戦術倍率による与ダメージ差分（負の値は減少を意味する）
  final int tacticBonusDamage;

  /// 戦術倍率による被ダメージ軽減量（負の値は増加を意味する）
  final int tacticGuardedDamage;

  /// 支援コマンド由来の回復量（防御支援のリジェネ）
  final int supportHealing;

  const BattleStatistics({
    this.playerDamageDealt = 0,
    this.enemyDamageDealt = 0,
    this.playerCriticalHits = 0,
    this.playerSkillCount = 0,
    this.playerSkillDamage = 0,
    this.playerHealing = 0,
    this.elementBonusDamage = 0,
    this.elementPenaltyDamage = 0,
    this.enemyElementBonusDamage = 0,
    this.tacticBonusDamage = 0,
    this.tacticGuardedDamage = 0,
    this.supportHealing = 0,
  });
}
