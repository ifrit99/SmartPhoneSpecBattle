import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/models/avatar_customization.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/experience.dart';
import 'package:spec_battle_game/domain/models/skill.dart';
import 'package:spec_battle_game/domain/models/stats.dart';

/// テスト用のCharacterを生成するヘルパー
Character _makeCharacter() {
  const baseStats = Stats(hp: 100, maxHp: 100, atk: 15, def: 12, spd: 10);
  return Character(
    name: 'テスト・アバター',
    element: ElementType.fire,
    baseStats: baseStats,
    currentStats: baseStats,
    skills: getSkillsForElement(ElementType.fire),
    experience: const Experience(level: 1),
    seed: 123,
    headIndex: 1,
    bodyIndex: 2,
    armIndex: 3,
    legIndex: 4,
    colorPaletteIndex: 5,
    accessoryIndex: 6,
    auraIndex: 2,
  );
}

void main() {
  group('AvatarCustomization - applyTo', () {
    test('全ておまかせなら元のキャラをそのまま返す', () {
      final base = _makeCharacter();
      const customization = AvatarCustomization();

      expect(customization.isEmpty, isTrue);
      expect(identical(customization.applyTo(base), base), isTrue);
    });

    test('設定済みスロットだけ上書きし、おまかせスロットは元の値を維持する', () {
      final base = _makeCharacter();
      const customization = AvatarCustomization(
        headIndex: 7,
        colorPaletteIndex: 11,
        auraIndex: 4,
      );

      final applied = customization.applyTo(base);

      // 上書きされたスロット
      expect(applied.headIndex, 7);
      expect(applied.colorPaletteIndex, 11);
      expect(applied.auraIndex, 4);
      // おまかせのまま維持されるスロット
      expect(applied.bodyIndex, base.bodyIndex);
      expect(applied.armIndex, base.armIndex);
      expect(applied.legIndex, base.legIndex);
      expect(applied.accessoryIndex, base.accessoryIndex);
      // 見た目以外は変わらない
      expect(applied.name, base.name);
      expect(applied.baseStats.atk, base.baseStats.atk);
      expect(applied.seed, base.seed);
    });

    test('全スロット設定なら全て上書きされる', () {
      final base = _makeCharacter();
      const customization = AvatarCustomization(
        headIndex: 0,
        bodyIndex: 0,
        armIndex: 0,
        legIndex: 0,
        colorPaletteIndex: 0,
        accessoryIndex: 0,
        auraIndex: 0,
      );

      final applied = customization.applyTo(base);

      expect(applied.headIndex, 0);
      expect(applied.bodyIndex, 0);
      expect(applied.armIndex, 0);
      expect(applied.legIndex, 0);
      expect(applied.colorPaletteIndex, 0);
      expect(applied.accessoryIndex, 0);
      expect(applied.auraIndex, 0);
    });
  });

  group('AvatarCustomization - customizedCount', () {
    test('全ておまかせなら0', () {
      expect(const AvatarCustomization().customizedCount, 0);
    });

    test('設定済みスロット数を数える（0も設定済みとして扱う）', () {
      const customization = AvatarCustomization(
        headIndex: 0,
        accessoryIndex: 3,
        auraIndex: 1,
      );
      expect(customization.customizedCount, 3);
      expect(customization.isEmpty, isFalse);
    });
  });

  group('AvatarCustomization - 永続化', () {
    test('toStorageString → fromStorageString で往復できる', () {
      const original = AvatarCustomization(
        headIndex: 3,
        bodyIndex: AvatarCustomization.unset,
        armIndex: 2,
        legIndex: AvatarCustomization.unset,
        colorPaletteIndex: 9,
        accessoryIndex: 0,
        auraIndex: 5,
      );

      final restored =
          AvatarCustomization.fromStorageString(original.toStorageString());

      expect(restored.headIndex, 3);
      expect(restored.bodyIndex, AvatarCustomization.unset);
      expect(restored.armIndex, 2);
      expect(restored.legIndex, AvatarCustomization.unset);
      expect(restored.colorPaletteIndex, 9);
      expect(restored.accessoryIndex, 0);
      expect(restored.auraIndex, 5);
    });

    test('null・空文字は全ておまかせとして復元する', () {
      expect(AvatarCustomization.fromStorageString(null).isEmpty, isTrue);
      expect(AvatarCustomization.fromStorageString('').isEmpty, isTrue);
    });

    test('要素数が7でない文字列は全ておまかせとして復元する', () {
      expect(AvatarCustomization.fromStorageString('1,2,3').isEmpty, isTrue);
      expect(
        AvatarCustomization.fromStorageString('1,2,3,4,5,6,7,8').isEmpty,
        isTrue,
      );
    });

    test('数値でない要素はそのスロットだけおまかせ扱いになる', () {
      final restored =
          AvatarCustomization.fromStorageString('1,abc,2,-1,3,4,5');

      expect(restored.headIndex, 1);
      expect(restored.bodyIndex, AvatarCustomization.unset);
      expect(restored.armIndex, 2);
      expect(restored.legIndex, AvatarCustomization.unset);
      expect(restored.colorPaletteIndex, 3);
    });
  });

  group('AvatarCustomization - 組み合わせ総数', () {
    test('4軸の組み合わせが3軸以上の自己表現を担保する', () {
      // 形状（頭×体×腕×脚）× カラー × 装飾 × 演出
      const total = AvatarCustomization.headVariations *
          AvatarCustomization.bodyVariations *
          AvatarCustomization.armVariations *
          AvatarCustomization.legVariations *
          AvatarCustomization.paletteVariations *
          AvatarCustomization.accessoryVariations *
          AvatarCustomization.auraVariations;

      expect(total, 691200);
    });
  });
}
