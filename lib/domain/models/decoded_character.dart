import 'character.dart';
import '../enums/rarity.dart';

/// QR/URLからデコードされたキャラクターデータ
class DecodedCharacter {
  final Character character;
  final bool isGacha;
  final Rarity? rarity;
  final String? deviceName;

  const DecodedCharacter({
    required this.character,
    required this.isGacha,
    this.rarity,
    this.deviceName,
  });

  /// バトル用のCharacterを取得（そのまま BattleEngine に渡せる）
  Character get battleCharacter => character;
}
