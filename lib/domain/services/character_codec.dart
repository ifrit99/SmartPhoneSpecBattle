import 'dart:convert';
import 'dart:typed_data';

import '../models/character.dart';
import '../models/decoded_character.dart';
import '../models/stats.dart';
import '../models/skill.dart';
import '../models/experience.dart';
import '../enums/element_type.dart';
import '../enums/rarity.dart';

/// キャラクターデータのバイナリエンコード/デコード
///
/// QRコード・URL共有用にキャラクターをコンパクトなBase64url文字列に変換する。
/// サーバーを介さず、データ自体にキャラ情報を埋め込む設計。
class CharacterCodec {
  static const int currentVersion = 1;
  static const int _fixedHeaderSize = 19;

  /// Character を Base64url 文字列にエンコード
  ///
  /// ガチャキャラの場合は [rarity] と [deviceName] を指定する。
  static String encode(
    Character character, {
    Rarity? rarity,
    String? deviceName,
  }) {
    final bytes = _toBytes(character, rarity, deviceName);
    return base64Url.encode(bytes);
  }

  /// Base64url 文字列から DecodedCharacter にデコード
  ///
  /// 不正なデータの場合は [FormatException] をスローする。
  static DecodedCharacter decode(String encoded) {
    final Uint8List bytes;
    try {
      bytes = base64Url.decode(encoded);
    } on FormatException {
      throw const FormatException('不正なBase64urlデータです');
    }
    return _fromBytes(bytes);
  }

  static Uint8List _toBytes(
    Character character,
    Rarity? rarity,
    String? deviceName,
  ) {
    final isGacha = rarity != null;
    final nameBytes = utf8.encode(character.name);
    final deviceNameBytes =
        isGacha ? utf8.encode(deviceName ?? '') : <int>[];

    // 合計サイズ: 固定ヘッダ + nameLen(1) + name + (deviceNameLen(1) + deviceName)?
    final totalSize = _fixedHeaderSize +
        1 +
        nameBytes.length +
        (isGacha ? 1 + deviceNameBytes.length : 0);

    final buffer = ByteData(totalSize);
    var offset = 0;

    // [0] version
    buffer.setUint8(offset++, currentVersion);

    // [1] flags: bit0=isGacha, bit1-2=rarity(0-3), bit3-5=element(0-5)
    int flags = 0;
    if (isGacha) flags |= 1;
    if (rarity != null) flags |= (rarity.index & 0x03) << 1;
    flags |= (character.element.index & 0x07) << 3;
    buffer.setUint8(offset++, flags);

    // [2] level
    buffer.setUint8(offset++, character.level.clamp(1, 255));

    // [3-4] baseHp
    buffer.setUint16(offset, character.baseStats.hp.clamp(0, 65535));
    offset += 2;

    // [5-6] baseMaxHp
    buffer.setUint16(offset, character.baseStats.maxHp.clamp(0, 65535));
    offset += 2;

    // [7] baseAtk
    buffer.setUint8(offset++, character.baseStats.atk.clamp(0, 255));

    // [8] baseDef
    buffer.setUint8(offset++, character.baseStats.def.clamp(0, 255));

    // [9] baseSpd
    buffer.setUint8(offset++, character.baseStats.spd.clamp(0, 255));

    // [10-13] seed
    buffer.setUint32(offset, character.seed & 0xFFFFFFFF);
    offset += 4;

    // [14-18] visual parts
    buffer.setUint8(offset++, character.headIndex.clamp(0, 255));
    buffer.setUint8(offset++, character.bodyIndex.clamp(0, 255));
    buffer.setUint8(offset++, character.armIndex.clamp(0, 255));
    buffer.setUint8(offset++, character.legIndex.clamp(0, 255));
    buffer.setUint8(offset++, character.colorPaletteIndex.clamp(0, 255));

    // [19] nameLen + name
    buffer.setUint8(offset++, nameBytes.length.clamp(0, 255));
    final result = buffer.buffer.asUint8List();
    result.setRange(offset, offset + nameBytes.length, nameBytes);
    offset += nameBytes.length;

    // ガチャキャラの場合: deviceNameLen + deviceName
    if (isGacha) {
      result[offset++] = deviceNameBytes.length.clamp(0, 255);
      result.setRange(
          offset, offset + deviceNameBytes.length, deviceNameBytes);
    }

    return result;
  }

  static DecodedCharacter _fromBytes(Uint8List bytes) {
    if (bytes.length < _fixedHeaderSize + 1) {
      throw const FormatException('データが短すぎます');
    }

    final buffer = ByteData.sublistView(bytes);
    var offset = 0;

    // [0] version
    final version = buffer.getUint8(offset++);
    if (version != currentVersion) {
      throw FormatException('未対応のバージョンです: v$version');
    }

    // [1] flags
    final flags = buffer.getUint8(offset++);
    final isGacha = (flags & 1) == 1;
    final rarityIndex = (flags >> 1) & 0x03;
    final elementIndex = (flags >> 3) & 0x07;

    if (elementIndex >= ElementType.values.length) {
      throw FormatException('不正な属性値です: $elementIndex');
    }

    final rarity = isGacha ? Rarity.values[rarityIndex] : null;
    final element = ElementType.values[elementIndex];

    // [2] level
    final level = buffer.getUint8(offset++);

    // [3-6] baseHp, baseMaxHp
    final baseHp = buffer.getUint16(offset);
    offset += 2;
    final baseMaxHp = buffer.getUint16(offset);
    offset += 2;

    // [7-9] baseAtk, baseDef, baseSpd
    final baseAtk = buffer.getUint8(offset++);
    final baseDef = buffer.getUint8(offset++);
    final baseSpd = buffer.getUint8(offset++);

    // [10-13] seed
    final seed = buffer.getUint32(offset);
    offset += 4;

    // [14-18] visual parts
    final headIndex = buffer.getUint8(offset++);
    final bodyIndex = buffer.getUint8(offset++);
    final armIndex = buffer.getUint8(offset++);
    final legIndex = buffer.getUint8(offset++);
    final colorPaletteIndex = buffer.getUint8(offset++);

    // [19] nameLen + name
    if (offset >= bytes.length) {
      throw const FormatException('名前データが不足しています');
    }
    final nameLen = buffer.getUint8(offset++);
    if (offset + nameLen > bytes.length) {
      throw const FormatException('名前データが不正です');
    }
    final name = utf8.decode(bytes.sublist(offset, offset + nameLen));
    offset += nameLen;

    // ガチャキャラの場合: deviceNameLen + deviceName
    String? deviceName;
    if (isGacha) {
      if (offset >= bytes.length) {
        throw const FormatException('デバイス名データが不足しています');
      }
      final deviceNameLen = buffer.getUint8(offset++);
      if (offset + deviceNameLen > bytes.length) {
        throw const FormatException('デバイス名データが不正です');
      }
      deviceName =
          utf8.decode(bytes.sublist(offset, offset + deviceNameLen));
    }

    final baseStats = Stats(
      hp: baseHp,
      maxHp: baseMaxHp,
      atk: baseAtk,
      def: baseDef,
      spd: baseSpd,
    );

    // Experience を level から復元（共有データに経験値詳細は不要）
    final experience = Experience(level: level);

    // スキルは属性から復元
    final skills = getSkillsForElement(element);

    final character = Character(
      name: name,
      element: element,
      baseStats: baseStats,
      currentStats: baseStats.levelUp(level),
      skills: skills,
      experience: experience,
      seed: seed,
      headIndex: headIndex,
      bodyIndex: bodyIndex,
      armIndex: armIndex,
      legIndex: legIndex,
      colorPaletteIndex: colorPaletteIndex,
    );

    return DecodedCharacter(
      character: character,
      isGacha: isGacha,
      rarity: rarity,
      deviceName: deviceName,
    );
  }
}
