import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';

void main() {
  group('elementMultiplier', () {
    test('有利属性は 1.5 倍を返す', () {
      // 炎→風, 水→炎, 地→光, 風→地, 光→闇, 闇→水
      expect(elementMultiplier(ElementType.fire, ElementType.wind), 1.5);
      expect(elementMultiplier(ElementType.water, ElementType.fire), 1.5);
      expect(elementMultiplier(ElementType.earth, ElementType.light), 1.5);
      expect(elementMultiplier(ElementType.wind, ElementType.earth), 1.5);
      expect(elementMultiplier(ElementType.light, ElementType.dark), 1.5);
      expect(elementMultiplier(ElementType.dark, ElementType.water), 1.5);
    });

    test('不利属性は 0.75 倍を返す', () {
      // 上記の逆が不利
      expect(elementMultiplier(ElementType.wind, ElementType.fire), 0.75);
      expect(elementMultiplier(ElementType.fire, ElementType.water), 0.75);
      expect(elementMultiplier(ElementType.light, ElementType.earth), 0.75);
      expect(elementMultiplier(ElementType.earth, ElementType.wind), 0.75);
      expect(elementMultiplier(ElementType.dark, ElementType.light), 0.75);
      expect(elementMultiplier(ElementType.water, ElementType.dark), 0.75);
    });

    test('中立（同属性）は 1.0 倍を返す', () {
      for (final e in ElementType.values) {
        expect(elementMultiplier(e, e), 1.0, reason: '${e.name} vs ${e.name}');
      }
    });

    test('相性のない組み合わせは 1.0 倍を返す', () {
      // 炎 vs 水の相性は炎→風なので、炎→水は相性なし（炎が不利でもない）
      // 炎→地、炎→光、炎→闇は中立
      expect(elementMultiplier(ElementType.fire, ElementType.earth), 1.0);
      expect(elementMultiplier(ElementType.fire, ElementType.light), 1.0);
      expect(elementMultiplier(ElementType.fire, ElementType.dark), 1.0);
    });
  });

  group('elementFromOsVersion', () {
    test('数字のみのバージョン文字列を正しく変換する', () {
      // "14" -> 14 % 6 = 2 -> ElementType.earth
      expect(elementFromOsVersion('14'), ElementType.earth);
      // "6" -> 6 % 6 = 0 -> ElementType.fire
      expect(elementFromOsVersion('6'), ElementType.fire);
    });

    test('数字以外を含む文字列でも正しく動作する', () {
      // "Android 14" -> "14" -> 14 % 6 = 2 -> ElementType.earth
      expect(elementFromOsVersion('Android 14'), ElementType.earth);
      // "iOS 16.0" -> "160" -> 160 % 6 = 4 -> ElementType.light
      expect(elementFromOsVersion('iOS 16.0'), ElementType.light);
    });

    test('空文字列はデフォルトの fire を返す', () {
      expect(elementFromOsVersion(''), ElementType.fire);
    });
  });
}
