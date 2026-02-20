import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/models/experience.dart';

void main() {
  group('Experience.addExp', () {
    test('経験値を加算できる', () {
      const exp = Experience(level: 1, currentExp: 0, expToNext: 100);
      final result = exp.addExp(50);

      expect(result.level, 1);
      expect(result.currentExp, 50);
    });

    test('必要経験値に達するとレベルアップする', () {
      const exp = Experience(level: 1, currentExp: 0, expToNext: 100);
      final result = exp.addExp(100);

      expect(result.level, 2);
      expect(result.currentExp, 0);
    });

    test('余剰経験値はそのまま持ち越す', () {
      const exp = Experience(level: 1, currentExp: 0, expToNext: 100);
      final result = exp.addExp(130);

      expect(result.level, 2);
      expect(result.currentExp, 30);
    });

    test('大量の経験値で複数レベルアップできる', () {
      const exp = Experience(level: 1, currentExp: 0, expToNext: 100);
      // Lv1→2: 100, Lv2→3: 150 → 合計250で2レベルアップ
      final result = exp.addExp(250);

      expect(result.level, 3);
    });

    test('レベルアップ後の expToNext は正しく増加する', () {
      const exp = Experience(level: 1, currentExp: 0, expToNext: 100);
      final result = exp.addExp(100); // Lv1→2

      // Lv2の必要経験値: (100 * (1.0 + (2-1)*0.5)).round() = 150
      expect(result.expToNext, 150);
    });
  });

  group('Experience.progressPercentage', () {
    test('進捗割合を正しく計算する', () {
      const exp = Experience(level: 1, currentExp: 50, expToNext: 100);
      expect(exp.progressPercentage, closeTo(0.5, 0.001));
    });

    test('expToNext が 0 のときは 0.0 を返す', () {
      const exp = Experience(level: 1, currentExp: 0, expToNext: 0);
      expect(exp.progressPercentage, 0.0);
    });
  });

  group('Experience.calcBattleExp', () {
    test('勝利時は敗北時より多くの経験値を得る', () {
      final wonExp = Experience.calcBattleExp(won: true, enemyLevel: 1);
      final lostExp = Experience.calcBattleExp(won: false, enemyLevel: 1);
      expect(wonExp, greaterThan(lostExp));
    });

    test('敵レベルが高いほど多くの経験値を得る', () {
      final low = Experience.calcBattleExp(won: true, enemyLevel: 1);
      final high = Experience.calcBattleExp(won: true, enemyLevel: 10);
      expect(high, greaterThan(low));
    });

    test('Lv1 の敵に勝利したときの基本経験値は 50', () {
      final exp = Experience.calcBattleExp(won: true, enemyLevel: 1);
      expect(exp, 50);
    });

    test('Lv1 の敵に敗北したときの基本経験値は 20', () {
      final exp = Experience.calcBattleExp(won: false, enemyLevel: 1);
      expect(exp, 20);
    });
  });
}
