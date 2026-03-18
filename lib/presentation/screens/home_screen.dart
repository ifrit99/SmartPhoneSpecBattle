import 'package:flutter/material.dart';
import '../../data/device_info_service.dart';
import '../../data/sound_service.dart';
import '../../domain/models/character.dart';
import '../../domain/enums/element_type.dart';
import '../theme/app_colors.dart';
import '../../domain/services/character_generator.dart';
import '../../domain/services/enemy_generator.dart';
import '../../domain/services/service_locator.dart';
import '../../domain/models/player_currency.dart';
import '../widgets/pixel_character.dart';
import '../widgets/stat_bar.dart';
import 'character_screen.dart';
import 'collection_screen.dart';
import 'battle_screen.dart';
import 'gacha_screen.dart';
import 'inventory_screen.dart';
import 'qr_menu_screen.dart';

import '../../data/local_storage_service.dart';

/// ホーム画面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Character? _playerCharacter;
  PlayerCurrency? _playerCurrency;
  bool _loading = true;
  bool _isFirstBattle = false;
  final _sl = ServiceLocator();
  final DeviceInfoService _deviceInfo = DeviceInfoService();

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
    final character = await _buildPlayerCharacter();
    final currency = _sl.currencyService.load();
    final firstBattle = !LocalStorageService().isFirstBattleCompleted();

    if (!mounted) return;
    setState(() {
      _playerCharacter = character;
      _playerCurrency = currency;
      _isFirstBattle = firstBattle;
      _loading = false;
    });
  }

  /// 装備中のキャラクターまたは実機スペックからCharacterを構築する
  Future<Character> _buildPlayerCharacter() async {
    final experience = _sl.experienceService.loadExperience();
    final equippedId = _sl.storage.getEquippedGachaCharacterId();

    if (equippedId != null) {
      final equipped = _sl.gachaService.findById(equippedId);
      if (equipped != null) {
        return equipped.character;
      }
    }

    final specs = await _deviceInfo.getDeviceSpecs();
    return CharacterGenerator.generate(specs, experience: experience);
  }

  void _startBattle() {
    final player = _playerCharacter;
    if (player == null) return;

    // バトル開始前に敵プレビューを表示
    _showEnemyPreview(player);
  }

  /// 敵プレビューボトムシートを表示する
  void _showEnemyPreview(Character player) {
    // ランダムに敵を生成してプレビュー表示
    final profile = EnemyGenerator.generateRandom(playerLevel: player.level);

    SoundService().playButton();

    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _EnemyPreviewSheet(
        player: player,
        profile: profile,
        elementColor: elementColor,
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BattleScreen(
              player: player,
              enemy: profile.character,
              enemyDeviceName: profile.deviceSpec.deviceName,
              enemyDifficulty: profile.deviceSpec.difficulty,
            ),
          ),
        ).then((_) => _reloadData());
      }
    });
  }

  /// バトル後にデータを最新状態にリロードする
  Future<void> _reloadData() async {
    final character = await _buildPlayerCharacter();
    final currency = _sl.currencyService.load();

    if (!mounted) return;
    setState(() {
      _playerCharacter = character;
      _playerCurrency = currency;
    });
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
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
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
    final record = _sl.experienceService.getBattleRecord();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 通貨ヘッダー
          if (_playerCurrency != null) ...[
            _buildCurrencyHeader(_playerCurrency!),
            const SizedBox(height: 16),
          ],
          // ヘッダー（タイトル）
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'SPEC BATTLE',
                  style: TextStyle(
                    fontSize: 28,
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
              ),
              const Text(
                'スペック対戦ゲーム',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white38,
                  letterSpacing: 2,
                ),
              ),
            ],
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
          const SizedBox(height: 16),
          
          // アクションボタン領域 (Party, Gacha)
          Row(
            children: [
              Expanded(
                child: _buildMenuButton(
                  icon: Icons.group,
                  label: 'Party',
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const InventoryScreen(),
                      ),
                    ).then((_) => _reloadData());
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMenuButton(
                  icon: Icons.star,
                  label: 'Gacha',
                  color: Colors.orangeAccent,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const GachaScreen(),
                      ),
                    ).then((_) => _reloadData()); // 戻ってきたらコイン・キャラ再取得
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 図鑑・履歴 と QR対戦ボタン
          Row(
            children: [
              Expanded(
                child: _buildMenuButton(
                  icon: Icons.menu_book,
                  label: 'Collection',
                  color: Colors.white70,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CollectionScreen(playerCharacter: player),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMenuButton(
                  icon: Icons.people,
                  label: 'Friend',
                  color: Colors.greenAccent,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const FriendBattleMenuScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 初回限定CTAバナー
          if (_isFirstBattle) ...[
            _buildFirstBattleBanner(),
            const SizedBox(height: 16),
          ],

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

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: color.withValues(alpha: 0.05),
      ),
    );
  }

  Widget _buildCurrencyHeader(PlayerCurrency currency) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // コイン
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Text('🪙 ', style: TextStyle(fontSize: 14)),
              Text(
                '${currency.coins}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // ジェム
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE056FD).withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Text('💎 ', style: TextStyle(fontSize: 14)),
              Text(
                '${currency.premiumGems}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterCard(Character player) {
    final elemColor = elementColor(player.element);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final charSize = (screenWidth * 0.22).clamp(60.0, 120.0);

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
          PixelCharacter(character: player, size: charSize),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.flash_on, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'SPD: ${player.effectiveStats.spd}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
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

  Widget _buildFirstBattleBanner() {
    return GestureDetector(
      onTap: _startBattle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFD700).withValues(alpha: 0.15),
              const Color(0xFFFFA502).withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA502)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'はじめてのバトル！',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'あなたのスマホの実力を試してみよう',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFFFFD700), size: 16),
          ],
        ),
      ),
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
        color: elementColor(element).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: elementColor(element).withValues(alpha: 0.5)),
      ),
      child: Text(
        elementName(element),
        style: TextStyle(
          color: elementColor(element),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

}

// ─────────────────────────────────────────────
// 敵プレビューボトムシート
// ─────────────────────────────────────────────

class _EnemyPreviewSheet extends StatelessWidget {
  final Character player;
  final EnemyProfile profile;
  final Color Function(ElementType) elementColor;

  const _EnemyPreviewSheet({
    required this.player,
    required this.profile,
    required this.elementColor,
  });

  @override
  Widget build(BuildContext context) {
    final enemy = profile.character;
    final device = profile.deviceSpec;
    final enemyColor = elementColor(enemy.element);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final charSize = (screenWidth * 0.18).clamp(50.0, 100.0);

    // 難易度に応じたカラー
    final diffColor = switch (device.difficulty) {
      EnemyDifficulty.easy   => Colors.greenAccent,
      EnemyDifficulty.normal => Colors.blueAccent,
      EnemyDifficulty.hard   => Colors.orangeAccent,
      EnemyDifficulty.boss   => Colors.redAccent,
    };

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1B2838),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ドラッグハンドル
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // タイトル行
          Row(
            children: [
              const Text(
                '挑戦者が現れた！',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // 難易度バッジ
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: diffColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  device.difficulty.label,
                  style: TextStyle(
                    color: diffColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 敵キャラクター情報カード
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  enemyColor.withValues(alpha: 0.15),
                  const Color(0xFF0D1B2A),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: enemyColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                // ピクセルキャラクター（反転表示）
                PixelCharacter(
                  character: enemy,
                  size: charSize,
                  flipHorizontal: true,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enemy.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _elementBadge(enemy.element, enemyColor),
                          const SizedBox(width: 8),
                          Text(
                            'Lv.${enemy.level}',
                            style: const TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // ステータス概要
                      _statRow('HP', enemy.battleStats.hp),
                      _statRow('ATK', enemy.battleStats.atk),
                      _statRow('DEF', enemy.battleStats.def),
                      _statRow('SPD', enemy.battleStats.spd),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 架空デバイス情報
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${device.osLabel}  ／  RAM ${device.ramMB ~/ 1024}GB  ／  空き${device.storageFreeGB}GB',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ボタン行
          Row(
            children: [
              // キャンセルボタン
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'キャンセル',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // バトル開始ボタン
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6,
                    shadowColor: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flash_on, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'バトル！',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _elementBadge(ElementType element, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        elementName(element),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _statRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
