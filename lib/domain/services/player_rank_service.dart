import 'dart:convert';

import '../../data/local_storage_service.dart';
import '../data/gacha_device_catalog.dart';
import '../models/gacha_character.dart';
import 'currency_service.dart';

class PlayerRankDefinition {
  final String id;
  final String title;
  final String description;
  final int minScore;

  const PlayerRankDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.minScore,
  });
}

class PlayerRankSnapshot {
  final int score;
  final int battles;
  final int wins;
  final int discoveredEnemies;
  final int rosterCount;
  final int limitedOwned;
  final int rivalRoadClearedStage;
  final int? bossBestTurns;
  final PlayerRankDefinition current;
  final PlayerRankDefinition? next;
  final List<PlayerRankRewardSnapshot> rewards;

  const PlayerRankSnapshot({
    required this.score,
    required this.battles,
    required this.wins,
    required this.discoveredEnemies,
    required this.rosterCount,
    required this.limitedOwned,
    required this.rivalRoadClearedStage,
    required this.bossBestTurns,
    required this.current,
    required this.next,
    required this.rewards,
  });

  bool get maxRank => next == null;

  int get scoreIntoCurrent => score - current.minScore;

  int get scoreToNext =>
      next == null ? 0 : (next!.minScore - score).clamp(0, next!.minScore);

  double get progressToNext {
    final nextRank = next;
    if (nextRank == null) return 1;
    final span = nextRank.minScore - current.minScore;
    if (span <= 0) return 1;
    return (scoreIntoCurrent / span).clamp(0.0, 1.0);
  }

  int get claimableRewardCount =>
      rewards.where((reward) => reward.claimable).length;
}

class PlayerRankRewardDefinition {
  final String rankId;
  final int coinsReward;
  final int gemsReward;

  const PlayerRankRewardDefinition({
    required this.rankId,
    this.coinsReward = 0,
    this.gemsReward = 0,
  });
}

class PlayerRankRewardSnapshot {
  final PlayerRankRewardDefinition definition;
  final PlayerRankDefinition rank;
  final bool unlocked;
  final bool claimed;

  const PlayerRankRewardSnapshot({
    required this.definition,
    required this.rank,
    required this.unlocked,
    required this.claimed,
  });

  bool get claimable => unlocked && !claimed;
}

class PlayerRankClaimResult {
  final int claimedCount;
  final int coinsAwarded;
  final int gemsAwarded;

  const PlayerRankClaimResult({
    required this.claimedCount,
    required this.coinsAwarded,
    required this.gemsAwarded,
  });
}

class PlayerRankService {
  final LocalStorageService _storage;
  final CurrencyService _currencyService;

  PlayerRankService(this._storage, this._currencyService);

  static const int battleScore = 3;
  static const int winScore = 12;
  static const int discoveredEnemyScore = 18;
  static const int rosterScore = 10;
  static const int limitedOwnedScore = 70;
  static const int rivalRoadStageScore = 85;
  static const int bossRecordBaseScore = 130;
  static const int bossRecordTurnPenalty = 2;
  static const int bossRecordMinScore = 30;

  static const List<PlayerRankDefinition> ranks = [
    PlayerRankDefinition(
      id: 'rookie',
      title: 'ルーキー',
      description: '端末スペックを試し始めた挑戦者',
      minScore: 0,
    ),
    PlayerRankDefinition(
      id: 'hunter',
      title: 'スペックハンター',
      description: '勝利と発見を積み上げる探索者',
      minScore: 120,
    ),
    PlayerRankDefinition(
      id: 'analyst',
      title: 'ベンチマークアナリスト',
      description: '編成と戦績を読み切る実力者',
      minScore: 300,
    ),
    PlayerRankDefinition(
      id: 'master',
      title: 'シリコンマスター',
      description: '高難度と限定端末を制する上級者',
      minScore: 600,
    ),
    PlayerRankDefinition(
      id: 'legend',
      title: 'SPEC LEGEND',
      description: 'ローカル環境で到達できる最高ランク',
      minScore: 1000,
    ),
  ];

  static const List<PlayerRankRewardDefinition> rankRewards = [
    PlayerRankRewardDefinition(
      rankId: 'hunter',
      coinsReward: 300,
      gemsReward: 10,
    ),
    PlayerRankRewardDefinition(
      rankId: 'analyst',
      coinsReward: 600,
      gemsReward: 30,
    ),
    PlayerRankRewardDefinition(
      rankId: 'master',
      coinsReward: 1200,
      gemsReward: 60,
    ),
    PlayerRankRewardDefinition(
      rankId: 'legend',
      coinsReward: 2000,
      gemsReward: 120,
    ),
  ];

  PlayerRankSnapshot loadRank() {
    final battles = _storage.getBattleCount();
    final wins = _storage.getWinCount();
    final discoveredEnemies = _storage.getDefeatedEnemies().length;
    final roster = _storage.getGachaCharacters();
    final limitedOwned = _countLimitedOwned(roster);
    final rivalRoadClearedStage = _storage.getRivalRoadClearedStage();
    final bossBestTurns = _storage.getBossBestTurns();
    final score = calcScore(
      battles: battles,
      wins: wins,
      discoveredEnemies: discoveredEnemies,
      rosterCount: roster.length,
      limitedOwned: limitedOwned,
      rivalRoadClearedStage: rivalRoadClearedStage,
      bossBestTurns: bossBestTurns,
    );
    final current = _currentRank(score);
    return PlayerRankSnapshot(
      score: score,
      battles: battles,
      wins: wins,
      discoveredEnemies: discoveredEnemies,
      rosterCount: roster.length,
      limitedOwned: limitedOwned,
      rivalRoadClearedStage: rivalRoadClearedStage,
      bossBestTurns: bossBestTurns,
      current: current,
      next: _nextRank(current),
      rewards: _buildRewards(score),
    );
  }

  Future<PlayerRankClaimResult?> claimAvailableRewards() async {
    final snapshot = loadRank();
    final claimable = snapshot.rewards
        .where((reward) => reward.claimable)
        .map((reward) => reward.definition)
        .toList();
    if (claimable.isEmpty) return null;

    final coins = claimable.fold<int>(
      0,
      (total, reward) => total + reward.coinsReward,
    );
    final gems = claimable.fold<int>(
      0,
      (total, reward) => total + reward.gemsReward,
    );

    if (coins > 0) await _currencyService.addCoins(coins);
    if (gems > 0) await _currencyService.addGems(gems);

    final claimed = _storage.getClaimedRankRewards().toSet()
      ..addAll(claimable.map((reward) => reward.rankId));
    await _storage.saveClaimedRankRewards(claimed.toList());

    return PlayerRankClaimResult(
      claimedCount: claimable.length,
      coinsAwarded: coins,
      gemsAwarded: gems,
    );
  }

  static int calcScore({
    required int battles,
    required int wins,
    required int discoveredEnemies,
    required int rosterCount,
    required int limitedOwned,
    int rivalRoadClearedStage = 0,
    int? bossBestTurns,
  }) {
    return battles * battleScore +
        wins * winScore +
        discoveredEnemies * discoveredEnemyScore +
        rosterCount * rosterScore +
        limitedOwned * limitedOwnedScore +
        rivalRoadClearedStage * rivalRoadStageScore +
        _bossRecordScore(bossBestTurns);
  }

  static int _bossRecordScore(int? turns) {
    if (turns == null || turns <= 0) return 0;
    return (bossRecordBaseScore - turns * bossRecordTurnPenalty)
        .clamp(bossRecordMinScore, bossRecordBaseScore)
        .toInt();
  }

  PlayerRankDefinition _currentRank(int score) {
    var current = ranks.first;
    for (final rank in ranks) {
      if (score >= rank.minScore) current = rank;
    }
    return current;
  }

  PlayerRankDefinition? _nextRank(PlayerRankDefinition current) {
    final index = ranks.indexWhere((rank) => rank.id == current.id);
    if (index < 0 || index >= ranks.length - 1) return null;
    return ranks[index + 1];
  }

  List<PlayerRankRewardSnapshot> _buildRewards(int score) {
    final claimed = _storage.getClaimedRankRewards().toSet();
    return rankRewards.map((reward) {
      final rank = ranks.firstWhere((rank) => rank.id == reward.rankId);
      return PlayerRankRewardSnapshot(
        definition: reward,
        rank: rank,
        unlocked: score >= rank.minScore,
        claimed: claimed.contains(reward.rankId),
      );
    }).toList();
  }

  int _countLimitedOwned(List<String> rosterJsons) {
    final limitedNames =
        eventLimitedDeviceCatalog.map((device) => device.deviceName).toSet();
    final owned = <String>{};
    for (final raw in rosterJsons) {
      final name = _deviceNameFromJson(raw);
      if (name != null && limitedNames.contains(name)) {
        owned.add(name);
      }
    }
    return owned.length;
  }

  String? _deviceNameFromJson(String raw) {
    try {
      return GachaCharacter.fromJsonString(raw).deviceName;
    } on FormatException {
      return _fallbackDeviceName(raw);
    } on TypeError {
      return _fallbackDeviceName(raw);
    }
  }

  String? _fallbackDeviceName(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        final value = data['deviceName'];
        return value is String && value.isNotEmpty ? value : null;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
