import 'package:firebase_core/firebase_core.dart';

import '../../data/local_storage_service.dart';
import '../models/character.dart';
import 'analytics_service.dart';
import 'character_codec.dart';
import 'local_league_service.dart';
import 'power_rating_service.dart';

/// Q4: CharacterGenerator の Lv1 基礎値上限（HP 202 / ATK·DEF·SPD 27）の
/// [PowerRatingService.powerScore] = 252 に +10%。`ceil(252 * 1.1) = 278`。
const int rankingMaxPowerRating = 278;

/// CharacterCodec v3 の実長（典型 ~130）＋余裕。
const int rankingMaxCharacterCodeLength = 256;

/// 既存称号の最長（ベンチマークアナリスト / SPEC LEGEND）＋余裕。
const int rankingMaxTitleLength = 32;

/// 1 セッションあたりの送信上限。
const int rankingSubmitSessionCap = 5;

const int rankingEntryTtlDays = 30;

/// ランキング一覧の1行。
class RankingEntry {
  final String name;
  final int score;
  final bool isPlayer;
  final String title;
  final Character? avatar;

  const RankingEntry({
    required this.name,
    required this.score,
    this.isPlayer = false,
    this.title = '',
    this.avatar,
  });

  factory RankingEntry.fromPower(PowerRankingEntry entry) {
    return RankingEntry(
      name: entry.name,
      score: entry.score,
      isPlayer: entry.isPlayer,
    );
  }

  /// 他プレイヤーの [characterCode] を検証する。失敗しても一覧は落とさない。
  factory RankingEntry.fromBackend(
    RankingBackendEntry entry, {
    required bool isPlayer,
  }) {
    return RankingEntry(
      name: entry.title.isNotEmpty ? entry.title : 'プレイヤー',
      score: entry.powerRating,
      isPlayer: isPlayer,
      title: entry.title,
      avatar: decodeRankingAvatar(entry.characterCode),
    );
  }
}

/// 不正な `characterCode` は null（汎用アバター）。一覧を落とさない。
Character? decodeRankingAvatar(String characterCode) {
  if (characterCode.isEmpty) {
    return null;
  }
  try {
    return CharacterCodec.decode(characterCode).character;
  } catch (_) {
    return null;
  }
}

/// 自分の順位と（任意で）上位一覧。
///
/// サーバー/ローカルの経路は持たない。[isEstimated] だけを UI が参照する。
class RankingSnapshot {
  final List<RankingEntry> entries;
  final int myRank;
  final int participantCount;
  final double myPercentile;
  final String weekId;
  final bool isEstimated;

  const RankingSnapshot({
    required this.entries,
    required this.myRank,
    required this.participantCount,
    required this.myPercentile,
    required this.weekId,
    required this.isEstimated,
  });

  /// ローカル [PowerRating] から推定スナップショットを作る。
  factory RankingSnapshot.estimated(
    PowerRating local, {
    required String weekId,
    bool includeEntries = true,
  }) {
    return RankingSnapshot(
      entries: includeEntries
          ? local.entries.take(50).map(RankingEntry.fromPower).toList()
          : const [],
      myRank: local.rank,
      participantCount: local.populationSize,
      myPercentile: local.topPercent,
      weekId: weekId,
      isEstimated: true,
    );
  }
}

/// 世界ランキングの読み書き。失敗時の推定フォールバックは実装側で完結させる。
abstract class RankingService {
  bool get isOptedIn;

  Future<void> setOptIn(
    bool enabled, {
    PowerRating? local,
    String characterCode = '',
    String title = '',
  });

  /// 順位と参加数のみ（上位一覧なし）。ホーム表示用。
  Future<RankingSnapshot> loadMyStanding(PowerRating local);

  /// 上位 50 件込み。詳細シート用。
  Future<RankingSnapshot> loadLeaderboard(PowerRating local);

  /// 週・PWR・編成コード・称号のいずれかが変わっていれば送信する。
  Future<void> submitIfNeeded({
    required PowerRating local,
    String characterCode = '',
    String title = '',
  });
}

/// Firebase 未設定・テスト用の No-op。常にローカル推定を返す。
class EstimatedRankingService implements RankingService {
  final Future<bool> Function() _ensureInitialized;
  final String Function() _weekIdProvider;
  bool _optedIn = false;

  EstimatedRankingService({
    Future<bool> Function()? ensureInitialized,
    String Function()? weekIdProvider,
  })  : _ensureInitialized = ensureInitialized ?? _skipInitialize,
        _weekIdProvider = weekIdProvider ?? _defaultWeekId;

  static Future<bool> _skipInitialize() async => false;

  static String _defaultWeekId() => LocalLeagueService.weekIdAt(DateTime.now());

  @override
  bool get isOptedIn => _optedIn;

  @override
  Future<void> setOptIn(
    bool enabled, {
    PowerRating? local,
    String characterCode = '',
    String title = '',
  }) async {
    _optedIn = enabled;
    if (enabled) {
      await _ensureInitialized();
    }
  }

  @override
  Future<RankingSnapshot> loadMyStanding(PowerRating local) async {
    await _initializeIfOptedIn();
    return RankingSnapshot.estimated(
      local,
      weekId: _weekIdProvider(),
      includeEntries: false,
    );
  }

  @override
  Future<RankingSnapshot> loadLeaderboard(PowerRating local) async {
    await _initializeIfOptedIn();
    return RankingSnapshot.estimated(
      local,
      weekId: _weekIdProvider(),
    );
  }

  @override
  Future<void> submitIfNeeded({
    required PowerRating local,
    String characterCode = '',
    String title = '',
  }) async {
    await _initializeIfOptedIn();
  }

  Future<void> _initializeIfOptedIn() async {
    if (_optedIn) {
      await _ensureInitialized();
    }
  }
}

/// Firestore 実装が依存する抽象。テストでは Fake を注入する。
abstract class RankingBackend {
  String? get currentUid;

  Future<String> signInAnonymously();

  Future<void> signOut();

  Future<void> submitEntry({
    required String weekId,
    required String uid,
    required int powerRating,
    required String characterCode,
    required String title,
    required DateTime expiresAt,
  });

  Future<List<RankingBackendEntry>> loadTopEntries(String weekId);

  Future<int> countAbove({
    required String weekId,
    required int powerRating,
  });

  Future<int> countAll(String weekId);

  Future<void> deleteAllOwnEntries();
}

class RankingBackendEntry {
  final String uid;
  final int powerRating;
  final String characterCode;
  final String title;

  const RankingBackendEntry({
    required this.uid,
    required this.powerRating,
    required this.characterCode,
    required this.title,
  });
}

/// ネットワーク・権限など想定内の Firebase 失敗。Sentry に送らず推定へ戻す。
bool isExpectedRankingFailure(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
      case 'permission-denied':
      case 'unauthenticated':
      case 'aborted':
      case 'cancelled':
      case 'resource-exhausted':
        return true;
      default:
        return false;
    }
  }
  return false;
}

String rankingPayloadHash({
  required int powerRating,
  required String characterCode,
  required String title,
}) {
  return '$powerRating|$characterCode|$title';
}

/// 参加 ON 時の Firestore 実装。失敗は推定フォールバックで完結させる。
class FirestoreRankingService implements RankingService {
  FirestoreRankingService({
    required RankingBackend backend,
    required LocalStorageService storage,
    required AnalyticsService analytics,
    Future<bool> Function()? ensureInitialized,
    String Function()? weekIdProvider,
    DateTime Function()? clock,
    int maxSubmitsPerSession = rankingSubmitSessionCap,
  })  : _backend = backend,
        _storage = storage,
        _analytics = analytics,
        _ensureInitialized = ensureInitialized ?? _skipInitialize,
        _weekIdProvider = weekIdProvider ?? _defaultWeekId,
        _clock = clock ?? DateTime.now,
        _maxSubmitsPerSession = maxSubmitsPerSession;

  final RankingBackend _backend;
  final LocalStorageService _storage;
  final AnalyticsService _analytics;
  final Future<bool> Function() _ensureInitialized;
  final String Function() _weekIdProvider;
  final DateTime Function() _clock;
  final int _maxSubmitsPerSession;

  int _sessionSubmitCount = 0;
  String? _cachedWeekId;
  int? _cachedPowerRating;
  RankingSnapshot? _cachedLeaderboard;

  static Future<bool> _skipInitialize() async => false;

  static String _defaultWeekId() => LocalLeagueService.weekIdAt(DateTime.now());

  @override
  bool get isOptedIn => _storage.isRankingOptedIn();

  @override
  Future<void> setOptIn(
    bool enabled, {
    PowerRating? local,
    String characterCode = '',
    String title = '',
  }) async {
    if (enabled) {
      await _optIn(
        local: local,
        characterCode: characterCode,
        title: title,
      );
      return;
    }
    await _optOut();
  }

  Future<void> _optIn({
    PowerRating? local,
    required String characterCode,
    required String title,
  }) async {
    final initialized = await _ensureInitialized();
    if (!initialized) {
      return;
    }
    await _backend.signInAnonymously();
    await _storage.setRankingOptedIn(true);
    if (local != null) {
      try {
        await _submit(
          local: local,
          characterCode: characterCode,
          title: title,
          force: true,
        );
      } catch (error) {
        if (!isExpectedRankingFailure(error)) {
          rethrow;
        }
      }
    }
    await _analytics.logEvent('ranking_opt_in', params: {'enabled': true});
  }

  Future<void> _optOut() async {
    if (!isOptedIn) {
      return;
    }
    final initialized = await _ensureInitialized();
    if (!initialized) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Firebase 未初期化のため参加解除できません',
      );
    }
    await _backend.signInAnonymously();
    try {
      await _backend.deleteAllOwnEntries();
    } catch (error) {
      // 削除が途中失敗したらフラグは OFF にしない。
      rethrow;
    }
    await _backend.signOut();
    await _storage.clearRankingSendCache();
    await _storage.setRankingOptedIn(false);
    _clearLeaderboardCache();
    await _analytics.logEvent('ranking_opt_in', params: {'enabled': false});
  }

  @override
  Future<RankingSnapshot> loadMyStanding(PowerRating local) async {
    if (!isOptedIn) {
      return _estimated(local, includeEntries: false);
    }
    try {
      if (!await _prepareSession()) {
        return _estimated(local, includeEntries: false);
      }
      return await _loadStanding(local, includeEntries: false);
    } catch (error) {
      if (isExpectedRankingFailure(error)) {
        return _estimated(local, includeEntries: false);
      }
      rethrow;
    }
  }

  @override
  Future<RankingSnapshot> loadLeaderboard(PowerRating local) async {
    if (!isOptedIn) {
      return _estimated(local);
    }
    final weekId = _weekIdProvider();
    final cached = _cachedLeaderboard;
    if (cached != null &&
        _cachedWeekId == weekId &&
        _cachedPowerRating == local.score) {
      return cached;
    }
    try {
      if (!await _prepareSession()) {
        return _estimated(local);
      }
      final snapshot = await _loadStanding(local, includeEntries: true);
      _cachedWeekId = weekId;
      _cachedPowerRating = local.score;
      _cachedLeaderboard = snapshot;
      return snapshot;
    } catch (error) {
      if (isExpectedRankingFailure(error)) {
        return _estimated(local);
      }
      rethrow;
    }
  }

  @override
  Future<void> submitIfNeeded({
    required PowerRating local,
    String characterCode = '',
    String title = '',
  }) async {
    if (!isOptedIn) {
      return;
    }
    try {
      if (!await _prepareSession()) {
        return;
      }
      await _submit(
        local: local,
        characterCode: characterCode,
        title: title,
        force: false,
      );
    } catch (error) {
      if (isExpectedRankingFailure(error)) {
        return;
      }
      rethrow;
    }
  }

  Future<bool> _prepareSession() async {
    final initialized = await _ensureInitialized();
    if (!initialized) {
      return false;
    }
    await _backend.signInAnonymously();
    return true;
  }

  Future<void> _submit({
    required PowerRating local,
    required String characterCode,
    required String title,
    required bool force,
  }) async {
    final uid = _backend.currentUid;
    if (uid == null) {
      return;
    }
    final weekId = _weekIdProvider();
    final hash = rankingPayloadHash(
      powerRating: local.score,
      characterCode: characterCode,
      title: title,
    );
    final lastWeek = _storage.getRankingLastSentWeekId();
    final lastHash = _storage.getRankingLastSentPayloadHash();
    final weekChanged = lastWeek != weekId;
    final payloadChanged = lastHash != hash;
    if (!force && !weekChanged && !payloadChanged) {
      return;
    }
    if (!force && _sessionSubmitCount >= _maxSubmitsPerSession) {
      return;
    }

    final clippedCode = characterCode.length > rankingMaxCharacterCodeLength
        ? characterCode.substring(0, rankingMaxCharacterCodeLength)
        : characterCode;
    final clippedTitle = title.length > rankingMaxTitleLength
        ? title.substring(0, rankingMaxTitleLength)
        : title;

    await _backend.submitEntry(
      weekId: weekId,
      uid: uid,
      powerRating: local.score,
      characterCode: clippedCode,
      title: clippedTitle,
      expiresAt: _clock().add(const Duration(days: rankingEntryTtlDays)),
    );
    await _storage.setRankingLastSentWeekId(weekId);
    await _storage.setRankingLastSentPayloadHash(hash);
    _sessionSubmitCount++;
    _clearLeaderboardCache();
  }

  Future<RankingSnapshot> _loadStanding(
    PowerRating local, {
    required bool includeEntries,
  }) async {
    final weekId = _weekIdProvider();
    final above = await _backend.countAbove(
      weekId: weekId,
      powerRating: local.score,
    );
    final participantCount = await _backend.countAll(weekId);
    if (participantCount <= 0) {
      return _estimated(local, includeEntries: includeEntries);
    }
    final myRank = above + 1;
    final myPercentile = myRank / participantCount * 100;
    final uid = _backend.currentUid;
    final entries = includeEntries
        ? (await _backend.loadTopEntries(weekId))
            .map(
              (entry) => RankingEntry.fromBackend(
                entry,
                isPlayer: uid != null && entry.uid == uid,
              ),
            )
            .toList()
        : const <RankingEntry>[];
    return RankingSnapshot(
      entries: entries,
      myRank: myRank,
      participantCount: participantCount,
      myPercentile: myPercentile,
      weekId: weekId,
      isEstimated: false,
    );
  }

  RankingSnapshot _estimated(
    PowerRating local, {
    bool includeEntries = true,
  }) {
    return RankingSnapshot.estimated(
      local,
      weekId: _weekIdProvider(),
      includeEntries: includeEntries,
    );
  }

  void _clearLeaderboardCache() {
    _cachedWeekId = null;
    _cachedPowerRating = null;
    _cachedLeaderboard = null;
  }
}
