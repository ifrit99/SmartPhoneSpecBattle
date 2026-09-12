import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/data/firebase_options.dart';
import 'package:spec_battle_game/domain/services/local_league_service.dart';
import 'package:spec_battle_game/domain/services/power_rating_service.dart';
import 'package:spec_battle_game/domain/services/ranking_service.dart';
import 'package:spec_battle_game/domain/services/service_locator.dart';

void main() {
  const local = PowerRating(
    score: 150,
    rank: 5,
    populationSize: 18,
    topPercent: 27.8,
    tier: PowerTier.a,
    entries: [
      PowerRankingEntry(name: 'Forge Phone 9 Pro', score: 220, isPlayer: false),
      PowerRankingEntry(name: 'あなた', score: 150, isPlayer: true),
      PowerRankingEntry(name: 'Stellar J2 Lite', score: 90, isPlayer: false),
    ],
  );

  test('hasConfig が false なら ServiceLocator は EstimatedRankingService を使う',
      () async {
    expect(FirebaseOptionsConfig.hasConfig, isFalse);
    SharedPreferences.setMockInitialValues({});
    await ServiceLocator().resetForTest();
    await ServiceLocator().init();

    expect(ServiceLocator().rankingService, isA<EstimatedRankingService>());
  });

  group('EstimatedRankingService', () {
    late List<bool> initializeCalls;
    late EstimatedRankingService service;

    setUp(() {
      initializeCalls = [];
      service = EstimatedRankingService(
        ensureInitialized: () async {
          initializeCalls.add(true);
          return false;
        },
        weekIdProvider: () => '2026-05-04',
      );
    });

    test('未参加では初期化せず、常に推定スナップショットを返す', () async {
      final standing = await service.loadMyStanding(local);
      final board = await service.loadLeaderboard(local);
      await service.submitIfNeeded(local: local);

      expect(service.isOptedIn, isFalse);
      expect(initializeCalls, isEmpty);
      expect(standing.isEstimated, isTrue);
      expect(standing.entries, isEmpty);
      expect(standing.myRank, 5);
      expect(standing.participantCount, 18);
      expect(standing.myPercentile, 27.8);
      expect(standing.weekId, '2026-05-04');
      expect(board.isEstimated, isTrue);
      expect(board.entries.map((e) => e.name), [
        'Forge Phone 9 Pro',
        'あなた',
        'Stellar J2 Lite',
      ]);
      expect(board.myRank, standing.myRank);
    });

    test('参加 ON で遅延初期化し、OFF では初期化しない', () async {
      await service.setOptIn(true);
      expect(service.isOptedIn, isTrue);
      expect(initializeCalls, hasLength(1));

      await service.loadMyStanding(local);
      expect(initializeCalls, hasLength(2));

      await service.setOptIn(false);
      expect(service.isOptedIn, isFalse);
      await service.loadLeaderboard(local);
      expect(initializeCalls, hasLength(2));
    });

    test('weekId は LocalLeagueService と同じ月曜計算を使う', () {
      final now = DateTime(2026, 5, 5);
      expect(LocalLeagueService.weekIdAt(now), '2026-05-04');
    });
  });
}
