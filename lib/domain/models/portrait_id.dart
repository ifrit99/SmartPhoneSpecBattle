import 'character.dart';

/// 表示時に `element` と `seed` から導出するポートレート ID。
///
/// RFC §7: `archetype = seed.abs() % 4`、`key = '${element.name}_$archetype'`。
/// Flutter に依存しない純粋な Dart ロジック。
class PortraitId {
  /// `ElementType.name`（fire/water/earth/wind/light/dark）
  final String elementName;

  /// 0–3。名前接頭語と同じ `seed.abs() % 4`
  final int archetype;

  const PortraitId({
    required this.elementName,
    required this.archetype,
  });

  /// [Character] からポートレート ID を導出する。
  factory PortraitId.fromCharacter(Character character) {
    return PortraitId(
      elementName: character.element.name,
      archetype: character.seed.abs() % 4,
    );
  }

  /// `{element}_{archetype}`（例: `fire_0`）
  String get key => '${elementName}_$archetype';

  String get fullAsset => 'assets/images/characters/${key}_full.png';

  String get bustAsset => 'assets/images/characters/${key}_bust.png';

  String get battleAsset => 'assets/images/characters/${key}_battle.png';

  /// RFC §7 の解決順で、出荷済みマニフェストから使うキーを返す。
  ///
  /// 端末固有 override（スライス3以降）→ `{element}_{archetype}` →
  /// `{element}_0` → 見つからなければ null（呼び出し側で PixelCharacter）。
  String? resolveShippedKey(
    Set<String> shipped, {
    String? deviceOverrideKey,
  }) {
    if (deviceOverrideKey != null && shipped.contains(deviceOverrideKey)) {
      return deviceOverrideKey;
    }
    if (shipped.contains(key)) {
      return key;
    }
    final commanderKey = '${elementName}_0';
    if (shipped.contains(commanderKey)) {
      return commanderKey;
    }
    return null;
  }
}
