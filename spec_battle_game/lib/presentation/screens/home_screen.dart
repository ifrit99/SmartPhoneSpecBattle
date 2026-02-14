import 'package:flutter/material.dart';
import '../../data/device_info_service.dart';
import '../../data/local_storage_service.dart';
import '../../domain/models/character.dart';
import '../../domain/enums/element_type.dart';
import '../../domain/services/character_generator.dart';
import '../../domain/services/experience_service.dart';
import '../widgets/pixel_character.dart';
import '../widgets/stat_bar.dart';
import 'character_screen.dart';
import 'battle_screen.dart';

/// ホーム画面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Character? _playerCharacter;
  bool _loading = true;
  late LocalStorageService _storage;
  late ExperienceService _expService;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initGame();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initGame() async {
    _storage = LocalStorageService();
    await _storage.init();
    _expService = ExperienceService(_storage);

    final deviceInfo = DeviceInfoService();
    final specs = await deviceInfo.getDeviceSpecs();

    // 画面サイズは後で設定（BuildContext不要の場合のデフォルト）
    final experience = _expService.loadExperience();
    final character = CharacterGenerator.generate(specs, experience: experience);

    setState(() {
      _playerCharacter = character;
      _loading = false;
    });
  }

  void _startBattle() {
    final player = _playerCharacter;
    if (player == null) return;

    final enemy = CharacterGenerator.generateOpponent(player.level);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          player: player,
          enemy: enemy,
        ),
      ),
    ).then((_) {
      // バトルから戻ったときにデータをリロード
      _reloadData();
    });
  }

  void _reloadData() {
    final experience = _expService.loadExperience();
    final player = _playerCharacter;
    if (player != null) {
      setState(() {
        _playerCharacter = Character(
          name: player.name,
          element: player.element,
          baseStats: player.baseStats,
          currentStats: player.baseStats.levelUp(experience.level),
          skills: player.skills,
          experience: experience,
          seed: player.seed,
          headIndex: player.headIndex,
          bodyIndex: player.bodyIndex,
          armIndex: player.armIndex,
          legIndex: player.legIndex,
          colorPaletteIndex: player.colorPaletteIndex,
        );
      });
    }
  }

  void _openCharacterDetail() {
    final player = _playerCharacter;
    if (player == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CharacterScreen(character: player),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: _loading ? _buildLoading() : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF6C5CE7)),
          ),
          const SizedBox(height: 16),
          const Text(
            'スペック読み取り中...',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final player = _playerCharacter!;
    final record = _expService.getBattleRecord();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // タイトル
          Text(
            'SPEC BATTLE',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 4,
              shadows: [
                Shadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
          const Text(
            'スペック対戦ゲーム',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white38,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 32),

          // キャラクターカード
          GestureDetector(
            onTap: _openCharacterDetail,
            child: _buildCharacterCard(player),
          ),
          const SizedBox(height: 24),

          // 戦績カード
          _buildRecordCard(record),
          const SizedBox(height: 32),

          // バトル開始ボタン
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: _buildBattleButton(),
              );
            },
          ),
          const SizedBox(height: 16),

          const Text(
            'タップしてキャラクター詳細を見る',
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterCard(Character player) {
    final elemColor = _getElementColor(player.element);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            elemColor.withValues(alpha: 0.2),
            const Color(0xFF1B2838),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: elemColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: elemColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          PixelCharacter(character: player, size: 100),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _elementBadge(player.element),
                    const SizedBox(width: 8),
                    Text(
                      'Lv.${player.level}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                StatBar(
                  label: 'HP',
                  value: 1.0,
                  color: Colors.greenAccent,
                  trailingText:
                      '${player.currentStats.hp}',
                  height: 8,
                ),
                StatBar(
                  label: 'EXP',
                  value: player.experience.progressPercentage,
                  color: const Color(0xFF6C5CE7),
                  trailingText:
                      '${player.experience.currentExp}/${player.experience.expToNext}',
                  height: 8,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white30),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, int> record) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _recordItem('バトル数', '${record['battles']}', Icons.sports_mma),
          Container(width: 1, height: 30, color: Colors.white10),
          _recordItem('勝利数', '${record['wins']}', Icons.emoji_events),
          Container(width: 1, height: 30, color: Colors.white10),
          _recordItem(
            '勝率',
            record['battles']! > 0
                ? '${(record['wins']! / record['battles']! * 100).toStringAsFixed(0)}%'
                : '-',
            Icons.trending_up,
          ),
        ],
      ),
    );
  }

  Widget _recordItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white30, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _buildBattleButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _startBattle,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C5CE7),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor: const Color(0xFF6C5CE7).withValues(alpha: 0.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flash_on, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'バトル開始',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _elementBadge(ElementType element) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getElementColor(element).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getElementColor(element).withValues(alpha: 0.5)),
      ),
      child: Text(
        elementName(element),
        style: TextStyle(
          color: _getElementColor(element),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getElementColor(ElementType element) {
    switch (element) {
      case ElementType.fire:
        return const Color(0xFFFF6B6B);
      case ElementType.water:
        return const Color(0xFF74B9FF);
      case ElementType.earth:
        return const Color(0xFFFDCB6E);
      case ElementType.wind:
        return const Color(0xFF55EFC4);
      case ElementType.light:
        return const Color(0xFFFFF176);
      case ElementType.dark:
        return const Color(0xFFAB47BC);
    }
  }
}
