import 'package:flutter/material.dart';

import '../../domain/models/character.dart';
import '../../domain/models/portrait_id.dart';
import 'pixel_character.dart';

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
  };

  final Character character;
  final PortraitVariant variant;
  final double height;
  final bool flipHorizontal;

  /// テストからマニフェストを差し替える。本番は [shippedPortraitKeys] を使う。
  @visibleForTesting
  final Set<String>? shippedKeysOverride;

  const CharacterPortrait({
    super.key,
    required this.character,
    required this.variant,
    required this.height,
    this.flipHorizontal = false,
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
      return _buildBattlePortrait(assetPath);
    }
    return Image.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _fallbackPixel(size: height),
    );
  }

  /// 現行 `charSize` の正方形アンカーを維持し、48 または 96 論理 px に整数倍する。
  Widget _buildBattlePortrait(String assetPath) {
    final spriteSize = height >= 96 ? 96.0 : 48.0;
    return SizedBox(
      width: height,
      height: height,
      child: Center(
        child: Image.asset(
          assetPath,
          width: spriteSize,
          height: spriteSize,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
          isAntiAlias: false,
          errorBuilder: (context, error, stackTrace) =>
              _fallbackPixel(size: spriteSize),
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
