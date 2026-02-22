import 'package:flutter/material.dart';
import '../../data/local_storage_service.dart';
import '../../domain/services/experience_service.dart';
import '../../domain/services/enemy_generator.dart';
import '../../domain/models/character.dart';

class CollectionScreen extends StatefulWidget {
  final Character? playerCharacter; // プレイヤーの現在情報を渡してもらう

  const CollectionScreen({super.key, this.playerCharacter});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late LocalStorageService _storage;
  bool _loading = true;

  List<String> _defeatedEnemies = [];
  Map<String, int> _battleRecord = {'battles': 0, 'wins': 0};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _storage = LocalStorageService();
    await _storage.init();
    
    final expService = ExperienceService(_storage);

    setState(() {
      _defeatedEnemies = _storage.getDefeatedEnemies();
      _battleRecord = expService.getBattleRecord();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1B2A),
          elevation: 0,
          title: const Text('コレクション', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Color(0xFF6C5CE7),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: '敵キャラ図鑑', icon: Icon(Icons.menu_book)),
              Tab(text: 'プレイヤー履歴', icon: Icon(Icons.person)),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildCompendiumTab(),
                  _buildPlayerHistoryTab(),
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: allDevices.length,
      itemBuilder: (context, index) {
        final device = allDevices[index];
        final isDefeated = _defeatedEnemies.contains(device.deviceName);
        return _buildEnemyCard(device, isDefeated);
      },
    );
  }

  Widget _buildEnemyCard(EnemyDeviceSpec device, bool isDefeated) {
    // 難易度カラー
    final diffColor = switch (device.difficulty) {
      EnemyDifficulty.easy   => Colors.greenAccent,
      EnemyDifficulty.normal => Colors.blueAccent,
      EnemyDifficulty.hard   => Colors.orangeAccent,
      EnemyDifficulty.boss   => Colors.redAccent,
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
              style: TextStyle(color: diffColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          const Icon(Icons.smartphone, size: 48, color: Colors.white70),
          const Spacer(),
          Text(
            device.deviceName,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '${device.osLabel}\nRAM: ${device.ramMB ~/ 1024}GB',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
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
            child: const Text('???', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ),
          const Spacer(),
          ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
            child: const Icon(Icons.smartphone, size: 48, color: Colors.white),
          ),
          const Spacer(),
          const Text('???', style: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPlayerHistoryTab() {
    final battles = _battleRecord['battles'] ?? 0;
    final wins = _battleRecord['wins'] ?? 0;
    final winRate = battles > 0 ? (wins / battles * 100).toStringAsFixed(1) : '0.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('対戦成績', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatBox('トータルバトル数', '$battles', Icons.sports_mma, Colors.blueAccent)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatBox('勝利数', '$wins', Icons.emoji_events, Colors.amber)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatBox('勝率', '$winRate%', Icons.pie_chart, Colors.greenAccent)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatBox('撃破した種類', '${_defeatedEnemies.length}種', Icons.catching_pokemon, Colors.purpleAccent)),
            ],
          ),
          const SizedBox(height: 32),
          if (widget.playerCharacter != null) ...[
            const Text('現在の相棒データ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
                  Text('Level: ${widget.playerCharacter!.level}', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('EXP: ${widget.playerCharacter!.experience.currentExp} / ${widget.playerCharacter!.experience.expToNext}', style: const TextStyle(color: Colors.white70)),
                  // TODO: More stats if needed
                ],
              ),
            ),
          ]
        ],
      ),
    );
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
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}
