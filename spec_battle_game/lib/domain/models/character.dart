import '../enums/element_type.dart';
import 'stats.dart';
import 'skill.dart';
import 'experience.dart';

/// デバイスのスペックから生成されるキャラクター
class Character {
  final String name;
  final ElementType element;
  final Stats baseStats;     // レベル1時点の基礎ステータス
  final Stats currentStats;  // 現在のステータス（レベル反映済み）
  final List<Skill> skills;
  final Experience experience;
  final int seed;             // スペック値から生成されたシード

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
    this.headIndex = 0,
    this.bodyIndex = 0,
    this.armIndex = 0,
    this.legIndex = 0,
    this.colorPaletteIndex = 0,
  });

  int get level => experience.level;

  /// バトル用のステータスを取得（レベル反映）
  Stats get battleStats => baseStats.levelUp(level);

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
    );
  }

  @override
  String toString() =>
      'Character($name Lv.$level ${elementName(element)} $currentStats)';
}
