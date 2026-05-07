import '../../data/local_storage_service.dart';
import 'player_rank_service.dart';
import 'rival_road_service.dart';

class PlayerTitleDefinition {
  final String id;
  final String label;
  final String description;
  final int priority;

  const PlayerTitleDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.priority,
  });
}

class PlayerTitleSnapshot {
  final PlayerTitleDefinition current;
  final List<PlayerTitleDefinition> unlocked;

  const PlayerTitleSnapshot({
    required this.current,
    required this.unlocked,
  });
}

class PlayerTitleService {
  final LocalStorageService _storage;
  final PlayerRankService _rankService;

  PlayerTitleService(this._storage, this._rankService);

  static const rookieTitle = PlayerTitleDefinition(
    id: 'rookie',
    label: 'ルーキー',
    description: '端末スペックを試し始めた挑戦者',
    priority: 0,
  );

  static const firstWinTitle = PlayerTitleDefinition(
    id: 'first_win',
    label: '初勝利者',
    description: 'CPU戦で初勝利した証',
    priority: 10,
  );

  static const hunterTitle = PlayerTitleDefinition(
    id: 'rank_hunter',
    label: 'スペックハンター',
    description: '勝利と発見を積み上げる探索者',
    priority: 20,
  );

  static const analystTitle = PlayerTitleDefinition(
    id: 'rank_analyst',
    label: 'ベンチマークアナリスト',
    description: '編成と戦績を読み切る実力者',
    priority: 30,
  );

  static const masterTitle = PlayerTitleDefinition(
    id: 'rank_master',
    label: 'シリコンマスター',
    description: '高難度と限定端末を制する上級者',
    priority: 40,
  );

  static const roadClearTitle = PlayerTitleDefinition(
    id: 'rival_road_clear',
    label: 'ロード制覇者',
    description: 'ライバルロードを全ステージ突破した証',
    priority: 50,
  );

  static const speedrunnerTitle = PlayerTitleDefinition(
    id: 'rival_road_best',
    label: '最速検証者',
    description: 'ライバルロード全ステージで最短記録を持つ証',
    priority: 60,
  );

  static const legendTitle = PlayerTitleDefinition(
    id: 'rank_legend',
    label: 'SPEC LEGEND',
    description: 'ローカル環境で到達できる最高称号',
    priority: 70,
  );

  PlayerTitleSnapshot loadTitles() {
    final rank = _rankService.loadRank();
    final clearedRoadStages = _storage.getRivalRoadClearedStage();
    final roadBestTurns = _storage.getRivalRoadBestTurns();
    final unlocked = <PlayerTitleDefinition>[rookieTitle];

    if (_storage.getWinCount() > 0) {
      unlocked.add(firstWinTitle);
    }
    if (rank.score >= _rankMinScore('hunter')) {
      unlocked.add(hunterTitle);
    }
    if (rank.score >= _rankMinScore('analyst')) {
      unlocked.add(analystTitle);
    }
    if (rank.score >= _rankMinScore('master')) {
      unlocked.add(masterTitle);
    }
    if (clearedRoadStages >= RivalRoadService.stages.length) {
      unlocked.add(roadClearTitle);
    }
    if (roadBestTurns.length >= RivalRoadService.stages.length) {
      unlocked.add(speedrunnerTitle);
    }
    if (rank.score >= _rankMinScore('legend')) {
      unlocked.add(legendTitle);
    }

    unlocked.sort((a, b) => a.priority.compareTo(b.priority));
    return PlayerTitleSnapshot(
      current: unlocked.last,
      unlocked: unlocked,
    );
  }

  int _rankMinScore(String id) {
    return PlayerRankService.ranks
        .firstWhere((rank) => rank.id == id)
        .minScore;
  }
}
