/// バトルスプライト（48×48）上のアクセサリー／影アンカー。
///
/// 値は `assets/images/characters/{key}_battle.png` を
/// `identify -format '%@'`（トリム境界 `WxH+X+Y`）で測り、
/// 頭頂 = Y、水平中央 = X + W/2、肩 = Y + round(H×0.38)、
/// 胸 = Y + round(H×0.52) として 0–47 に収めたもの。
class BattleAnchors {
  final int headTopY;
  final int chestY;
  final int shoulderY;
  final int centerX;

  const BattleAnchors({
    required this.headTopY,
    required this.chestY,
    required this.shoulderY,
    required this.centerX,
  });
}

/// 未登録キー向けの既定アンカー（RFC §3-5-1）。
const BattleAnchors defaultBattleAnchors = BattleAnchors(
  headTopY: 6,
  chestY: 22,
  shoulderY: 16,
  centerX: 24,
);

/// `PortraitId.key` → 実測アンカー。24 体すべてを載せる。
const Map<String, BattleAnchors> battleSpriteAnchors = {
  'fire_0': BattleAnchors(headTopY: 4, chestY: 25, shoulderY: 20, centerX: 24),
  'fire_1': BattleAnchors(headTopY: 5, chestY: 25, shoulderY: 20, centerX: 22),
  'fire_2': BattleAnchors(headTopY: 4, chestY: 25, shoulderY: 20, centerX: 23),
  'fire_3': BattleAnchors(headTopY: 5, chestY: 25, shoulderY: 19, centerX: 23),
  'water_0': BattleAnchors(headTopY: 5, chestY: 25, shoulderY: 20, centerX: 24),
  'water_1': BattleAnchors(headTopY: 6, chestY: 25, shoulderY: 20, centerX: 25),
  'water_2': BattleAnchors(headTopY: 5, chestY: 25, shoulderY: 19, centerX: 24),
  'water_3': BattleAnchors(headTopY: 5, chestY: 25, shoulderY: 19, centerX: 22),
  'earth_0': BattleAnchors(headTopY: 3, chestY: 25, shoulderY: 19, centerX: 25),
  'earth_1': BattleAnchors(headTopY: 5, chestY: 26, shoulderY: 20, centerX: 23),
  'earth_2': BattleAnchors(headTopY: 5, chestY: 26, shoulderY: 20, centerX: 24),
  'earth_3': BattleAnchors(headTopY: 4, chestY: 25, shoulderY: 20, centerX: 24),
  'wind_0': BattleAnchors(headTopY: 4, chestY: 25, shoulderY: 19, centerX: 23),
  'wind_1': BattleAnchors(headTopY: 5, chestY: 26, shoulderY: 21, centerX: 22),
  'wind_2': BattleAnchors(headTopY: 5, chestY: 25, shoulderY: 20, centerX: 22),
  'wind_3': BattleAnchors(headTopY: 6, chestY: 26, shoulderY: 20, centerX: 24),
  'light_0': BattleAnchors(headTopY: 6, chestY: 25, shoulderY: 20, centerX: 25),
  'light_1': BattleAnchors(headTopY: 4, chestY: 25, shoulderY: 20, centerX: 25),
  'light_2': BattleAnchors(headTopY: 6, chestY: 25, shoulderY: 20, centerX: 23),
  'light_3': BattleAnchors(headTopY: 4, chestY: 25, shoulderY: 20, centerX: 24),
  'dark_0': BattleAnchors(headTopY: 6, chestY: 25, shoulderY: 20, centerX: 22),
  'dark_1': BattleAnchors(headTopY: 7, chestY: 25, shoulderY: 20, centerX: 23),
  'dark_2': BattleAnchors(headTopY: 3, chestY: 25, shoulderY: 19, centerX: 23),
  'dark_3': BattleAnchors(headTopY: 5, chestY: 25, shoulderY: 19, centerX: 24),
};

/// [key] のアンカー。未登録なら [defaultBattleAnchors]。
BattleAnchors anchorsFor(String key) =>
    battleSpriteAnchors[key] ?? defaultBattleAnchors;
