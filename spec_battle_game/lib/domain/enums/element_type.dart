/// キャラクターの属性タイプ
enum ElementType {
  fire,   // 炎
  water,  // 水
  earth,  // 地
  wind,   // 風
  light,  // 光
  dark,   // 闇
}

/// OSバージョンから属性を決定
ElementType elementFromOsVersion(String osVersion) {
  // バージョン文字列から数値を抽出
  final digits = osVersion.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return ElementType.fire;
  final num = int.parse(digits) % ElementType.values.length;
  return ElementType.values[num];
}

/// 属性の日本語名
String elementName(ElementType type) {
  switch (type) {
    case ElementType.fire:
      return '炎';
    case ElementType.water:
      return '水';
    case ElementType.earth:
      return '地';
    case ElementType.wind:
      return '風';
    case ElementType.light:
      return '光';
    case ElementType.dark:
      return '闇';
  }
  return '';
}

/// 属性の相性倍率を返す（攻撃側 → 守備側）
double elementMultiplier(ElementType attacker, ElementType defender) {
  // 炎→風, 水→炎, 地→光, 風→地, 光→闇, 闇→水 で有利（1.5倍）
  const advantages = {
    ElementType.fire: ElementType.wind,
    ElementType.water: ElementType.fire,
    ElementType.earth: ElementType.light,
    ElementType.wind: ElementType.earth,
    ElementType.light: ElementType.dark,
    ElementType.dark: ElementType.water,
  };
  if (advantages[attacker] == defender) return 1.5;
  if (advantages[defender] == attacker) return 0.75;
  return 1.0;
}
