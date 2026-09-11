import 'package:flutter/material.dart';

import '../../domain/data/battle_sprite_anchors.dart';
import '../../domain/models/character.dart';
import '../../domain/models/portrait_id.dart';
import 'pixel_character.dart';

/// アクセサリー色（`elementColor` 6色 + 白・黒・金・銀・桃・青緑）。
const List<Color> battleAccessoryColors = [
  Color(0xFFFF6B6B),
  Color(0xFF74B9FF),
  Color(0xFFFDCB6E),
  Color(0xFF55EFC4),
  Color(0xFFFFF176),
  Color(0xFFAB47BC),
  Color(0xFFFFFFFF),
  Color(0xFF000000),
  Color(0xFFFFD700),
  Color(0xFFC0C0C0),
  Color(0xFFFD79A8),
  Color(0xFF4ECDC4),
];

/// アクセサリー表示名（index 0 = なし）。
const List<String> battleAccessoryLabels = [
  'なし',
  'リボン',
  'バイザー',
  'イヤーピース',
  'バッジ',
  'ストラップ',
  'スラブ',
  'ヘアピン',
];

/// accessoryIndex 1–7 の 48×48 オーバーレイ。0（なし）は null。
String? battleAccessoryAssetPath(int accessoryIndex) {
  return switch (accessoryIndex % 8) {
    1 => 'assets/images/accessories/accessory_01_ribbon.png',
    2 => 'assets/images/accessories/accessory_02_visor.png',
    3 => 'assets/images/accessories/accessory_03_earpiece.png',
    4 => 'assets/images/accessories/accessory_04_badge.png',
    5 => 'assets/images/accessories/accessory_05_strap.png',
    6 => 'assets/images/accessories/accessory_06_slab.png',
    7 => 'assets/images/accessories/accessory_07_hairpins.png',
    _ => null,
  };
}

/// ポートレートの表示形態（RFC §4 / §8）
enum PortraitVariant { bust, full, battle }

/// 擬人化ポートレートを表示する。未出荷・読込失敗時は [PixelCharacter] にフォールバックする。
class CharacterPortrait extends StatelessWidget {
  /// full/bust/battle の三揃い PNG があるキーだけを載せる。
  static const Set<String> shippedPortraitKeys = {
    'fire_0',
    'fire_1',
    'fire_2',
    'fire_3',
    'water_0',
    'water_1',
    'water_2',
    'water_3',
    'earth_0',
    'earth_1',
    'earth_2',
    'earth_3',
    'wind_0',
    'wind_1',
    'wind_2',
    'wind_3',
    'light_0',
    'light_1',
    'light_2',
    'light_3',
    'dark_0',
    'dark_1',
    'dark_2',
    'dark_3',
  };

  final Character character;
  final PortraitVariant variant;
  final double height;
  final bool flipHorizontal;

  /// true のとき height×height の正方形に切り、上寄せ cover で顔を残す（ミニアイコン用）。
  /// bust 以外の variant では無視する。
  final bool square;

  /// テストからマニフェストを差し替える。本番は [shippedPortraitKeys] を使う。
  @visibleForTesting
  final Set<String>? shippedKeysOverride;

  const CharacterPortrait({
    super.key,
    required this.character,
    required this.variant,
    required this.height,
    this.flipHorizontal = false,
    this.square = false,
    this.shippedKeysOverride,
  });

  Set<String> get _shippedKeys => shippedKeysOverride ?? shippedPortraitKeys;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: character.name,
      child: _maybeFlip(_buildContent()),
    );
  }

  Widget _maybeFlip(Widget child) {
    if (!flipHorizontal) {
      return child;
    }
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..setEntry(0, 0, -1.0),
      child: child,
    );
  }

  Widget _buildContent() {
    final id = PortraitId.fromCharacter(character);
    final resolvedKey = id.resolveShippedKey(_shippedKeys);
    if (resolvedKey == null) {
      if (variant == PortraitVariant.battle) {
        return SizedBox(
          width: height,
          height: height,
          child: _fallbackPixel(size: height),
        );
      }
      return _fallbackPixel(size: height);
    }

    final assetPath = _assetPathForKey(resolvedKey);
    if (variant == PortraitVariant.battle) {
      return _buildBattlePortrait(assetPath, resolvedKey);
    }
    if (variant == PortraitVariant.bust && square) {
      return SizedBox(
        width: height,
        height: height,
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (context, error, stackTrace) =>
              _fallbackPixel(size: height),
        ),
      );
    }
    return Image.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _fallbackPixel(size: height),
    );
  }

  /// 現行 `charSize` の正方形アンカーを維持し、48 または 96 論理 px に整数倍する。
  Widget _buildBattlePortrait(String assetPath, String portraitKey) {
    final spriteSize = height >= 96 ? 96.0 : 48.0;
    final accessoryPath = battleAccessoryAssetPath(character.accessoryIndex);
    final showAura = character.auraIndex != 0;
    final tint = battleAccessoryColors[
        character.colorPaletteIndex % battleAccessoryColors.length];
    return SizedBox(
      width: height,
      height: height,
      child: Center(
        child: SizedBox(
          width: spriteSize,
          height: spriteSize,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                assetPath,
                width: spriteSize,
                height: spriteSize,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                isAntiAlias: false,
                errorBuilder: (context, error, stackTrace) =>
                    _fallbackPixel(size: spriteSize),
              ),
              if (accessoryPath != null)
                ColorFiltered(
                  colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
                  child: Image.asset(
                    accessoryPath,
                    width: spriteSize,
                    height: spriteSize,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.none,
                    isAntiAlias: false,
                  ),
                ),
              if (showAura)
                CustomPaint(
                  painter: _BattleAccessoryPainter(
                    character: character,
                    portraitKey: portraitKey,
                    spriteSize: spriteSize,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackPixel({required double size}) {
    return PixelCharacter(
      character: character,
      size: size,
    );
  }

  String _assetPathForKey(String key) {
    final resolved = PortraitId(
      elementName: key.substring(0, key.lastIndexOf('_')),
      archetype: int.parse(key.substring(key.lastIndexOf('_') + 1)),
    );
    return switch (variant) {
      PortraitVariant.full => resolved.fullAsset,
      PortraitVariant.bust => resolved.bustAsset,
      PortraitVariant.battle => resolved.battleAsset,
    };
  }
}

/// バトルスプライト（48 グリッド）に足元の影を重ねる。
/// アクセサリーは [_buildBattlePortrait] の PNG Image オーバーレイ。
class _BattleAccessoryPainter extends CustomPainter {
  final Character character;
  final String portraitKey;
  final double spriteSize;

  _BattleAccessoryPainter({
    required this.character,
    required this.portraitKey,
    required this.spriteSize,
  });

  int get _scale => spriteSize ~/ 48;

  static const _shadow = Color(0x66000000);

  @override
  void paint(Canvas canvas, Size size) {
    if (character.auraIndex != 0) {
      _drawAura(canvas, anchorsFor(portraitKey));
    }
  }

  void _drawAura(Canvas canvas, BattleAnchors anchors) {
    final cx = anchors.centerX;
    final pixels = <(int, int)>{};
    switch (character.auraIndex % 6) {
      case 1: // 楕円
        for (var x = cx - 4; x <= cx + 4; x++) {
          pixels.add((x, 46));
        }
        for (var x = cx - 5; x <= cx + 5; x++) {
          pixels.add((x, 47));
        }
      case 2: // 細い楕円
        for (var x = cx - 4; x <= cx + 4; x++) {
          pixels.add((x, 47));
        }
      case 3: // リング
        pixels.addAll([
          (cx - 4, 46),
          (cx - 3, 46),
          (cx + 3, 46),
          (cx + 4, 46),
          (cx - 5, 47),
          (cx - 4, 47),
          (cx + 4, 47),
          (cx + 5, 47),
        ]);
      case 4: // ひし形
        pixels.addAll([
          (cx, 46),
          (cx - 1, 47),
          (cx, 47),
          (cx + 1, 47),
        ]);
      case 5: // 二重楕円
        for (var x = cx - 5; x <= cx + 5; x++) {
          pixels.add((x, 46));
        }
        for (var x = cx - 2; x <= cx + 2; x++) {
          pixels.add((x, 47));
        }
    }
    for (final (x, y) in pixels) {
      _cell(canvas, x, y, _shadow);
    }
  }

  void _cell(Canvas canvas, int x, int y, Color color) {
    if (x < 0 || x > 47 || y < 0 || y > 47) {
      return;
    }
    canvas.drawRect(
      Rect.fromLTWH(
        (x * _scale).toDouble(),
        (y * _scale).toDouble(),
        _scale.toDouble(),
        _scale.toDouble(),
      ),
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(covariant _BattleAccessoryPainter oldDelegate) {
    return oldDelegate.character.auraIndex != character.auraIndex ||
        oldDelegate.portraitKey != portraitKey ||
        oldDelegate.spriteSize != spriteSize;
  }
}
