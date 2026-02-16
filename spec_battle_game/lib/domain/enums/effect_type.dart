/// ステータス効果の種類
enum EffectType {
  attackUp,
  attackDown,
  defenseUp,
  defenseDown,
  speedUp,
  speedDown,
  poison,   // 継続ダメージ
  regen,    // 継続回復
  stun,     // 行動不能
}

extension EffectTypeExtension on EffectType {
  String get label {
    switch (this) {
      case EffectType.attackUp:
        return '攻撃力UP';
      case EffectType.attackDown:
        return '攻撃力DOWN';
      case EffectType.defenseUp:
        return '防御力UP';
      case EffectType.defenseDown:
        return '防御力DOWN';
      case EffectType.speedUp:
        return '素早さUP';
      case EffectType.speedDown:
        return '素早さDOWN';
      case EffectType.poison:
        return '毒';
      case EffectType.regen:
        return '再生';
      case EffectType.stun:
        return 'スタン';
    }
  }

  bool get isBuff {
    switch (this) {
      case EffectType.attackUp:
      case EffectType.defenseUp:
      case EffectType.speedUp:
      case EffectType.regen:
        return true;
      default:
        return false;
    }
  }
}
