import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/domain/enums/rarity.dart';
import 'package:spec_battle_game/domain/models/player_currency.dart';
import 'package:spec_battle_game/domain/services/gacha_service.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';
import 'package:spec_battle_game/data/local_storage_service.dart';

void main() {
  group('GachaProbabilityTable', () {
    test('排出確率の合計が100%になる', () {
      final total = GachaProbabilityTable.rates.values.reduce((a, b) => a + b);
      expect(total, 100);
    });

    test('draw が有効な Rarity を返す', () {
      final random = Random(42);
      for (int i = 0; i < 100; i++) {
        final rarity = GachaProbabilityTable.draw(random);
        expect(Rarity.values.contains(rarity), true);
      }
    });

    test('大量試行で排出確率が期待値に近い', () {
      final random = Random(12345);
      final counts = <Rarity, int>{};
      for (final r in Rarity.values) {
        counts[r] = 0;
      }

      const trials = 100000;
      for (int i = 0; i < trials; i++) {
        final rarity = GachaProbabilityTable.draw(random);
        counts[rarity] = counts[rarity]! + 1;
      }

      // 許容誤差は ±2% (大量試行なので十分な精度)
      expect(counts[Rarity.n]! / trials, closeTo(0.60, 0.02));
      expect(counts[Rarity.r]! / trials, closeTo(0.25, 0.02));
      expect(counts[Rarity.sr]! / trials, closeTo(0.10, 0.02));
      expect(counts[Rarity.ssr]! / trials, closeTo(0.05, 0.02));
    });

    test('roll=0 で SSR が出る', () {
      // nextInt(100) が 0 を返すケース -> SSR
      final mockRandom = _FixedRandom(0);
      expect(GachaProbabilityTable.draw(mockRandom), Rarity.ssr);
    });

    test('roll=4 で SSR が出る (境界値)', () {
      final mockRandom = _FixedRandom(4);
      expect(GachaProbabilityTable.draw(mockRandom), Rarity.ssr);
    });

    test('roll=5 で SR が出る', () {
      final mockRandom = _FixedRandom(5);
      expect(GachaProbabilityTable.draw(mockRandom), Rarity.sr);
    });

    test('roll=14 で SR が出る (境界値)', () {
      final mockRandom = _FixedRandom(14);
      expect(GachaProbabilityTable.draw(mockRandom), Rarity.sr);
    });

    test('roll=15 で R が出る', () {
      final mockRandom = _FixedRandom(15);
      expect(GachaProbabilityTable.draw(mockRandom), Rarity.r);
    });

    test('roll=39 で R が出る (境界値)', () {
      final mockRandom = _FixedRandom(39);
      expect(GachaProbabilityTable.draw(mockRandom), Rarity.r);
    });

    test('roll=40 で N が出る', () {
      final mockRandom = _FixedRandom(40);
      expect(GachaProbabilityTable.draw(mockRandom), Rarity.n);
    });

    test('roll=99 で N が出る (境界値)', () {
      final mockRandom = _FixedRandom(99);
      expect(GachaProbabilityTable.draw(mockRandom), Rarity.n);
    });
  });

  group('GachaService', () {
    late LocalStorageService storage;
    late CurrencyService currencyService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.init();
      currencyService = CurrencyService(storage);
    });

    test('単発ガチャ: コイン不足で null を返す', () async {
      // コイン 0 の状態
      final service = GachaService(currencyService, storage);
      final result = await service.pullSingle();
      expect(result, isNull);
    });

    test('単発ガチャ: 100コインで1体取得しコイン消費される', () async {
      await currencyService.addCoins(200);

      final service = GachaService(currencyService, storage, Random(42));
      final result = await service.pullSingle();

      expect(result, isNotNull);
      expect(result!.characters.length, 1);
      expect(result.updatedCurrency.coins, 100); // 200 - 100
      expect(result.characters.first.deviceName, isNotEmpty);
      expect(result.characters.first.id, isNotEmpty);
    });

    test('単発ガチャ: ちょうど100コインで引ける', () async {
      await currencyService.addCoins(100);

      final service = GachaService(currencyService, storage, Random(42));
      final result = await service.pullSingle();

      expect(result, isNotNull);
      expect(result!.updatedCurrency.coins, 0);
    });

    test('単発ガチャ: 99コインでは引けない', () async {
      await currencyService.addCoins(99);

      final service = GachaService(currencyService, storage);
      final result = await service.pullSingle();
      expect(result, isNull);
    });

    test('10連ガチャ: コイン不足で null を返す', () async {
      await currencyService.addCoins(899);

      final service = GachaService(currencyService, storage);
      final result = await service.pullTen();
      expect(result, isNull);
    });

    test('10連ガチャ: 900コインで10体取得', () async {
      await currencyService.addCoins(900);

      final service = GachaService(currencyService, storage, Random(42));
      final result = await service.pullTen();

      expect(result, isNotNull);
      expect(result!.characters.length, 10);
      expect(result.updatedCurrency.coins, 0); // 900 - 900
    });

    test('10連ガチャ: SR以上が最低1枚含まれる', () async {
      // 複数回試行してSR以上保証を検証
      for (int seed = 0; seed < 50; seed++) {
        SharedPreferences.setMockInitialValues({});
        final s = LocalStorageService();
        await s.init();
        final cs = CurrencyService(s);
        await cs.addCoins(900);

        final service = GachaService(cs, s, Random(seed));
        final result = await service.pullTen();

        expect(result, isNotNull);
        final hasSROrAbove = result!.characters.any(
          (c) => c.rarity == Rarity.sr || c.rarity == Rarity.ssr,
        );
        expect(hasSROrAbove, true, reason: 'seed=$seed で SR以上が含まれない');
      }
    });

    test('インベントリに保存される', () async {
      await currencyService.addCoins(200);

      final service = GachaService(currencyService, storage, Random(42));
      await service.pullSingle();
      await service.pullSingle();

      final roster = service.loadRoster();
      expect(roster.length, 2);
    });

    test('findById でキャラクターを検索できる', () async {
      await currencyService.addCoins(100);

      final service = GachaService(currencyService, storage, Random(42));
      final result = await service.pullSingle();
      final id = result!.characters.first.id;

      final found = service.findById(id);
      expect(found, isNotNull);
      expect(found!.deviceName, result.characters.first.deviceName);
    });

    test('findById: 存在しないIDは null', () async {
      final service = GachaService(currencyService, storage);
      expect(service.findById('nonexistent'), isNull);
    });

    test('updateCharacter でキャラクターの経験値を更新できる', () async {
      await currencyService.addCoins(100);

      final service = GachaService(currencyService, storage, Random(42));
      final result = await service.pullSingle();
      final original = result!.characters.first;

      final leveled = original.gainExp(200);
      await service.updateCharacter(leveled);

      final updated = service.findById(original.id);
      expect(updated, isNotNull);
      expect(updated!.character.level, greaterThan(original.character.level));
    });

    test('装備キャラクターの設定と取得', () async {
      await currencyService.addCoins(100);

      final service = GachaService(currencyService, storage, Random(42));
      final result = await service.pullSingle();
      final char = result!.characters.first;

      await service.equipCharacter(char.id);
      final equipped = service.getEquippedCharacter();
      expect(equipped, isNotNull);
      expect(equipped!.id, char.id);
    });

    test('装備解除', () async {
      final service = GachaService(currencyService, storage);
      await service.equipCharacter(null);
      final equipped = service.getEquippedCharacter();
      expect(equipped, isNull);
    });

    test('affordableSinglePulls が正しい値を返す', () async {
      await currencyService.addCoins(350);

      final service = GachaService(currencyService, storage);
      expect(service.affordableSinglePulls(), 3);
    });

    test('canAffordTenPull が正しい値を返す', () async {
      final service = GachaService(currencyService, storage);

      // 0コイン
      expect(service.canAffordTenPull(), false);

      await currencyService.addCoins(900);
      expect(service.canAffordTenPull(), true);
    });

    test('連続ガチャでコインが正しく減少する', () async {
      await currencyService.addCoins(1000);

      final service = GachaService(currencyService, storage, Random(42));

      final r1 = await service.pullSingle();
      expect(r1!.updatedCurrency.coins, 900);

      final r2 = await service.pullTen();
      expect(r2!.updatedCurrency.coins, 0);

      // もう引けない
      final r3 = await service.pullSingle();
      expect(r3, isNull);
    });
  });

  group('GachaResult', () {
    test('hasSR: SR以上が含まれるか判定', () async {
      SharedPreferences.setMockInitialValues({});
      final s = LocalStorageService();
      await s.init();
      final cs = CurrencyService(s);
      await cs.addCoins(900);

      // seed=0 で 10連ガチャを引き、SR以上保証が効くことを確認
      final service = GachaService(cs, s, Random(0));
      final result = await service.pullTen();
      expect(result!.hasSR, true);
    });
  });
}

/// テスト用: nextInt が常に固定値を返す Random
class _FixedRandom implements Random {
  final int _value;
  _FixedRandom(this._value);

  @override
  int nextInt(int max) => _value % max;

  @override
  double nextDouble() => _value / 100.0;

  @override
  bool nextBool() => _value % 2 == 0;
}
