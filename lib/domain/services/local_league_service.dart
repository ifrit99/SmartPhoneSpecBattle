import 'player_rank_service.dart';

class LocalLeagueEntry {
  final String name;
  final String title;
  final int score;
  final bool isPlayer;

  const LocalLeagueEntry({
    required this.name,
    required this.title,
    required this.score,
    this.isPlayer = false,
  });
}

class LocalLeagueSnapshot {
  final String weekId;
  final List<LocalLeagueEntry> standings;

  const LocalLeagueSnapshot({
    required this.weekId,
    required this.standings,
  });

  int get playerPosition => standings.indexWhere((entry) => entry.isPlayer) + 1;

  LocalLeagueEntry? get nextRival {
    final index = standings.indexWhere((entry) => entry.isPlayer);
    if (index <= 0) return null;
    return standings[index - 1];
  }

  int get pointsToNext {
    final rival = nextRival;
    if (rival == null) return 0;
    final player = standings.firstWhere((entry) => entry.isPlayer);
    return (rival.score - player.score + 1).clamp(0, rival.score + 1);
  }
}

class LocalLeagueService {
  final PlayerRankService _rankService;
  final DateTime Function() _now;

  LocalLeagueService(
    this._rankService, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const List<LocalLeagueEntry> _baseRivals = [
    LocalLeagueEntry(
      name: 'ChronoCore',
      title: 'SPEC LEGEND',
      score: 980,
    ),
    LocalLeagueEntry(
      name: 'Metric Phantom',
      title: 'シリコンマスター',
      score: 680,
    ),
    LocalLeagueEntry(
      name: 'Silicon Crown',
      title: 'ベンチマークアナリスト',
      score: 430,
    ),
    LocalLeagueEntry(
      name: 'Nexia Runner',
      title: 'スペックハンター',
      score: 240,
    ),
    LocalLeagueEntry(
      name: 'Blazemi Scout',
      title: 'スペックハンター',
      score: 130,
    ),
    LocalLeagueEntry(
      name: 'Dart Rookie',
      title: 'ルーキー',
      score: 55,
    ),
  ];

  LocalLeagueSnapshot loadLeague() {
    final rank = _rankService.loadRank();
    final weekId = currentWeekId;
    final rivals = _baseRivals
        .asMap()
        .entries
        .map((entry) => _withWeeklyDrift(entry.value, entry.key, weekId))
        .toList();
    final standings = [
      ...rivals,
      LocalLeagueEntry(
        name: 'YOU',
        title: rank.current.title,
        score: rank.score,
        isPlayer: true,
      ),
    ]..sort((a, b) {
        final scoreCompare = b.score.compareTo(a.score);
        if (scoreCompare != 0) return scoreCompare;
        if (a.isPlayer != b.isPlayer) return a.isPlayer ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return LocalLeagueSnapshot(
      weekId: weekId,
      standings: standings,
    );
  }

  String get currentWeekId {
    final today = _dateOnly(_now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return _formatDate(monday);
  }

  LocalLeagueEntry _withWeeklyDrift(
    LocalLeagueEntry rival,
    int index,
    String weekId,
  ) {
    final seed = weekId.codeUnits.fold<int>(index * 17, (a, b) => a + b);
    final drift = (seed % 51) - 25;
    return LocalLeagueEntry(
      name: rival.name,
      title: rival.title,
      score: (rival.score + drift).clamp(0, 9999),
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
