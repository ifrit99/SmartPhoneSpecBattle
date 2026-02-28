import '../models/character.dart';
import '../models/decoded_character.dart';
import '../models/gacha_character.dart';
import '../enums/rarity.dart';
import 'character_codec.dart';

/// QR/URL対戦に関するエンコード・デコード・ゲスト敵生成を担うサービス
///
/// UI層（QRコード表示やカメラ読み取り画面）はAntigravity側が担当するため、
/// このサービスはデータ変換と検証ロジックに専念する。
class QrBattleService {
  /// 実機キャラクターをQR/URL共有用文字列にエンコード
  String encodePlayerCharacter(Character character) {
    return CharacterCodec.encode(character);
  }

  /// ガチャキャラクターをQR/URL共有用文字列にエンコード
  String encodeGachaCharacter(GachaCharacter gachaCharacter) {
    return CharacterCodec.encode(
      gachaCharacter.character,
      rarity: gachaCharacter.rarity,
      deviceName: gachaCharacter.deviceName,
    );
  }

  /// QR/URLから読み取った文字列をデコードしてゲスト敵を生成
  ///
  /// チェックサム検証を行い、不正データの場合は例外をスローする。
  /// 戻り値の [QrBattleGuest] にはデコード済みキャラクターと
  /// バトル用Characterが含まれる。
  QrBattleGuest decodeAsGuest(String encoded) {
    final decoded = CharacterCodec.decode(encoded);
    return QrBattleGuest.fromDecoded(decoded);
  }

  /// URL共有用のディープリンクURLを生成
  ///
  /// [baseUrl] はアプリのディープリンクベースURL。
  /// 例: `specbattle://battle?data=<encoded>`
  String generateShareUrl(String encoded, {String scheme = 'specbattle'}) {
    return '$scheme://battle?data=$encoded';
  }

  /// ディープリンクURLからエンコード済みデータを抽出
  ///
  /// URLが正しい形式でない場合は null を返す。
  String? extractFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    return uri.queryParameters['data'];
  }
}

/// QR/URLからスキャンしたゲスト敵キャラクター
///
/// バトル画面にそのまま渡せる形式で保持する。
class QrBattleGuest {
  /// デコードされたキャラクター名
  final String name;

  /// ソースデバイス名（ガチャキャラの場合）
  final String? deviceName;

  /// レアリティ（ガチャキャラの場合）
  final Rarity? rarity;

  /// ガチャ産かどうか
  final bool isGacha;

  /// バトル用Character（BattleEngineに渡す）
  final Character battleCharacter;

  /// 表示用ラベル（例: "[SR] Galaxy S25"）
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
