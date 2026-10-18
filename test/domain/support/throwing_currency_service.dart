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
}
