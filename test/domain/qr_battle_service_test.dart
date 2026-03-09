import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/gacha_character.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/domain/models/skill.dart';
import 'package:spec_battle_game/domain/models/experience.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/enums/rarity.dart';
import 'package:spec_battle_game/domain/services/character_codec.dart';
import 'package:spec_battle_game/domain/services/qr_battle_service.dart';

/// テスト用のCharacterを生成するヘルパー
Character _makeCharacter({
  String name = 'テスト・ウォリアー',
  ElementType element = ElementType.fire,
  int hp = 120,
  int atk = 18,
  int def = 14,
  int spd = 12,
  int level = 5,
  int seed = 42,
}) {
  final baseStats = Stats(hp: hp, maxHp: hp, atk: atk, def: def, spd: spd);
  return Character(
    name: name,
    element: element,
    baseStats: baseStats,
    currentStats: baseStats.levelUp(level),
    skills: getSkillsForElement(element),
    experience: Experience(level: level),
    seed: seed,
    headIndex: 2,
    bodyIndex: 1,
    armIndex: 3,
    legIndex: 0,
    colorPaletteIndex: 4,
  );
}

/// テスト用のGachaCharacterを生成するヘルパー
GachaCharacter _makeGachaCharacter({
  String name = 'ガチャ戦士',
  String deviceName = 'Galaxy S25',
  Rarity rarity = Rarity.sr,
}) {
  final character = _makeCharacter(name: name);
  return GachaCharacter(
    id: 'test_id_${DateTime.now().millisecondsSinceEpoch}',
    deviceName: deviceName,
    rarity: rarity,
    obtainedAt: DateTime.now(),
    character: character,
  );
}

void main() {
  late QrBattleService service;

  setUp(() {
    service = QrBattleService();
  });

  group('QrBattleService - 実機キャラエンコード', () {
    test('実機キャラをエンコード→デコードしてゲスト敵を生成できる', () {
      final character = _makeCharacter();
      final encoded = service.encodePlayerCharacter(character);
      final guest = service.decodeAsGuest(encoded);

      expect(guest.isGacha, false);
      expect(guest.rarity, isNull);
      expect(guest.name, character.name);
      expect(guest.battleCharacter.baseStats.atk, character.baseStats.atk);
    });

    test('実機キャラのdisplayLabelはキャラ名のみ', () {
      final character = _makeCharacter(name: '炎の戦士');
      final encoded = service.encodePlayerCharacter(character);
      final guest = service.decodeAsGuest(encoded);

      expect(guest.displayLabel, '炎の戦士');
    });
  });

  group('QrBattleService - ガチャキャラエンコード', () {
    test('ガチャキャラをエンコード→デコードしてゲスト敵を生成できる', () {
      final gachaChar = _makeGachaCharacter(
        name: 'ギャラクシー・ナイト',
        deviceName: 'Galaxy S25',
        rarity: Rarity.sr,
      );
      final encoded = service.encodeGachaCharacter(gachaChar);
      final guest = service.decodeAsGuest(encoded);

      expect(guest.isGacha, true);
      expect(guest.rarity, Rarity.sr);
      expect(guest.deviceName, 'Galaxy S25');
      expect(guest.name, 'ギャラクシー・ナイト');
    });

    test('ガチャキャラのdisplayLabelに[レアリティ]とデバイス名が含まれる', () {
      final gachaChar = _makeGachaCharacter(
        name: 'テスト',
        deviceName: 'iPhone 16',
        rarity: Rarity.ssr,
      );
      final encoded = service.encodeGachaCharacter(gachaChar);
      final guest = service.decodeAsGuest(encoded);

      expect(guest.displayLabel, contains('[SSR]'));
      expect(guest.displayLabel, contains('iPhone 16'));
    });
  });

  group('QrBattleService - ゲスト敵のバトル互換性', () {
    test('battleCharacterがBattleEngineに渡せる形式である', () {
      final character = _makeCharacter(
        element: ElementType.water,
        level: 10,
        atk: 25,
      );
      final encoded = service.encodePlayerCharacter(character);
      final guest = service.decodeAsGuest(encoded);

      final bc = guest.battleCharacter;
      expect(bc.skills, isNotEmpty);
      expect(bc.element, ElementType.water);
      expect(bc.level, 10);
      expect(bc.currentStats.atk, isPositive);
    });
  });

  group('QrBattleService - URL生成・解析', () {
    test('共有URLを生成できる', () {
      final svc = QrBattleService(baseUrl: 'https://example.com');
      final encoded = svc.encodePlayerCharacter(_makeCharacter());
      final url = svc.generateShareUrl(encoded);

      expect(url, startsWith('https://example.com/?battle='));
      expect(url, contains(encoded));
    });

    test('URLから対戦パラメータを抽出できる', () {
      final original = _makeCharacter(name: '抽出テスト');
      final encoded = service.encodePlayerCharacter(original);
      final uri = Uri.parse('https://example.com/?battle=$encoded');

      final extracted = QrBattleService.extractBattleParam(uri);
      expect(extracted, encoded);

      // 抽出データからゲスト敵を復元
      final guest = service.decodeAsGuest(extracted!);
      expect(guest.name, '抽出テスト');
    });

    test('battleパラメータのないURLからはnullが返る', () {
      final uri = Uri.parse('https://example.com/?other=value');
      expect(QrBattleService.extractBattleParam(uri), isNull);
    });
  });

  group('QrBattleService - 改ざん検知', () {
    test('改ざんデータのデコードでIntegrityExceptionがスローされる', () {
      final character = _makeCharacter();
      final encoded = service.encodePlayerCharacter(character);

      // Base64をデコードして改ざん
      final bytes = base64Url.decode(encoded);
      bytes[7] = (bytes[7] + 1) % 256;
      final tampered = base64Url.encode(bytes);

      expect(
        () => service.decodeAsGuest(tampered),
        throwsA(isA<IntegrityException>()),
      );
    });
  });

  group('QrBattleGuest - displayLabel', () {
    test('実機キャラ: キャラ名のみ', () {
      final character = _makeCharacter(name: 'プレイヤーA');
      final encoded = service.encodePlayerCharacter(character);
      final guest = service.decodeAsGuest(encoded);

      expect(guest.displayLabel, 'プレイヤーA');
    });

    test('ガチャキャラ（デバイス名あり）: [レアリティ] デバイス名 — キャラ名', () {
      final gachaChar = _makeGachaCharacter(
        name: 'フレイムナイト',
        deviceName: 'Pixel 9',
        rarity: Rarity.r,
      );
      final encoded = service.encodeGachaCharacter(gachaChar);
      final guest = service.decodeAsGuest(encoded);

      expect(guest.displayLabel, '[R] Pixel 9 — フレイムナイト');
    });

    test('ガチャキャラ（デバイス名なし）: [レアリティ] キャラ名', () {
      final gachaChar = GachaCharacter(
        id: 'test',
        deviceName: '',
        rarity: Rarity.n,
        obtainedAt: DateTime.now(),
        character: _makeCharacter(name: 'ノーデバイス'),
      );
      final encoded = service.encodeGachaCharacter(gachaChar);
      final guest = service.decodeAsGuest(encoded);

      expect(guest.displayLabel, '[N] ノーデバイス');
    });
  });
}
