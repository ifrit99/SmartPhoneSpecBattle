import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';
import 'package:spec_battle_game/domain/services/daily_reward_service.dart';

void main() {
  late LocalStorageService storage;
  late CurrencyService currencyService;
  late DailyRewardService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    currencyService = CurrencyService(storage);
    service = DailyRewardService(storage, currencyService);
  });

  group('DailyRewardService - todayString', () {
    test('yyyy-MM-dd形式の日付文字列を返す', () {
      final today = DailyRewardService.todayString();
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(today), isTrue);
    });
  });

  group('DailyRewardService - ログイン報酬', () {
    test('初回はログイン報酬を受取可能', () {
      expect(service.canClaimLoginReward(), isTrue);
    });

    test('ログイン報酬を受け取ると10ジェム加算される', () async {
      final result = await service.claimLoginReward();
      expect(result, isNotNull);
      expect(result!.type, DailyRewardType.login);
      expect(result.gemsAwarded, 10);
      expect(currencyService.load().premiumGems, 10);
    });

    test('同一日の2回目のログイン報酬はnull', () async {
      await service.claimLoginReward();
      final second = await service.claimLoginReward();
      expect(second, isNull);
      // ジェムは1回分のまま
      expect(currencyService.load().premiumGems, 10);
    });

    test('受取後はcanClaimLoginRewardがfalseになる', () async {
      await service.claimLoginReward();
      expect(service.canClaimLoginReward(), isFalse);
    });

    test('異なる日付なら再度受取可能', () async {
      // 昨日の日付をセット
      await storage.setLastLoginRewardDate('2020-01-01');
      expect(service.canClaimLoginReward(), isTrue);
      final result = await service.claimLoginReward();
      expect(result, isNotNull);
    });
  });

  group('DailyRewardService - バトル報酬', () {
    test('初回はバトル報酬を受取可能', () {
      expect(service.canClaimBattleReward(), isTrue);
    });

    test('バトル報酬を受け取ると15ジェム加算される', () async {
      final result = await service.claimBattleReward();
      expect(result, isNotNull);
      expect(result!.type, DailyRewardType.battle);
      expect(result.gemsAwarded, 15);
      expect(currencyService.load().premiumGems, 15);
    });

    test('同一日の2回目のバトル報酬はnull', () async {
      await service.claimBattleReward();
      final second = await service.claimBattleReward();
      expect(second, isNull);
      expect(currencyService.load().premiumGems, 15);
    });

    test('受取後はcanClaimBattleRewardがfalseになる', () async {
      await service.claimBattleReward();
      expect(service.canClaimBattleReward(), isFalse);
    });

    test('異なる日付なら再度受取可能', () async {
      await storage.setLastBattleRewardDate('2020-01-01');
      expect(service.canClaimBattleReward(), isTrue);
      final result = await service.claimBattleReward();
      expect(result, isNotNull);
    });
  });

  group('DailyRewardService - ログインとバトルの複合', () {
    test('両方受け取ると合計25ジェム', () async {
      await service.claimLoginReward();
      await service.claimBattleReward();
      expect(currencyService.load().premiumGems, 25);
    });

    test('ログイン報酬とバトル報酬は独立して管理される', () async {
      await service.claimLoginReward();
      expect(service.canClaimLoginReward(), isFalse);
      expect(service.canClaimBattleReward(), isTrue);

      await service.claimBattleReward();
      expect(service.canClaimBattleReward(), isFalse);
    });
  });

  group('DailyRewardService - CPU対戦のみバトル報酬が付与される', () {
    test('claimBattleRewardを呼ばなければバトル報酬は付与されない（QR対戦想定）', () async {
      // QR対戦ではclaimBattleRewardを呼ばないため、ジェムは加算されない
      expect(currencyService.load().premiumGems, 0);
      // バトル報酬は未消費のまま
      expect(service.canClaimBattleReward(), isTrue);
    });

    test('QR対戦後もCPU対戦でバトル報酬を受取可能', () async {
      // QR対戦ではclaimBattleRewardを呼ばない（isCpuBattle=falseの分岐）
      // → バトル報酬は温存される

      // その後CPU対戦で報酬を受け取る
      final result = await service.claimBattleReward();
      expect(result, isNotNull);
      expect(result!.gemsAwarded, 15);
      expect(currencyService.load().premiumGems, 15);
    });
  });

  group('DailyRewardService - LocalStorage失敗時のフォールバック', () {
    test('日付が保存されていない場合は受取可能と判定される', () {
      // setUp で空のSharedPreferencesなので、日付未保存 → 受取可能
      expect(service.canClaimLoginReward(), isTrue);
      expect(service.canClaimBattleReward(), isTrue);
    });
  });
}
