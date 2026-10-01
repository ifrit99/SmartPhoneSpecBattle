import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/data/firebase_options.dart';
import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/domain/services/analytics_service.dart';
import 'package:spec_battle_game/domain/services/character_codec.dart';
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

  test('MAX_PWR は CharacterGenerator Lv1 素体上限 +10%', () {
    expect(rankingMaxPowerRating, 278);
  });

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

  group('FirestoreRankingService', () {
    late LocalStorageService storage;
    late _FakeRankingBackend backend;
    late _RecordingAnalytics analytics;
    late String weekId;
    late FirestoreRankingService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.resetForTest();
      backend = _FakeRankingBackend();
      analytics = _RecordingAnalytics();
      weekId = '2026-05-04';
      service = FirestoreRankingService(
        backend: backend,
        storage: storage,
        analytics: analytics,
        ensureInitialized: () async => true,
        weekIdProvider: () => weekId,
      );
    });

    test('送信デバウンス: 同一ペイロードは再送しない', () async {
      await service.setOptIn(true, local: local, characterCode: 'c1', title: 't1');
      await service.submitIfNeeded(
        local: local,
        characterCode: 'c1',
        title: 't1',
      );

      expect(backend.submitCount, 1);
      expect(
        backend.lastExpiresAt!.difference(DateTime.now()).inDays,
        inInclusiveRange(29, 30),
      );
    });

    test('週替わり時は PWR 不変でも再送する', () async {
      await service.setOptIn(true, local: local, characterCode: 'c1', title: 't1');
      expect(backend.submitCount, 1);

      weekId = '2026-05-11';
      await service.submitIfNeeded(
        local: local,
        characterCode: 'c1',
        title: 't1',
      );

      expect(backend.submitCount, 2);
      expect(backend.submittedWeekIds, ['2026-05-04', '2026-05-11']);
    });

    test('オフライン時は推定フォールバックする', () async {
      await service.setOptIn(true, local: local);
      backend.readError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      final standing = await service.loadMyStanding(local);
      final board = await service.loadLeaderboard(local);

      expect(standing.isEstimated, isTrue);
      expect(board.isEstimated, isTrue);
      expect(standing.myRank, local.rank);
    });

    test('参加51人以上でも順位と上位%の分母は N', () async {
      await service.setOptIn(true, local: local);
      backend.seedWeek(weekId, [
        for (var i = 0; i < 50; i++)
          RankingBackendEntry(
            uid: 'other_$i',
            powerRating: 400 - i,
            characterCode: '',
            title: '他$i',
          ),
        const RankingBackendEntry(
          uid: 'fake-uid',
          powerRating: 150,
          characterCode: '',
          title: 'あなた',
        ),
      ]);

      final standing = await service.loadMyStanding(local);

      expect(backend.topLoadCount, 0);
      expect(backend.countAboveCount, 1);
      expect(backend.countAllCount, 1);
      expect(standing.isEstimated, isFalse);
      expect(standing.participantCount, 51);
      expect(standing.myRank, 51);
      expect(standing.myPercentile, 100);
      expect(standing.entries, isEmpty);
    });

    test('OFF で全週 entry を削除し推定へ戻す', () async {
      await service.setOptIn(true, local: local, title: 'ルーキー');
      backend.seedWeek('2026-04-27', const [
        RankingBackendEntry(
          uid: 'fake-uid',
          powerRating: 140,
          characterCode: '',
          title: 'ルーキー',
        ),
      ]);

      await service.setOptIn(false);
      final standing = await service.loadMyStanding(local);

      expect(service.isOptedIn, isFalse);
      expect(backend.ownEntryCount, 0);
      expect(backend.signedIn, isFalse);
      expect(storage.getRankingLastSentWeekId(), isNull);
      expect(standing.isEstimated, isTrue);
      expect(analytics.enabledFlags, [true, false]);
    });

    test('削除が途中失敗したら opt-in は OFF にしない', () async {
      await service.setOptIn(true, local: local);
      backend.seedWeek('2026-04-27', const [
        RankingBackendEntry(
          uid: 'fake-uid',
          powerRating: 140,
          characterCode: '',
          title: 'ルーキー',
        ),
      ]);
      backend.failDeleteMidway = true;

      await expectLater(service.setOptIn(false), throwsA(isA<FirebaseException>()));

      expect(service.isOptedIn, isTrue);
      expect(backend.ownEntryCount, greaterThan(0));
      expect(analytics.enabledFlags, [true]);
    });

    test('weekId は LocalLeagueService と一致する', () async {
      final monday = LocalLeagueService.weekIdAt(DateTime(2026, 5, 5));
      weekId = monday;
      await service.setOptIn(true, local: local);
      backend.seedWeek(monday, [
        RankingBackendEntry(
          uid: backend.uid,
          powerRating: local.score,
          characterCode: '',
          title: 'ルーキー',
        ),
      ]);

      final standing = await service.loadMyStanding(local);

      expect(monday, '2026-05-04');
      expect(standing.weekId, monday);
      expect(standing.isEstimated, isFalse);
    });

    test('不正 characterCode でも一覧を落とさずアバターは null', () async {
      await service.setOptIn(true, local: local);
      final validCode = CharacterCodec.encode(_sampleCharacter());
      backend.seedWeek(weekId, [
        RankingBackendEntry(
          uid: 'other',
          powerRating: 220,
          characterCode: '%%%not-a-code%%%',
          title: '壊れた行',
        ),
        RankingBackendEntry(
          uid: backend.uid,
          powerRating: local.score,
          characterCode: validCode,
          title: 'あなた',
        ),
      ]);

      final board = await service.loadLeaderboard(local);

      expect(board.isEstimated, isFalse);
      expect(board.entries, hasLength(2));
      expect(board.entries.first.avatar, isNull);
      expect(board.entries.last.avatar, isNotNull);
      expect(decodeRankingAvatar('%%%not-a-code%%%'), isNull);
    });

    test('1セッションの送信上限でデバウンスする', () async {
      service = FirestoreRankingService(
        backend: backend,
        storage: storage,
        analytics: analytics,
        ensureInitialized: () async => true,
        weekIdProvider: () => weekId,
        maxSubmitsPerSession: 2,
      );
      await service.setOptIn(true, local: local, title: 'a');
      await service.submitIfNeeded(local: local, title: 'b');
      await service.submitIfNeeded(local: local, title: 'c');

      expect(backend.submitCount, 2);
    });

    test('想定外の例外は伝播する', () async {
      await service.setOptIn(true, local: local);
      backend.readError = StateError('unexpected');

      await expectLater(service.loadMyStanding(local), throwsStateError);
    });
  });
}

class _RecordingAnalytics extends NoopAnalyticsService {
  final enabledFlags = <bool>[];

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> params = const {},
  }) async {
    if (name == 'ranking_opt_in') {
      enabledFlags.add(params['enabled'] == true);
    }
  }
}

class _FakeRankingBackend implements RankingBackend {
  String uid = 'fake-uid';
  bool signedIn = false;
  bool failDeleteMidway = false;
  Object? readError;
  int submitCount = 0;
  int topLoadCount = 0;
  int countAboveCount = 0;
  int countAllCount = 0;
  DateTime? lastExpiresAt;
  final submittedWeekIds = <String>[];
  final weeks = <String, Map<String, RankingBackendEntry>>{};

  @override
  String? get currentUid => signedIn ? uid : null;

  @override
  Future<String> signInAnonymously() async {
    signedIn = true;
    return uid;
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
  }

  @override
  Future<void> submitEntry({
    required String weekId,
    required String uid,
    required int powerRating,
    required String characterCode,
    required String title,
    required DateTime expiresAt,
  }) async {
    submitCount++;
    submittedWeekIds.add(weekId);
    lastExpiresAt = expiresAt;
    weeks.putIfAbsent(weekId, () => {});
    weeks[weekId]![uid] = RankingBackendEntry(
      uid: uid,
      powerRating: powerRating,
      characterCode: characterCode,
      title: title,
    );
  }

  @override
  Future<List<RankingBackendEntry>> loadTopEntries(String weekId) async {
    _throwIfReadError();
    topLoadCount++;
    final entries = weeks[weekId]?.values.toList() ?? [];
    entries.sort((a, b) => b.powerRating.compareTo(a.powerRating));
    return entries.take(50).toList();
  }

  @override
  Future<int> countAbove({
    required String weekId,
    required int powerRating,
  }) async {
    _throwIfReadError();
    countAboveCount++;
    return weeks[weekId]
            ?.values
            .where((entry) => entry.powerRating > powerRating)
            .length ??
        0;
  }

  @override
  Future<int> countAll(String weekId) async {
    _throwIfReadError();
    countAllCount++;
    return weeks[weekId]?.length ?? 0;
  }

  @override
  Future<void> deleteAllOwnEntries() async {
    final ownWeeks = weeks.entries
        .where((entry) => entry.value.containsKey(uid))
        .map((entry) => entry.key)
        .toList();
    for (var i = 0; i < ownWeeks.length; i++) {
      if (failDeleteMidway && i > 0) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );
      }
      weeks[ownWeeks[i]]!.remove(uid);
    }
  }

  void seedWeek(String weekId, List<RankingBackendEntry> entries) {
    weeks[weekId] = {for (final entry in entries) entry.uid: entry};
  }

  int get ownEntryCount {
    return weeks.values
        .expand((entries) => entries.values)
        .where((entry) => entry.uid == uid)
        .length;
  }

  void _throwIfReadError() {
    final error = readError;
    if (error != null) {
      throw error;
    }
  }
}

Character _sampleCharacter() {
  const stats = Stats(hp: 100, maxHp: 100, atk: 10, def: 10, spd: 10);
  return Character(
    name: 'テスト',
    element: ElementType.fire,
    baseStats: stats,
    currentStats: stats,
    skills: const [],
  );
}
