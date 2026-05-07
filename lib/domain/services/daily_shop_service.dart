import '../../data/local_storage_service.dart';
import '../models/gacha_character.dart';
import '../models/player_currency.dart';
import 'currency_service.dart';
import 'gacha_service.dart';

enum DailyShopRewardKind {
  trainingExp,
  batteryCharge,
  premiumGems,
}

class DailyShopOfferDefinition {
  final String id;
  final String title;
  final String description;
  final int costCoins;
  final int rewardAmount;
  final DailyShopRewardKind rewardKind;
  final bool requiresEquippedCharacter;

  const DailyShopOfferDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.costCoins,
    required this.rewardAmount,
    required this.rewardKind,
    this.requiresEquippedCharacter = false,
  });
}

class DailyShopOfferSnapshot {
  final DailyShopOfferDefinition definition;
  final bool purchased;
  final bool affordable;
  final String? blockedReason;

  const DailyShopOfferSnapshot({
    required this.definition,
    required this.purchased,
    required this.affordable,
    required this.blockedReason,
  });

  bool get canPurchase => !purchased && affordable && blockedReason == null;
}

class DailyShopSnapshot {
  final String date;
  final List<DailyShopOfferSnapshot> offers;

  const DailyShopSnapshot({
    required this.date,
    required this.offers,
  });

  int get purchasableCount => offers.where((offer) => offer.canPurchase).length;
}

class DailyShopPurchaseResult {
  final DailyShopOfferDefinition definition;
  final PlayerCurrency updatedCurrency;
  final GachaCharacter? updatedCharacter;
  final int levelsGained;

  const DailyShopPurchaseResult({
    required this.definition,
    required this.updatedCurrency,
    this.updatedCharacter,
    this.levelsGained = 0,
  });

  String get summary {
    return switch (definition.rewardKind) {
      DailyShopRewardKind.trainingExp =>
        '${updatedCharacter?.deviceName ?? '装備キャラ'} +${definition.rewardAmount} EXP',
      DailyShopRewardKind.batteryCharge =>
        '${updatedCharacter?.deviceName ?? '装備キャラ'} Battery ${updatedCharacter?.character.batteryLevel ?? 100}%',
      DailyShopRewardKind.premiumGems => '+${definition.rewardAmount} Gems',
    };
  }
}

class DailyShopService {
  static const List<DailyShopOfferDefinition> definitions = [
    DailyShopOfferDefinition(
      id: 'training_report',
      title: '戦術レポート',
      description: '装備中キャラにEXPを即時付与',
      costCoins: 240,
      rewardAmount: 120,
      rewardKind: DailyShopRewardKind.trainingExp,
      requiresEquippedCharacter: true,
    ),
    DailyShopOfferDefinition(
      id: 'battery_pack',
      title: '急速充電パック',
      description: '装備中キャラのBatteryを回復',
      costCoins: 120,
      rewardAmount: 40,
      rewardKind: DailyShopRewardKind.batteryCharge,
      requiresEquippedCharacter: true,
    ),
    DailyShopOfferDefinition(
      id: 'gem_cache',
      title: '解析Gemパック',
      description: 'Coinを少量のGemsに交換',
      costCoins: 360,
      rewardAmount: 8,
      rewardKind: DailyShopRewardKind.premiumGems,
    ),
  ];

  final LocalStorageService _storage;
  final CurrencyService _currencyService;
  final GachaService _gachaService;
  final DateTime Function() _now;

  DailyShopService(
    this._storage,
    this._currencyService,
    this._gachaService, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  String get todayString => _formatDate(_now());

  bool get _isToday => _storage.getDailyShopDate() == todayString;

  DailyShopSnapshot loadShop() {
    final purchased =
        _isToday ? _storage.getPurchasedDailyShopOffers().toSet() : <String>{};
    final currency = _currencyService.load();
    final equipped = _gachaService.getEquippedCharacter();

    return DailyShopSnapshot(
      date: todayString,
      offers: definitions.map((definition) {
        return DailyShopOfferSnapshot(
          definition: definition,
          purchased: purchased.contains(definition.id),
          affordable: currency.coins >= definition.costCoins,
          blockedReason: _blockedReason(definition, equipped),
        );
      }).toList(),
    );
  }

  Future<DailyShopPurchaseResult?> purchase(String id) async {
    await _ensureToday();

    final definition = _definitionById(id);
    if (definition == null) return null;

    final shop = loadShop();
    DailyShopOfferSnapshot? offer;
    for (final candidate in shop.offers) {
      if (candidate.definition.id == definition.id) {
        offer = candidate;
        break;
      }
    }
    if (offer == null || !offer.canPurchase) return null;

    final beforeCharacter = _gachaService.getEquippedCharacter();
    final spent = await _currencyService.spendCoins(definition.costCoins);
    if (spent == null) return null;

    var updatedCurrency = spent;
    GachaCharacter? updatedCharacter;
    var levelsGained = 0;

    switch (definition.rewardKind) {
      case DailyShopRewardKind.trainingExp:
        final target = beforeCharacter;
        if (target == null) return null;
        updatedCharacter = target.gainExp(definition.rewardAmount);
        levelsGained =
            updatedCharacter.character.level - target.character.level;
        await _gachaService.updateCharacter(updatedCharacter);
      case DailyShopRewardKind.batteryCharge:
        final target = beforeCharacter;
        if (target == null) return null;
        final nextBattery =
            (target.character.batteryLevel + definition.rewardAmount)
                .clamp(0, 100)
                .toInt();
        updatedCharacter = target.withBattery(nextBattery);
        await _gachaService.updateCharacter(updatedCharacter);
      case DailyShopRewardKind.premiumGems:
        updatedCurrency = await _currencyService.addGems(
          definition.rewardAmount,
        );
    }

    final purchased = _storage.getPurchasedDailyShopOffers().toSet()
      ..add(definition.id);
    await _storage.savePurchasedDailyShopOffers(purchased.toList());

    return DailyShopPurchaseResult(
      definition: definition,
      updatedCurrency: updatedCurrency,
      updatedCharacter: updatedCharacter,
      levelsGained: levelsGained,
    );
  }

  Future<void> _ensureToday() async {
    if (_isToday) return;
    await _storage.setDailyShopDate(todayString);
    await _storage.savePurchasedDailyShopOffers(const []);
  }

  String? _blockedReason(
    DailyShopOfferDefinition definition,
    GachaCharacter? equipped,
  ) {
    if (definition.requiresEquippedCharacter && equipped == null) {
      return '装備キャラが必要';
    }
    if (definition.rewardKind == DailyShopRewardKind.batteryCharge &&
        equipped != null &&
        equipped.character.batteryLevel >= 100) {
      return 'Battery満タン';
    }
    return null;
  }

  DailyShopOfferDefinition? _definitionById(String id) {
    for (final definition in definitions) {
      if (definition.id == id) return definition;
    }
    return null;
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
