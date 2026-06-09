import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/models/player_currency.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';
import 'package:spec_battle_game/domain/services/gacha_plan_service.dart';
import 'package:spec_battle_game/domain/services/gacha_service.dart';

void main() {
  group('GachaPlanService', () {
    late LocalStorageService storage;
    late GachaPlanService planService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.resetForTest();

      final currencyService = CurrencyService(storage);
      final gachaService = GachaService(
        currencyService,
        storage,
        Random(1),
        null,
        () => DateTime(2026, 5, 5),
      );
      planService = GachaPlanService(gachaService);
    });

    test('所持ジェムから限定/日替わりの天井不足量を計算する', () {
      final plan = planService.buildPlan(
        const PlayerCurrency(premiumGems: 60),
      );

      expect(plan.eventLimited.gemsToGuarantee, 120);
      expect(plan.eventLimited.gemsShortage, 60);
      expect(plan.eventLimited.guaranteeProgress, 0.5);
      expect(plan.premiumFeatured.gemsToGuarantee, 120);
      expect(plan.premiumFeatured.gemsShortage, 60);
      expect(plan.premiumFeatured.guaranteeProgress, 0.5);
    });

    test('限定SSRが次回確定で引ける場合は限定を優先する', () async {
      await storage.setEventLimitedMisses(
        GachaService.eventLimitedPityThreshold - 1,
      );

      final plan = planService.buildPlan(
        const PlayerCurrency(premiumGems: PlayerCurrency.eventLimitedPullCost),
      );

      expect(plan.eventLimited.nextPullGuaranteed, isTrue);
      expect(plan.eventLimited.canReachGuarantee, isTrue);
      expect(plan.recommendedTarget.kind, GachaPlanTargetKind.eventLimited);
    });

    test('日替わりSSRが次回確定で引ける場合は日替わりを優先する', () async {
      await storage.setPremiumFeaturedMisses(
        GachaService.premiumFeaturedPityThreshold - 1,
      );

      final plan = planService.buildPlan(
        const PlayerCurrency(premiumGems: PlayerCurrency.premiumPullCost),
      );

      expect(plan.premiumFeatured.nextPullGuaranteed, isTrue);
      expect(plan.premiumFeatured.canReachGuarantee, isTrue);
      expect(plan.recommendedTarget.kind, GachaPlanTargetKind.premiumFeatured);
    });
  });
}
