import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';
import 'package:spec_battle_game/domain/services/local_league_service.dart';
import 'package:spec_battle_game/domain/services/player_rank_service.dart';

void main() {
  late LocalStorageService storage;
  late LocalLeagueService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
    final currencyService = CurrencyService(storage);
    service = LocalLeagueService(
      PlayerRankService(storage, currencyService),
      now: () => DateTime(2026, 5, 5),
    );
  });

  test('週IDとプレイヤー順位を含むローカルリーグを返す', () {
    final league = service.loadLeague();

    expect(league.weekId, '2026-05-04');
    expect(league.standings.any((entry) => entry.isPlayer), isTrue);
    expect(league.playerPosition, greaterThan(0));
  });

  test('スコアが上がるとプレイヤー順位も上がる', () async {
    final before = service.loadLeague().playerPosition;

    for (var i = 0; i < 80; i++) {
      await storage.incrementBattleCount();
      await storage.incrementWinCount();
    }
    final after = service.loadLeague();

    expect(after.playerPosition, lessThan(before));
    expect(after.nextRival, isNull);
    expect(after.pointsToNext, 0);
  });
}
