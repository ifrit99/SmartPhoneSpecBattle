import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/device_info_service.dart';
import '../../data/local_storage_service.dart';
import '../../data/sound_service.dart';
import '../../domain/models/character.dart';
import '../../domain/enums/element_type.dart';
import '../../domain/services/character_generator.dart';
import '../../domain/services/enemy_generator.dart';
import '../../domain/services/experience_service.dart';
import '../../domain/services/currency_service.dart';
import '../../domain/models/player_currency.dart';
import '../widgets/pixel_character.dart';
import '../widgets/stat_bar.dart';
import 'character_screen.dart';
import 'collection_screen.dart';
import 'battle_screen.dart';

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
  late LocalStorageService _storage;
  late ExperienceService _expService;
  late CurrencyService _currencyService;
  final DeviceInfoService _deviceInfo = DeviceInfoService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  StreamSubscription<int>? _batterySubscription;
  int _currentBatteryLevel = 100;

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
    _startBatteryMonitoring();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _batterySubscription?.cancel();
    super.dispose();
  }

  void _startBatteryMonitoring() {
    _batterySubscription = _deviceInfo.batteryLevelStream.listen((level) {
      if (mounted) {
        setState(() {
          _currentBatteryLevel = level;
          if (_playerCharacter != null) {
            _playerCharacter = _playerCharacter!.copyWith(batteryLevel: level);
          }
        });
      }
    });
  }

  Future<void> _initGame() async {
    _storage = LocalStorageService();
    await _storage.init();
    _expService = ExperienceService(_storage);
    _currencyService = CurrencyService(_storage);

    final specs = await _deviceInfo.getDeviceSpecs();

    // 画面サイズは後で設定（BuildContext不要の場合のデフォルト）
    final experience = _expService.loadExperience();
    final currency = _currencyService.load();
    
    // 生成時に最新のバッテリーレベルを反映
    final batterySpecs = specs.withBattery(_currentBatteryLevel);
    final character = CharacterGenerator.generate(batterySpecs, experience: experience);

    setState(() {
      _playerCharacter = character;
      _playerCurrency = currency;
      _loading = false;
    });
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
        elementColor: _getElementColor,
      ),
    ).then((confirmed) {
      if (confirmed == true) {
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
    // SharedPreferencesの最新データを再取得
    await _storage.init();
    final experience = _expService.loadExperience();
    final currency = _currencyService.load();
    
    // バトル後にレベルが上がっている可能性があるため、ジェネレーターから再生成する
    // これによりbaseStatsから正しい現在レベルのcurrentStats（最大HP等も含む）が作られる
    final specs = await _deviceInfo.getDeviceSpecs();
    final batterySpecs = specs.withBattery(_currentBatteryLevel);
    final character = CharacterGenerator.generate(batterySpecs, experience: experience);

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
          // 通貨ヘッダー
          if (_playerCurrency != null) ...[
            _buildCurrencyHeader(_playerCurrency!),
            const SizedBox(height: 16),
          ],
          // ヘッダー（タイトル + バッテリー）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
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
              _buildBatteryIndicator(),
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
                    // TODO: InventoryScreen
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
                    // TODO: GachaScreen
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 図鑑・履歴ボタン
          SizedBox(
            width: double.infinity,
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

  Widget _buildBatteryIndicator() {
    Color batteryColor = Colors.greenAccent;
    IconData batteryIcon = Icons.battery_full;

    if (_currentBatteryLevel <= 20) {
      batteryColor = Colors.redAccent;
      batteryIcon = Icons.battery_alert;
    } else if (_currentBatteryLevel <= 50) {
      batteryColor = Colors.amberAccent;
      batteryIcon = Icons.battery_std;
    }

    // SPD補正値の計算
    final spdBonus = ((_currentBatteryLevel - 50) * 0.002 * 100).round();
    final bonusText = spdBonus >= 0 ? '+$spdBonus%' : '$spdBonus%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Icon(batteryIcon, color: batteryColor, size: 16),
              const SizedBox(width: 4),
              Text(
                '$_currentBatteryLevel%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'SPD $bonusText',
            style: TextStyle(
              color: batteryColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
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
                  size: 80,
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
                ),
                const SizedBox(height: 4),
                Text(
                  '${device.osLabel}  ／  RAM ${device.ramMB ~/ 1024}GB  ／  空き${device.storageFreeGB}GB  ／  🔋${device.batteryLevel}%',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
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
