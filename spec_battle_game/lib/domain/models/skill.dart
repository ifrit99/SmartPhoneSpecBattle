import '../enums/element_type.dart';
import '../enums/effect_type.dart';
import 'status_effect.dart';

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
  final StatusEffect? effect; // 付与する効果
  final bool isSelfTarget;    // 自分自身が対象か

  const Skill({
    required this.name,
    required this.description,
    required this.element,
    required this.category,
    this.multiplier = 1.0,
    this.cooldown = 0,
    this.effect,
    this.isSelfTarget = false,
  });

  @override
  String toString() => '$name ($category)';
}

/// 属性別のデフォルトスキル定義
List<Skill> getSkillsForElement(ElementType element) {
  switch (element) {
    case ElementType.fire:
      return [
        const Skill(name: 'ファイアボール', description: '炎の球を投げつける', element: ElementType.fire, category: SkillCategory.attack, multiplier: 1.8, cooldown: 2),
        const Skill(
          name: '灼熱の壁',
          description: '炎の壁で防御力UP',
          element: ElementType.fire,
          category: SkillCategory.defense,
          multiplier: 0.0,
          cooldown: 4,
          effect: StatusEffect(id: 'fire_def_up', type: EffectType.defenseUp, duration: 3, value: 20),
          isSelfTarget: true,
        ),
        const Skill(
          name: 'フレイムチャージ',
          description: '炎を纏って攻撃力UP',
          element: ElementType.fire,
          category: SkillCategory.special,
          multiplier: 0.0,
          cooldown: 4,
          effect: StatusEffect(id: 'fire_atk_up', type: EffectType.attackUp, duration: 3, value: 30),
          isSelfTarget: true,
        ),
      ];
    case ElementType.water:
      return [
        const Skill(name: 'ウォータースラッシュ', description: '水の刃で斬りつける', element: ElementType.water, category: SkillCategory.attack, multiplier: 1.7, cooldown: 2),
        const Skill(name: 'ヒーリングウェーブ', description: '水の力でHPを回復', element: ElementType.water, category: SkillCategory.special, multiplier: 0.4, cooldown: 4, isSelfTarget: true),
        const Skill(
          name: 'アクアベール',
          description: '水の膜で防御力UP',
          element: ElementType.water,
          category: SkillCategory.defense,
          multiplier: 0.0,
          cooldown: 4,
          effect: StatusEffect(id: 'water_def_up', type: EffectType.defenseUp, duration: 3, value: 25),
          isSelfTarget: true,
        ),
      ];
    case ElementType.earth:
      return [
        const Skill(name: 'ロックスマッシュ', description: '巨大な岩を叩きつける', element: ElementType.earth, category: SkillCategory.attack, multiplier: 2.0, cooldown: 3),
        const Skill(
          name: 'ストーンアーマー',
          description: '岩の鎧で大幅防御力UP',
          element: ElementType.earth,
          category: SkillCategory.defense,
          multiplier: 0.0,
          cooldown: 5,
          effect: StatusEffect(id: 'earth_def_up', type: EffectType.defenseUp, duration: 3, value: 40),
          isSelfTarget: true,
        ),
        const Skill(
          name: 'アースクエイク',
          description: '地震を起こして敵の素早さDOWN',
          element: ElementType.earth,
          category: SkillCategory.special,
          multiplier: 1.2,
          cooldown: 4,
          effect: StatusEffect(id: 'earth_spd_down', type: EffectType.speedDown, duration: 3, value: 20),
        ),
      ];
    case ElementType.wind:
      return [
        const Skill(name: 'エアカッター', description: '鋭い風で切り裂く', element: ElementType.wind, category: SkillCategory.attack, multiplier: 1.5, cooldown: 1),
        const Skill(
          name: 'スピードブースト',
          description: '風の力で素早さUP',
          element: ElementType.wind,
          category: SkillCategory.special,
          multiplier: 0.0,
          cooldown: 3,
          effect: StatusEffect(id: 'wind_spd_up', type: EffectType.speedUp, duration: 3, value: 30),
          isSelfTarget: true,
        ),
        const Skill(
          name: 'ダウンバースト',
          description: '強烈な下降気流で敵の攻撃力DOWN',
          element: ElementType.wind,
          category: SkillCategory.special,
          multiplier: 1.2,
          cooldown: 4,
          effect: StatusEffect(id: 'wind_atk_down', type: EffectType.attackDown, duration: 3, value: 20),
        ),
      ];
    case ElementType.light:
      return [
        const Skill(name: 'ホーリーレイ', description: '聖なる光で攻撃', element: ElementType.light, category: SkillCategory.attack, multiplier: 1.9, cooldown: 2),
        const Skill(
          name: 'バリア',
          description: '光の盾で防御力UP',
          element: ElementType.light,
          category: SkillCategory.defense,
          multiplier: 0.0,
          cooldown: 4,
          effect: StatusEffect(id: 'light_def_up', type: EffectType.defenseUp, duration: 3, value: 20),
          isSelfTarget: true,
        ),
        const Skill(
          name: 'セイントヒール',
          description: '継続回復を付与',
          element: ElementType.light,
          category: SkillCategory.special,
          multiplier: 0.0,
          cooldown: 5,
          effect: StatusEffect(id: 'light_regen', type: EffectType.regen, duration: 3, value: 15), // 15%回復
          isSelfTarget: true,
        ),
      ];
    case ElementType.dark:
      return [
        const Skill(name: 'シャドウストライク', description: '闇の力で奇襲', element: ElementType.dark, category: SkillCategory.attack, multiplier: 2.2, cooldown: 3),
        const Skill(
          name: 'カースドレイン',
          description: '敵のHPを吸収',
          element: ElementType.dark,
          category: SkillCategory.special,
          multiplier: 0.3,
          cooldown: 4,
          isSelfTarget: false, // 攻撃+回復なので敵対象
        ),
        const Skill(
          name: 'ウィークネス',
          description: '敵の防御力を下げる',
          element: ElementType.dark,
          category: SkillCategory.special,
          multiplier: 0.5,
          cooldown: 3,
          effect: StatusEffect(id: 'dark_def_down', type: EffectType.defenseDown, duration: 3, value: 25),
        ),
      ];
  }
}
