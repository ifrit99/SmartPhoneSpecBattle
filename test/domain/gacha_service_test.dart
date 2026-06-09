import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/domain/enums/rarity.dart';
import 'package:spec_battle_game/domain/models/gacha_character.dart';
import 'package:spec_battle_game/domain/services/daily_mission_service.dart';
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
      await storage.resetForTest();
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
        await s.resetForTest();
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

    test('プレミアム解析: ジェム不足で null を返す', () async {
      await currencyService.addGems(19);

      final service = GachaService(currencyService, storage);
      final result = await service.pullPremium();

      expect(result, isNull);
    });

    test('プレミアム解析: 20ジェムでSR以上を1体取得しジェム消費される', () async {
      await currencyService.addGems(25);

      final service = GachaService(currencyService, storage, Random(42));
      final result = await service.pullPremium();

      expect(result, isNotNull);
      expect(result!.characters.length, 1);
      expect(result.updatedCurrency.premiumGems, 5);
      expect(result.updatedCurrency.coins, 0);
      expect(
        [Rarity.sr, Rarity.ssr],
        contains(result.characters.first.rarity),
      );
      expect(service.loadRoster().length, 1);
    });

    test('プレミアム解析: SSR時は日替わりピックアップを優先排出する', () async {
      await currencyService.addGems(20);
      final service = GachaService(
        currencyService,
        storage,
        _FixedRandom(0),
        null,
        () => DateTime(2026, 5, 5),
      );

      final result = await service.pullPremium();

      expect(result, isNotNull);
      expect(result!.characters.first.rarity, Rarity.ssr);
      expect(
        result.characters.first.deviceName,
        GachaService.featuredSsrDevice(date: DateTime(2026, 5, 5)).deviceName,
      );
    });

    test('プレミアム解析: ピックアップSSRを外すと天井カウントが進む', () async {
      await currencyService.addGems(20);
      final service = GachaService(currencyService, storage, _FixedRandom(1));

      final result = await service.pullPremium();

      expect(result, isNotNull);
      expect(result!.characters.first.rarity, Rarity.sr);
      expect(storage.getPremiumFeaturedMisses(), 1);
      expect(service.premiumFeaturedPullsUntilGuarantee, 5);
      expect(service.isNextPremiumFeaturedGuaranteed, isFalse);
    });

    test('プレミアム解析: ピックアップSSRを引くと天井カウントをリセットする', () async {
      await storage.setPremiumFeaturedMisses(4);
      await currencyService.addGems(20);
      final service = GachaService(
        currencyService,
        storage,
        _FixedRandom(0),
        null,
        () => DateTime(2026, 5, 5),
      );

      final result = await service.pullPremium();

      expect(result, isNotNull);
      expect(
        result!.characters.first.deviceName,
        GachaService.featuredSsrDevice(date: DateTime(2026, 5, 5)).deviceName,
      );
      expect(storage.getPremiumFeaturedMisses(), 0);
      expect(service.isNextPremiumFeaturedGuaranteed, isFalse);
    });

    test('プレミアム解析: 5回外すと次回はピックアップSSR確定', () async {
      await currencyService.addGems(120);
      final service = GachaService(
        currencyService,
        storage,
        _FixedRandom(1),
        null,
        () => DateTime(2026, 5, 5),
      );

      for (var i = 0; i < GachaService.premiumFeaturedPityThreshold - 1; i++) {
        final miss = await service.pullPremium();
        expect(miss, isNotNull);
        expect(miss!.characters.first.rarity, Rarity.sr);
      }

      expect(storage.getPremiumFeaturedMisses(), 5);
      expect(service.isNextPremiumFeaturedGuaranteed, isTrue);
      expect(service.premiumFeaturedPullsUntilGuarantee, 1);

      final guaranteed = await service.pullPremium();

      expect(guaranteed, isNotNull);
      expect(guaranteed!.characters.first.rarity, Rarity.ssr);
      expect(
        guaranteed.characters.first.deviceName,
        GachaService.featuredSsrDevice(date: DateTime(2026, 5, 5)).deviceName,
      );
      expect(storage.getPremiumFeaturedMisses(), 0);
    });

    test('日替わりピックアップSSRは日付で決定される', () {
      final today = GachaService.featuredSsrDevice(
        date: DateTime(2026, 5, 5),
      );
      final sameDay = GachaService.featuredSsrDevice(
        date: DateTime(2026, 5, 5, 23, 59),
      );
      final nextDay = GachaService.featuredSsrDevice(
        date: DateTime(2026, 5, 6),
      );

      expect(sameDay.deviceName, today.deviceName);
      expect(nextDay.deviceName, isNot(today.deviceName));
      expect(today.rarity, Rarity.ssr);
      expect(nextDay.rarity, Rarity.ssr);
    });

    test('イベント限定SSRは週替わりで決定される', () {
      final thisWeek = GachaService.eventLimitedSsrDevice(
        date: DateTime(2026, 5, 5),
      );
      final sameWeek = GachaService.eventLimitedSsrDevice(
        date: DateTime(2026, 5, 6),
      );
      final nextWeek = GachaService.eventLimitedSsrDevice(
        date: DateTime(2026, 5, 12),
      );

      expect(sameWeek.deviceName, thisWeek.deviceName);
      expect(nextWeek.deviceName, isNot(thisWeek.deviceName));
      expect(thisWeek.rarity, Rarity.ssr);
    });

    test('イベント解析: 30ジェムでSR以上を1体取得しジェム消費される', () async {
      await currencyService.addGems(35);

      final service = GachaService(currencyService, storage, _FixedRandom(2));
      final result = await service.pullEventLimited();

      expect(result, isNotNull);
      expect(result!.characters.length, 1);
      expect(result.updatedCurrency.premiumGems, 5);
      expect([Rarity.sr, Rarity.ssr], contains(result.characters.first.rarity));
      expect(storage.getEventLimitedMisses(), 1);
    });

    test('イベント解析: 限定SSRを引くと天井カウントをリセットする', () async {
      await storage.setEventLimitedMisses(2);
      await currencyService.addGems(30);
      final service = GachaService(
        currencyService,
        storage,
        _FixedRandom(0),
        null,
        () => DateTime(2026, 5, 5),
      );

      final result = await service.pullEventLimited();

      expect(result, isNotNull);
      expect(result!.characters.first.rarity, Rarity.ssr);
      expect(
        result.characters.first.deviceName,
        GachaService.eventLimitedSsrDevice(date: DateTime(2026, 5, 5))
            .deviceName,
      );
      expect(storage.getEventLimitedMisses(), 0);
    });

    test('イベント解析: 3回外すと次回は限定SSR確定', () async {
      await currencyService.addGems(120);
      final service = GachaService(
        currencyService,
        storage,
        _FixedRandom(2),
        null,
        () => DateTime(2026, 5, 5),
      );

      for (var i = 0; i < GachaService.eventLimitedPityThreshold - 1; i++) {
        final miss = await service.pullEventLimited();
        expect(miss, isNotNull);
        expect(miss!.characters.first.rarity, Rarity.sr);
      }

      expect(storage.getEventLimitedMisses(), 3);
      expect(service.isNextEventLimitedGuaranteed, isTrue);
      expect(service.eventLimitedPullsUntilGuarantee, 1);

      final guaranteed = await service.pullEventLimited();

      expect(guaranteed, isNotNull);
      expect(guaranteed!.characters.first.rarity, Rarity.ssr);
      expect(
        guaranteed.characters.first.deviceName,
        GachaService.eventLimitedSsrDevice(date: DateTime(2026, 5, 5))
            .deviceName,
      );
      expect(storage.getEventLimitedMisses(), 0);
    });

    test('インベントリに保存される', () async {
      await currencyService.addCoins(200);

      final service = GachaService(currencyService, storage, Random(42));
      await service.pullSingle();
      await service.pullSingle();

      final roster = service.loadRoster();
      expect(roster.length, 2);
    });

    test('同一端末の重複は新規枠ではなく覚醒に変換される', () async {
      await currencyService.addCoins(200);

      final service = GachaService(currencyService, storage, _FixedRandom(40));
      final first = await service.pullSingle();
      final second = await service.pullSingle();

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first!.duplicateUpgrades, 0);
      expect(second!.duplicateUpgrades, 1);
      expect(second.characters.first.awakeningLevel, 1);

      final roster = service.loadRoster();
      expect(roster.length, 1);
      expect(roster.first.id, first.characters.first.id);
      expect(roster.first.awakeningLevel, 1);
    });

    test('重複覚醒は最大レベルで止まる', () async {
      await currencyService.addCoins(700);

      final service = GachaService(currencyService, storage, _FixedRandom(40));
      GachaResult? result;
      for (var i = 0; i < 7; i++) {
        result = await service.pullSingle();
      }

      expect(result, isNotNull);
      expect(result!.duplicateUpgrades, 0);
      expect(result.duplicateRefundCoins,
          GachaService.duplicateRefundCoinsFor(Rarity.n));
      expect(result.updatedCurrency.coins,
          GachaService.duplicateRefundCoinsFor(Rarity.n));

      final roster = service.loadRoster();
      expect(roster.length, 1);
      expect(roster.first.awakeningLevel, GachaCharacter.maxAwakeningLevel);
    });

    test('覚醒上限後の重複はレアリティ別のコイン補填に変換される', () async {
      expect(GachaService.duplicateRefundCoinsFor(Rarity.n), 25);
      expect(GachaService.duplicateRefundCoinsFor(Rarity.r), 45);
      expect(GachaService.duplicateRefundCoinsFor(Rarity.sr), 100);
      expect(GachaService.duplicateRefundCoinsFor(Rarity.ssr), 180);
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

    test('ガチャ成功時にデイリーミッションのガチャ回数を記録する', () async {
      await currencyService.addCoins(1000);
      final dailyMissionService = DailyMissionService(
        storage,
        currencyService,
        now: () => DateTime(2026, 5, 5),
      );
      final service = GachaService(
        currencyService,
        storage,
        dailyMissionService,
        _FixedRandom(40),
      );

      await service.pullSingle();
      expect(storage.getDailyMissionGachaPulls(), 1);

      await service.pullTen();
      expect(storage.getDailyMissionGachaPulls(), 11);
    });
  });

  group('GachaResult', () {
    test('hasSR: SR以上が含まれるか判定', () async {
      SharedPreferences.setMockInitialValues({});
      final s = LocalStorageService();
      await s.resetForTest();
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
