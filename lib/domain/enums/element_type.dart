/// キャラクターの属性タイプ
enum ElementType {
  fire,   // 炎
  water,  // 水
  earth,  // 地
  wind,   // 風
  light,  // 光
  dark,   // 闇
}

/// ElementType のドメイン用拡張
extension ElementTypeExtension on ElementType {
  /// 属性の日本語名
  String get label {
    return switch (this) {
      ElementType.fire  => '炎',
      ElementType.water => '水',
      ElementType.earth => '地',
      ElementType.wind  => '風',
      ElementType.light => '光',
      ElementType.dark  => '闇',
    };
  }

  /// 属性の相性倍率を返す（this が攻撃側）
  double multiplierAgainst(ElementType defender) {
    const advantages = {
      ElementType.fire: ElementType.wind,
      ElementType.water: ElementType.fire,
      ElementType.earth: ElementType.light,
      ElementType.wind: ElementType.earth,
      ElementType.light: ElementType.dark,
      ElementType.dark: ElementType.water,
    };
    if (advantages[this] == defender) return 1.5;
    if (advantages[defender] == this) return 0.75;
    return 1.0;
  }
}

/// OSバージョンから属性を決定
ElementType elementFromOsVersion(String osVersion) {
  final digits = osVersion.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return ElementType.fire;
  final num = int.parse(digits) % ElementType.values.length;
  return ElementType.values[num];
}

/// 後方互換: 属性の日本語名
String elementName(ElementType type) => type.label;

/// 後方互換: 属性の相性倍率
double elementMultiplier(ElementType attacker, ElementType defender) =>
    attacker.multiplierAgainst(defender);
