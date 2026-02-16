import 'dart:math';
import '../enums/element_type.dart';
import 'stats.dart';
import 'skill.dart';
import 'experience.dart';
import 'status_effect.dart';
import '../enums/effect_type.dart'; // EffectTypeのためにインポート

/// デバイスのスペックから生成されるキャラクター
class Character {
  final String name;
  final ElementType element;
  final Stats baseStats;     // レベル1時点の基礎ステータス
  final Stats currentStats;  // 現在のステータス（レベル反映済み）
  final List<Skill> skills;
  final Experience experience;
  final int seed;             // スペック値から生成されたシード
  final List<StatusEffect> statusEffects; // バフ・デバフ
  final int batteryLevel;     // バッテリー残量 (SPD補正用)

  // ビジュアル用パーツインデックス
  final int headIndex;
  final int bodyIndex;
  final int armIndex;
  final int legIndex;
  final int colorPaletteIndex;

  const Character({
    required this.name,
    required this.element,
    required this.baseStats,
    required this.currentStats,
    required this.skills,
    this.experience = const Experience(),
    this.seed = 0,
    this.statusEffects = const [],
    this.batteryLevel = 100, // デフォルト100%
    this.headIndex = 0,
    this.bodyIndex = 0,
    this.armIndex = 0,
    this.legIndex = 0,
    this.colorPaletteIndex = 0,
  });

  int get level => experience.level;
  
  Character copyWith({
    String? name,
    ElementType? element,
    Stats? baseStats,
    Stats? currentStats,
    List<Skill>? skills,
    Experience? experience,
    int? seed,
    List<StatusEffect>? statusEffects,
    int? batteryLevel,
    int? headIndex,
    int? bodyIndex,
    int? armIndex,
    int? legIndex,
    int? colorPaletteIndex,
  }) {
    return Character(
      name: name ?? this.name,
      element: element ?? this.element,
      baseStats: baseStats ?? this.baseStats,
      currentStats: currentStats ?? this.currentStats,
      skills: skills ?? this.skills,
      experience: experience ?? this.experience,
      seed: seed ?? this.seed,
      statusEffects: statusEffects ?? this.statusEffects,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      headIndex: headIndex ?? this.headIndex,
      bodyIndex: bodyIndex ?? this.bodyIndex,
      armIndex: armIndex ?? this.armIndex,
      legIndex: legIndex ?? this.legIndex,
      colorPaletteIndex: colorPaletteIndex ?? this.colorPaletteIndex,
    );
  }

  /// バトル用のステータスを取得（レベル反映）
  Stats get battleStats => baseStats.levelUp(level);

  /// バフ・デバフ・バッテリー補正を適用した実効ステータス
  Stats get effectiveStats {
    double atkMul = 1.0;
    double defMul = 1.0;
    double spdMul = 1.0;

    // バッテリー補正 (50%を基準に ±10%)
    // 100% -> +10% (x1.1)
    // 50%  -> +0% (x1.0)
    // 0%   -> -10% (x0.9)
    spdMul += (batteryLevel - 50) * 0.002;

    for (final effect in statusEffects) {
      switch (effect.type) {
        case EffectType.attackUp:
          atkMul += effect.value / 100.0;
        case EffectType.attackDown:
          atkMul -= effect.value / 100.0;
        case EffectType.defenseUp:
          defMul += effect.value / 100.0;
        case EffectType.defenseDown:
          defMul -= effect.value / 100.0;
        case EffectType.speedUp:
          spdMul += effect.value / 100.0;
        case EffectType.speedDown:
          spdMul -= effect.value / 100.0;
        default:
          break;
      }
    }

    // 倍率は0.1を下限とする
    atkMul = max(0.1, atkMul);
    defMul = max(0.1, defMul);
    spdMul = max(0.1, spdMul);

    final stats = battleStats;
    // HPは現在の値を維持（最大HPは変わらない前提だが、最大HPバフがあるなら考慮が必要）
    // 今回はatk/def/spdのみ変更
    return Stats(
      hp: currentStats.hp,
      maxHp: currentStats.maxHp,
      atk: (stats.atk * atkMul).round(),
      def: (stats.def * defMul).round(),
      spd: (stats.spd * spdMul).round(),
    );
  }

  /// 経験値を加算した新しいキャラクターを返す
  Character gainExp(int amount) {
    final newExp = experience.addExp(amount);
    return Character(
      name: name,
      element: element,
      baseStats: baseStats,
      currentStats: baseStats.levelUp(newExp.level),
      skills: skills,
      experience: newExp,
      seed: seed,
      headIndex: headIndex,
      bodyIndex: bodyIndex,
      armIndex: armIndex,
      legIndex: legIndex,
      colorPaletteIndex: colorPaletteIndex,
      statusEffects: statusEffects,
      batteryLevel: batteryLevel,
    );
  }

  /// HPを更新したバトル中のキャラクターを返す
  Character withHp(int newHp) {
    return Character(
      name: name,
      element: element,
      baseStats: baseStats,
      currentStats: currentStats.copyWithHp(newHp),
      skills: skills,
      experience: experience,
      seed: seed,
      headIndex: headIndex,
      bodyIndex: bodyIndex,
      armIndex: armIndex,
      legIndex: legIndex,
      colorPaletteIndex: colorPaletteIndex,
      statusEffects: statusEffects,
      batteryLevel: batteryLevel,
    );
  }

  @override
  String toString() =>
      'Character($name Lv.$level ${elementName(element)} $currentStats)';
}
