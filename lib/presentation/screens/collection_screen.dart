import 'package:flutter/material.dart';
import '../../data/local_storage_service.dart';
import '../../domain/services/service_locator.dart';
import '../../domain/services/enemy_generator.dart';
import '../../domain/models/character.dart';
import '../../domain/services/achievement_service.dart';
import '../../domain/services/player_rank_service.dart';
import '../../domain/services/local_league_service.dart';
import '../../domain/services/player_title_service.dart';

class CollectionScreen extends StatefulWidget {
  final Character? playerCharacter; // プレイヤーの現在情報を渡してもらう
  final int initialTabIndex;

  const CollectionScreen({
    super.key,
    this.playerCharacter,
    this.initialTabIndex = 0,
  });

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _sl = ServiceLocator();

  List<String> _defeatedEnemies = [];
  Map<String, int> _battleRecord = {'battles': 0, 'wins': 0};
  List<BattleHistoryEntry> _battleHistory = [];
  List<AchievementSnapshot> _achievements = [];
  late PlayerRankSnapshot _rankSnapshot;
  late LocalLeagueSnapshot _leagueSnapshot;
  late PlayerTitleSnapshot _titleSnapshot;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _defeatedEnemies = _sl.storage.getDefeatedEnemies();
    _battleRecord = _sl.experienceService.getBattleRecord();
    _battleHistory = _sl.storage.getBattleHistory();
    _achievements = _sl.achievementService.loadAchievements();
    _rankSnapshot = _sl.playerRankService.loadRank();
    _leagueSnapshot = _sl.localLeagueService.loadLeague();
    _titleSnapshot = _sl.playerTitleService.loadTitles();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1B2A),
          elevation: 0,
          title: const Text('コレクション',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Color(0xFF6C5CE7),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: '敵キャラ図鑑', icon: Icon(Icons.menu_book)),
              Tab(text: 'プレイヤー履歴', icon: Icon(Icons.person)),
              Tab(text: '実績', icon: Icon(Icons.workspace_premium)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCompendiumTab(),
            _buildPlayerHistoryTab(),
            _buildAchievementsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompendiumTab() {
    final allDevices = EnemyGenerator.allEnemyDevices;

    // 難易度順にソートするなどの工夫も可能だがそのまま表示
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: allDevices.length,
      itemBuilder: (context, index) {
        final device = allDevices[index];
        final isDefeated = _defeatedEnemies.contains(device.id);
        return _buildEnemyCard(device, isDefeated);
      },
    );
  }

  Widget _buildEnemyCard(EnemyDeviceSpec device, bool isDefeated) {
    // 難易度カラー
    final diffColor = switch (device.difficulty) {
      EnemyDifficulty.easy => Colors.greenAccent,
      EnemyDifficulty.normal => Colors.blueAccent,
      EnemyDifficulty.hard => Colors.orangeAccent,
      EnemyDifficulty.boss => Colors.redAccent,
    };

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefeated ? diffColor.withValues(alpha: 0.5) : Colors.white10,
          width: 2,
        ),
      ),
      child: isDefeated
          ? _buildDiscoveredEnemy(device, diffColor)
          : _buildHiddenEnemy(device),
    );
  }

  Widget _buildDiscoveredEnemy(EnemyDeviceSpec device, Color diffColor) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: diffColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              device.difficulty.label,
              style: TextStyle(
                  color: diffColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          const Icon(Icons.smartphone, size: 48, color: Colors.white70),
          const Spacer(),
          Text(
            device.deviceName,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${device.osLabel}\nRAM: ${device.ramMB ~/ 1024}GB',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHiddenEnemy(EnemyDeviceSpec device) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('???',
                style: TextStyle(color: Colors.white38, fontSize: 10)),
          ),
          const Spacer(),
          ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
            child: const Icon(Icons.smartphone, size: 48, color: Colors.white),
          ),
          const Spacer(),
          const Text('???',
              style: TextStyle(
                  color: Colors.white30,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPlayerHistoryTab() {
    final battles = _battleRecord['battles'] ?? 0;
    final wins = _battleRecord['wins'] ?? 0;
    final bossBestTurns = _sl.storage.getBossBestTurns();
    final winRate =
        battles > 0 ? (wins / battles * 100).toStringAsFixed(1) : '0.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('対戦成績',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildStatBox('トータルバトル数', '$battles', Icons.sports_mma,
                      Colors.blueAccent)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildStatBox(
                      '勝利数', '$wins', Icons.emoji_events, Colors.amber)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildStatBox(
                      '勝率', '$winRate%', Icons.pie_chart, Colors.greenAccent)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildStatBox('撃破した種類', '${_defeatedEnemies.length}種',
                      Icons.catching_pokemon, Colors.purpleAccent)),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatBox(
            'BOSS最短',
            bossBestTurns == null ? '-' : '${bossBestTurns}T',
            Icons.timer,
            Colors.redAccent,
          ),
          const SizedBox(height: 32),
          _buildRankCard(_rankSnapshot),
          const SizedBox(height: 16),
          _buildLeagueCard(_leagueSnapshot),
          const SizedBox(height: 32),
          _buildRecentBattleHistory(),
          const SizedBox(height: 32),
          if (widget.playerCharacter != null) ...[
            const Text('現在の相棒データ',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2838),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Level: ${widget.playerCharacter!.level}',
                      style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                      'EXP: ${widget.playerCharacter!.experience.currentExp} / ${widget.playerCharacter!.experience.expToNext}',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildRecentBattleHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '最近のバトル',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_battleHistory.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2838),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: const Text(
              'まだ記録がありません。CPU戦やフレンド対戦の結果がここに残ります。',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          )
        else
          ..._battleHistory.take(8).map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildBattleHistoryCard(entry),
              )),
      ],
    );
  }

  Widget _buildBattleHistoryCard(BattleHistoryEntry entry) {
    final accent = entry.playerWon ? Colors.amber : Colors.blueGrey;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                entry.playerWon ? Icons.emoji_events : Icons.shield,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${entry.playerWon ? '勝利' : '敗北'} vs ${entry.enemyName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatHistoryDate(entry.happenedAt),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _historyChip(entry.modeLabel),
              _historyChip(entry.difficultyLabel),
              _historyChip('${entry.turnsPlayed}T'),
              _historyChip(entry.tacticLabel),
              _historyChip(entry.supportLabel),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${entry.expGained} EXP / ${entry.rewardSummary}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _historyChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatHistoryDate(String raw) {
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return '';
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.month}/${parsed.day} $hour:$minute';
  }

  Widget _buildRankCard(PlayerRankSnapshot rank) {
    final next = rank.next;
    final accent = rank.maxRank ? const Color(0xFFFFD700) : Colors.cyanAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech, color: accent, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rank.current.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rank.current.description,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '${rank.score} RP',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: rank.progressToNext,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? '最高ランク到達。BOSS自己ベストと限定端末収集を伸ばしましょう。'
                : '次: ${next.title} まで ${rank.scoreToNext} RP',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _titlePanel(_titleSnapshot, accent),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _rankChip('勝利', '${rank.wins}'),
              _rankChip('発見', '${rank.discoveredEnemies}種'),
              _rankChip('ロスター', '${rank.rosterCount}体'),
              _rankChip('限定', '${rank.limitedOwned}体'),
              _rankChip(
                'BOSS最短',
                rank.bossBestTurns == null ? '-' : '${rank.bossBestTurns}T',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildRankRewardPanel(rank),
        ],
      ),
    );
  }

  Widget _buildRankRewardPanel(PlayerRankSnapshot rank) {
    final claimable = rank.claimableRewardCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard,
                  color: Color(0xFFFFD700), size: 17),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'ランク到達報酬',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (claimable > 0)
                SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    onPressed: _claimRankRewards,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text('$claimable件受取'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: rank.rewards.map(_rankRewardChip).toList(),
          ),
        ],
      ),
    );
  }

  Widget _titlePanel(PlayerTitleSnapshot titles, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.badge, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles.current.label,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${titles.current.description} / 解放 ${titles.unlocked.length}件',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankRewardChip(PlayerRankRewardSnapshot reward) {
    final color = reward.claimed
        ? Colors.white30
        : reward.claimable
            ? const Color(0xFFFFD700)
            : Colors.cyanAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            reward.claimed
                ? Icons.check_circle
                : reward.claimable
                    ? Icons.redeem
                    : Icons.lock,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            '${reward.rank.title} ${_rankRewardText(reward.definition)}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _rankRewardText(PlayerRankRewardDefinition definition) {
    final parts = <String>[];
    if (definition.coinsReward > 0) {
      parts.add('+${definition.coinsReward} Coin');
    }
    if (definition.gemsReward > 0) {
      parts.add('+${definition.gemsReward} Gems');
    }
    return parts.join(' / ');
  }

  Future<void> _claimRankRewards() async {
    final result = await _sl.playerRankService.claimAvailableRewards();
    if (!mounted || result == null) return;

    setState(_loadData);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.claimedCount}件: ${_rankClaimSummary(result)} を受け取りました',
        ),
      ),
    );
  }

  String _rankClaimSummary(PlayerRankClaimResult result) {
    final parts = <String>[];
    if (result.coinsAwarded > 0) parts.add('${result.coinsAwarded} Coin');
    if (result.gemsAwarded > 0) parts.add('${result.gemsAwarded} Gems');
    return parts.join(' / ');
  }

  Widget _rankChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLeagueCard(LocalLeagueSnapshot league) {
    final nextRival = league.nextRival;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard, color: Color(0xFFFFD700), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ローカルリーグ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${league.weekId} 週 / ${league.playerPosition}位',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            nextRival == null
                ? '今週のローカルリーグ首位です'
                : '次の相手: ${nextRival.name} まで ${league.pointsToNext} RP',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ..._visibleLeagueRows(league).map(_leagueRow),
        ],
      ),
    );
  }

  List<LocalLeagueEntry> _visibleLeagueRows(LocalLeagueSnapshot league) {
    final top = league.standings.take(4).toList();
    final player = league.standings.firstWhere((entry) => entry.isPlayer);
    if (!top.contains(player)) top.add(player);
    return top;
  }

  Widget _leagueRow(LocalLeagueEntry entry) {
    final color = entry.isPlayer ? Colors.cyanAccent : Colors.white54;
    final index = _leagueSnapshot.standings.indexOf(entry) + 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$index',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.isPlayer ? 'YOU' : entry.name,
              style: TextStyle(
                color: entry.isPlayer ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            entry.title,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Text(
            '${entry.score} RP',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsTab() {
    final claimableCount =
        _achievements.where((achievement) => achievement.claimable).length;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _achievements.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2838),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium,
                    color: Color(0xFFFFD700), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '実績報酬',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        claimableCount > 0
                            ? '$claimableCount件の報酬を受け取れます'
                            : 'バトル・勝利・収集で報酬を解放',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return _achievementCard(_achievements[index - 1]);
      },
    );
  }

  Widget _achievementCard(AchievementSnapshot achievement) {
    final definition = achievement.definition;
    final accent = achievement.claimed
        ? Colors.white24
        : achievement.completed
            ? const Color(0xFFFFD700)
            : Colors.blueAccent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                achievement.claimed
                    ? Icons.check_circle
                    : Icons.workspace_premium,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  definition.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                _rewardText(definition),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            definition.description,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: achievement.progressRatio,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${achievement.progress.clamp(0, definition.target)}/${definition.target}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: achievement.claimable
                  ? () => _claimAchievement(definition.id)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                disabledForegroundColor: Colors.white38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(achievement.claimed
                  ? '受取済'
                  : achievement.completed
                      ? '報酬を受け取る'
                      : '未達成'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _claimAchievement(String id) async {
    final result = await _sl.achievementService.claim(id);
    if (!mounted || result == null) return;
    setState(_loadData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_rewardSummary(result)} を受け取りました')),
    );
  }

  String _rewardText(AchievementDefinition definition) {
    final parts = <String>[];
    if (definition.coinsReward > 0) {
      parts.add('🪙 ${definition.coinsReward}');
    }
    if (definition.gemsReward > 0) {
      parts.add('💎 ${definition.gemsReward}');
    }
    return parts.join(' / ');
  }

  String _rewardSummary(AchievementClaimResult result) {
    final parts = <String>[];
    if (result.coinsAwarded > 0) {
      parts.add('${result.coinsAwarded} Coin');
    }
    if (result.gemsAwarded > 0) {
      parts.add('${result.gemsAwarded} Gems');
    }
    return parts.join(' / ');
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}
