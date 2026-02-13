import '../enums/element_type.dart';

/// スキルの種類
enum SkillCategory {
  attack,   // 攻撃スキル
  defense,  // 防御スキル
  special,  // 特殊スキル
}

/// バトルで使用するスキル
class Skill {
  final String name;
  final String description;
  final ElementType element;
  final SkillCategory category;
  final double multiplier;  // ダメージ/効果の倍率
  final int cooldown;       // クールダウンターン数

  const Skill({
    this.name,
    this.description,
    this.element,
    this.category,
    this.multiplier = 1.0,
    this.cooldown = 0,
  });

  @override
  String toString() => '$name ($category)';
}

/// 属性別のデフォルトスキル定義
List<Skill> getSkillsForElement(ElementType element) {
  switch (element) {
    case ElementType.fire:
      return [
        Skill(
          name: 'ファイアボール',
          description: '炎の球を投げつける',
          element: ElementType.fire,
          category: SkillCategory.attack,
          multiplier: 1.8,
          cooldown: 2,
        ),
        Skill(
          name: '灼熱の壁',
          description: '炎の壁で身を守る',
          element: ElementType.fire,
          category: SkillCategory.defense,
          multiplier: 1.5,
          cooldown: 3,
        ),
      ];
    case ElementType.water:
      return [
        Skill(
          name: 'ウォータースラッシュ',
          description: '水の刃で斬りつける',
          element: ElementType.water,
          category: SkillCategory.attack,
          multiplier: 1.7,
          cooldown: 2,
        ),
        Skill(
          name: 'ヒーリングウェーブ',
          description: '水の力でHPを回復',
          element: ElementType.water,
          category: SkillCategory.special,
          multiplier: 0.3, // maxHPの30%回復
          cooldown: 4,
        ),
      ];
    case ElementType.earth:
      return [
        Skill(
          name: 'ロックスマッシュ',
          description: '巨大な岩を叩きつける',
          element: ElementType.earth,
          category: SkillCategory.attack,
          multiplier: 2.0,
          cooldown: 3,
        ),
        Skill(
          name: 'ストーンアーマー',
          description: '岩の鎧で防御力UP',
          element: ElementType.earth,
          category: SkillCategory.defense,
          multiplier: 2.0,
          cooldown: 3,
        ),
      ];
    case ElementType.wind:
      return [
        Skill(
          name: 'エアカッター',
          description: '鋭い風で切り裂く',
          element: ElementType.wind,
          category: SkillCategory.attack,
          multiplier: 1.5,
          cooldown: 1,
        ),
        Skill(
          name: 'スピードブースト',
          description: '風の力で素早さUP',
          element: ElementType.wind,
          category: SkillCategory.special,
          multiplier: 1.5,
          cooldown: 3,
        ),
      ];
    case ElementType.light:
      return [
        Skill(
          name: 'ホーリーレイ',
          description: '聖なる光で攻撃',
          element: ElementType.light,
          category: SkillCategory.attack,
          multiplier: 1.9,
          cooldown: 2,
        ),
        Skill(
          name: 'バリア',
          description: '光の盾でダメージ軽減',
          element: ElementType.light,
          category: SkillCategory.defense,
          multiplier: 1.8,
          cooldown: 3,
        ),
      ];
    case ElementType.dark:
      return [
        Skill(
          name: 'シャドウストライク',
          description: '闇の力で奇襲',
          element: ElementType.dark,
          category: SkillCategory.attack,
          multiplier: 2.2,
          cooldown: 3,
        ),
        Skill(
          name: 'カースドレイン',
          description: '敵のHPを吸収',
          element: ElementType.dark,
          category: SkillCategory.special,
          multiplier: 0.2, // 与ダメの20%回復
          cooldown: 4,
        ),
      ];
  }
  return [];
}
