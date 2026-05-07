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
  ///
  /// base64urlのパディング(`=`)を除去してURLに安全に埋め込む。
  /// [extractBattleParam] 側でパディングを復元するため、ペアで使用する。
  String generateShareUrl(String encoded) {
    String base;
    if (baseUrl.isNotEmpty) {
      base = baseUrl;
    } else {
      // Uri.base からquery/fragmentを除去し、パスのみ保持する
      // （共有リンク経由で開いた場合に既存の?battle=が混入するのを防ぐ）
      final clean = Uri.base.replace(query: '', fragment: '');
      base = clean.toString().replaceAll(RegExp(r'[?#/]+$'), '');
    }
    // base64urlパディングを除去してURL安全にする
    // base64url文字（A-Za-z0-9_-）はURLクエリ内で安全にそのまま使用可能
    final safeEncoded = _stripBase64Padding(encoded);
    return '$base/?battle=$safeEncoded';
  }

  /// URLから対戦パラメータを抽出（nullならパラメータなし）
  ///
  /// [generateShareUrl]で除去されたbase64urlパディングを復元する。
  /// ブラウザの挙動によりスペースや`+`が混入する場合も除去する。
  static String? extractBattleParam(Uri uri) {
    final raw = uri.queryParameters['battle'];
    if (raw == null) return null;
    // スペースや+を除去（ブラウザのURLデコードで混入する場合への対策）
    final cleaned = raw.replaceAll(' ', '').replaceAll('+', '');
    return _restoreBase64Padding(cleaned);
  }

  /// URLまたは生コードの入力値を、デコード可能な対戦コードに正規化する。
  ///
  /// 共有URL入力時は `battle` パラメータを抽出し、
  /// 生コード入力時は不足しているbase64urlパディングを復元する。
  static String normalizeBattleInput(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      final extracted = extractBattleParam(uri);
      if (extracted != null && extracted.isNotEmpty) {
        return extracted;
      }
    }

    final cleaned = trimmed.replaceAll(' ', '').replaceAll('+', '');
    return _restoreBase64Padding(cleaned);
  }

  /// base64urlのパディング(`=`)を除去
  static String _stripBase64Padding(String encoded) {
    return encoded.replaceAll('=', '');
  }

  /// base64urlのパディングを復元（4の倍数になるよう`=`を追加）
  static String _restoreBase64Padding(String encoded) {
    final remainder = encoded.length % 4;
    if (remainder == 0) return encoded;
    return encoded + '=' * (4 - remainder);
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
