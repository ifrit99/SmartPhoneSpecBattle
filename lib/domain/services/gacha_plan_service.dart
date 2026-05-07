import '../models/player_currency.dart';
import 'gacha_service.dart';

enum GachaPlanTargetKind {
  eventLimited,
  premiumFeatured,
}

class GachaPlanTarget {
  final GachaPlanTargetKind kind;
  final String title;
  final String deviceName;
  final int costPerPull;
  final int pullsUntilGuarantee;
  final int currentGems;
  final bool nextPullGuaranteed;

  const GachaPlanTarget({
    required this.kind,
    required this.title,
    required this.deviceName,
    required this.costPerPull,
    required this.pullsUntilGuarantee,
    required this.currentGems,
    required this.nextPullGuaranteed,
  });

  int get gemsToGuarantee => costPerPull * pullsUntilGuarantee;

  int get gemsShortage => (gemsToGuarantee - currentGems).clamp(
        0,
        gemsToGuarantee,
      );

  int get affordablePulls => currentGems ~/ costPerPull;

  bool get canReachGuarantee => currentGems >= gemsToGuarantee;

  bool get canPullNow => currentGems >= costPerPull;

  double get guaranteeProgress {
    if (gemsToGuarantee <= 0) return 1.0;
    return (currentGems / gemsToGuarantee).clamp(0.0, 1.0).toDouble();
  }
}

class GachaPlanSnapshot {
  final GachaPlanTarget eventLimited;
  final GachaPlanTarget premiumFeatured;

  const GachaPlanSnapshot({
    required this.eventLimited,
    required this.premiumFeatured,
  });

  GachaPlanTarget get recommendedTarget {
    if (eventLimited.canReachGuarantee && !premiumFeatured.canReachGuarantee) {
      return eventLimited;
    }
    if (premiumFeatured.canReachGuarantee && !eventLimited.canReachGuarantee) {
      return premiumFeatured;
    }
    if (eventLimited.nextPullGuaranteed && eventLimited.canPullNow) {
      return eventLimited;
    }
    if (premiumFeatured.nextPullGuaranteed && premiumFeatured.canPullNow) {
      return premiumFeatured;
    }
    if (eventLimited.gemsShortage <= premiumFeatured.gemsShortage) {
      return eventLimited;
    }
    return premiumFeatured;
  }
}

class GachaPlanService {
  final GachaService _gachaService;

  const GachaPlanService(this._gachaService);

  GachaPlanSnapshot buildPlan(PlayerCurrency currency) {
    final gems = currency.premiumGems;

    return GachaPlanSnapshot(
      eventLimited: GachaPlanTarget(
        kind: GachaPlanTargetKind.eventLimited,
        title: 'イベント限定SSR',
        deviceName: _gachaService.currentEventLimitedSsr.deviceName,
        costPerPull: PlayerCurrency.eventLimitedPullCost,
        pullsUntilGuarantee: _gachaService.eventLimitedPullsUntilGuarantee,
        currentGems: gems,
        nextPullGuaranteed: _gachaService.isNextEventLimitedGuaranteed,
      ),
      premiumFeatured: GachaPlanTarget(
        kind: GachaPlanTargetKind.premiumFeatured,
        title: '日替わりSSR',
        deviceName: _gachaService.todayFeaturedSsr.deviceName,
        costPerPull: PlayerCurrency.premiumPullCost,
        pullsUntilGuarantee: _gachaService.premiumFeaturedPullsUntilGuarantee,
        currentGems: gems,
        nextPullGuaranteed: _gachaService.isNextPremiumFeaturedGuaranteed,
      ),
    );
  }
}
