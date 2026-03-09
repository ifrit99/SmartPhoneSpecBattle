import '../models/character.dart';
import '../models/decoded_character.dart';
import '../models/gacha_character.dart';
import '../enums/rarity.dart';
import 'character_codec.dart';

/// URL対戦に関するエンコード・デコード・URL生成を担うサービス
class QrBattleService {
  /// デプロイ先のベースURL
  final String baseUrl;

  QrBattleService({this.baseUrl = ''});

  /// 実機キャラクターをURL共有用文字列にエンコード
  String encodePlayerCharacter(Character character) {
    return CharacterCodec.encode(character);
  }

  /// ガチャキャラクターをURL共有用文字列にエンコード
  String encodeGachaCharacter(GachaCharacter gachaCharacter) {
    return CharacterCodec.encode(
      gachaCharacter.character,
      rarity: gachaCharacter.rarity,
      deviceName: gachaCharacter.deviceName,
    );
  }

  /// 読み取った文字列をデコードしてゲスト敵を生成
  QrBattleGuest decodeAsGuest(String encoded) {
    final decoded = CharacterCodec.decode(encoded);
    return QrBattleGuest.fromDecoded(decoded);
  }

  /// エンコード済みデータからWeb共有URLを生成
  String generateShareUrl(String encoded) {
    final base = baseUrl.isNotEmpty ? baseUrl : Uri.base.origin;
    return '$base/?battle=$encoded';
  }

  /// URLから対戦パラメータを抽出（nullならパラメータなし）
  static String? extractBattleParam(Uri uri) {
    return uri.queryParameters['battle'];
  }
}

/// URL対戦で受信したゲストキャラクター情報
class QrBattleGuest {
  final String name;
  final String? deviceName;
  final Rarity? rarity;
  final bool isGacha;
  final Character battleCharacter;
  final String displayLabel;

  const QrBattleGuest({
    required this.name,
    required this.deviceName,
    required this.rarity,
    required this.isGacha,
    required this.battleCharacter,
    required this.displayLabel,
  });

  factory QrBattleGuest.fromDecoded(DecodedCharacter decoded) {
    final character = decoded.character;

    String label;
    if (decoded.isGacha && decoded.rarity != null) {
      final rarityTag = '[${decoded.rarity!.label}]';
      final device = decoded.deviceName ?? '';
      label = device.isNotEmpty
          ? '$rarityTag $device — ${character.name}'
          : '$rarityTag ${character.name}';
    } else {
      label = character.name;
    }

    return QrBattleGuest(
      name: character.name,
      deviceName: decoded.deviceName,
      rarity: decoded.rarity,
      isGacha: decoded.isGacha,
      battleCharacter: decoded.battleCharacter,
      displayLabel: label,
    );
  }
}
