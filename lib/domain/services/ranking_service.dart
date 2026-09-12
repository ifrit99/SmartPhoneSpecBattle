import 'local_league_service.dart';
import 'power_rating_service.dart';

/// ランキング一覧の1行。
class RankingEntry {
  final String name;
  final int score;
  final bool isPlayer;

  const RankingEntry({
    required this.name,
    required this.score,
    this.isPlayer = false,
  });

  factory RankingEntry.fromPower(PowerRankingEntry entry) {
    return RankingEntry(
      name: entry.name,
      score: entry.score,
      isPlayer: entry.isPlayer,
    );
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

  Future<void> setOptIn(bool enabled);

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
  Future<void> setOptIn(bool enabled) async {
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
