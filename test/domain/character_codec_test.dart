import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/domain/models/skill.dart';
import 'package:spec_battle_game/domain/models/experience.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/enums/rarity.dart';
import 'package:spec_battle_game/domain/services/character_codec.dart';

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

void main() {
  group('CharacterCodec - 実機キャラ', () {
    test('ラウンドトリップ: encode → decode で元データと一致する', () {
      final original = _makeCharacter();
      final encoded = CharacterCodec.encode(original);
      final decoded = CharacterCodec.decode(encoded);

      expect(decoded.isGacha, false);
      expect(decoded.rarity, isNull);
      expect(decoded.deviceName, isNull);

      final c = decoded.character;
      expect(c.name, original.name);
      expect(c.element, original.element);
      expect(c.baseStats.hp, original.baseStats.hp);
      expect(c.baseStats.maxHp, original.baseStats.maxHp);
      expect(c.baseStats.atk, original.baseStats.atk);
      expect(c.baseStats.def, original.baseStats.def);
      expect(c.baseStats.spd, original.baseStats.spd);
      expect(c.level, original.level);
      expect(c.seed, original.seed);
      expect(c.headIndex, original.headIndex);
      expect(c.bodyIndex, original.bodyIndex);
      expect(c.armIndex, original.armIndex);
      expect(c.legIndex, original.legIndex);
      expect(c.colorPaletteIndex, original.colorPaletteIndex);
    });

    test('currentStats がレベル反映済みで復元される', () {
      final original = _makeCharacter(level: 10);
      final encoded = CharacterCodec.encode(original);
      final decoded = CharacterCodec.decode(encoded);

      final expectedStats = decoded.character.baseStats.levelUp(10);
      expect(decoded.character.currentStats.atk, expectedStats.atk);
      expect(decoded.character.currentStats.def, expectedStats.def);
    });

    test('スキルが属性から正しく復元される', () {
      final original = _makeCharacter(element: ElementType.water);
      final encoded = CharacterCodec.encode(original);
      final decoded = CharacterCodec.decode(encoded);

      expect(decoded.character.skills.length, 3);
      expect(decoded.character.skills[0].element, ElementType.water);
    });

    test('battleCharacter がそのまま Character を返す', () {
      final original = _makeCharacter();
      final encoded = CharacterCodec.encode(original);
      final decoded = CharacterCodec.decode(encoded);

      expect(identical(decoded.battleCharacter, decoded.character), true);
    });
  });

  group('CharacterCodec - ガチャキャラ', () {
    test('ラウンドトリップ: rarity と deviceName が復元される', () {
      final original = _makeCharacter(name: 'ギャラクシー・ナイト');
      final encoded = CharacterCodec.encode(
        original,
        rarity: Rarity.sr,
        deviceName: 'Galaxy S25',
      );
      final decoded = CharacterCodec.decode(encoded);

      expect(decoded.isGacha, true);
      expect(decoded.rarity, Rarity.sr);
      expect(decoded.deviceName, 'Galaxy S25');
      expect(decoded.character.name, 'ギャラクシー・ナイト');
    });

    test('全Rarity(4種)のラウンドトリップ', () {
      for (final rarity in Rarity.values) {
        final original = _makeCharacter(name: 'Rarity-${rarity.label}');
        final encoded = CharacterCodec.encode(
          original,
          rarity: rarity,
          deviceName: 'TestDevice',
        );
        final decoded = CharacterCodec.decode(encoded);

        expect(decoded.rarity, rarity, reason: '${rarity.label} の復元に失敗');
      }
    });
  });

  group('CharacterCodec - 全属性', () {
    test('全ElementType(6種)のラウンドトリップ', () {
      for (final element in ElementType.values) {
        final original = _makeCharacter(
          name: 'Element-${element.label}',
          element: element,
        );
        final encoded = CharacterCodec.encode(original);
        final decoded = CharacterCodec.decode(encoded);

        expect(decoded.character.element, element,
            reason: '${element.label} の復元に失敗');
        expect(decoded.character.name, 'Element-${element.label}');
      }
    });
  });

  group('CharacterCodec - UTF-8', () {
    test('日本語キャラ名のエンコード/デコード', () {
      final original = _makeCharacter(name: '炎の勇者・ドラゴンスレイヤー');
      final encoded = CharacterCodec.encode(original);
      final decoded = CharacterCodec.decode(encoded);

      expect(decoded.character.name, '炎の勇者・ドラゴンスレイヤー');
    });

    test('日本語デバイス名のエンコード/デコード', () {
      final original = _makeCharacter(name: '量子戦士');
      final encoded = CharacterCodec.encode(
        original,
        rarity: Rarity.ssr,
        deviceName: 'アクオス ウィッシュ3',
      );
      final decoded = CharacterCodec.decode(encoded);

      expect(decoded.deviceName, 'アクオス ウィッシュ3');
    });

    test('ASCII英数字のみのキャラ名', () {
      final original = _makeCharacter(name: 'Pixel-9-Pro');
      final encoded = CharacterCodec.encode(original);
      final decoded = CharacterCodec.decode(encoded);

      expect(decoded.character.name, 'Pixel-9-Pro');
    });
  });

  group('CharacterCodec - エラーハンドリング', () {
    test('不正なBase64urlでFormatException', () {
      expect(
        () => CharacterCodec.decode('!!!invalid!!!'),
        throwsA(isA<FormatException>()),
      );
    });

    test('データが短すぎる場合にFormatException', () {
      final shortData = base64Url.encode([1, 2, 3]);
      expect(
        () => CharacterCodec.decode(shortData),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('短すぎ'),
        )),
      );
    });

    test('未対応バージョンでFormatException', () {
      // version=99 の不正データを作成
      final bytes = List<int>.filled(25, 0);
      bytes[0] = 99; // 未対応バージョン
      final encoded = base64Url.encode(bytes);

      expect(
        () => CharacterCodec.decode(encoded),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('バージョン'),
        )),
      );
    });

    test('空文字列でFormatException', () {
      expect(
        () => CharacterCodec.decode(''),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CharacterCodec - QR適合性', () {
    test('エンコード結果がURL-safe文字のみで構成される', () {
      final original = _makeCharacter(name: '超長い名前のテストキャラクター');
      final encoded = CharacterCodec.encode(
        original,
        rarity: Rarity.ssr,
        deviceName: 'iPhone 17 Pro Max Ultra',
      );

      // Base64url は +, / を使わず -, _ を使う
      expect(encoded, isNot(contains('+')));
      expect(encoded, isNot(contains('/')));
      // URLに安全な文字のみ
      expect(encoded, matches(RegExp(r'^[A-Za-z0-9_=-]*$')));
    });

    test('一般的なキャラのエンコードサイズが100バイト以下', () {
      final original = _makeCharacter(name: 'テスト・ウォリアー');
      final encoded = CharacterCodec.encode(
        original,
        rarity: Rarity.sr,
        deviceName: 'Galaxy S25',
      );

      // Base64エンコード前のバイナリサイズを確認
      final binarySize = base64Url.decode(encoded).length;
      expect(binarySize, lessThanOrEqualTo(100),
          reason: 'バイナリサイズ: $binarySize bytes');
    });
  });

  group('CharacterCodec - 境界値', () {
    test('レベル1の最小キャラ', () {
      final original = _makeCharacter(
        name: 'A',
        level: 1,
        hp: 1,
        atk: 1,
        def: 1,
        spd: 1,
        seed: 0,
      );
      final encoded = CharacterCodec.encode(original);
      final decoded = CharacterCodec.decode(encoded);

      expect(decoded.character.level, 1);
      expect(decoded.character.baseStats.hp, 1);
    });

    test('高レベル・高ステータスキャラ', () {
      final original = _makeCharacter(
        name: 'MaxStats',
        level: 255,
        hp: 9999,
        atk: 255,
        def: 255,
        spd: 255,
        seed: 0xFFFFFFFF,
      );
      final encoded = CharacterCodec.encode(original);
      final decoded = CharacterCodec.decode(encoded);

      expect(decoded.character.level, 255);
      expect(decoded.character.baseStats.hp, 9999);
      expect(decoded.character.baseStats.atk, 255);
      expect(decoded.character.seed, 0xFFFFFFFF);
    });

    test('deviceNameが空文字のガチャキャラ', () {
      final original = _makeCharacter();
      final encoded = CharacterCodec.encode(
        original,
        rarity: Rarity.n,
        deviceName: '',
      );
      final decoded = CharacterCodec.decode(encoded);

      expect(decoded.isGacha, true);
      expect(decoded.deviceName, '');
    });
  });
}
