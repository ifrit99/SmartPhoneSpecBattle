import 'package:spec_battle_game/domain/models/player_currency.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';

class ThrowingCurrencyService extends CurrencyService {
  ThrowingCurrencyService(super.storage);

  @override
  Future<PlayerCurrency> addCoins(int _) {
    throw StateError('currency grant failed');
  }

  @override
  Future<PlayerCurrency> addGems(int _) {
    throw StateError('currency grant failed');
  }

  @override
  Future<PlayerCurrency> addReward({int coins = 0, int gems = 0}) {
    throw StateError('currency grant failed');
  }

  @override
  Future<PlayerCurrency?> exchangeCoinsForGems({
    required int coins,
    required int gems,
  }) {
    throw StateError('currency grant failed');
  }
}
