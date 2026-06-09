import 'package:flutter/material.dart';
import '../../data/device_info_service.dart';
import '../../data/sound_service.dart';
import '../../domain/models/character.dart';
import '../../domain/enums/element_type.dart';
import '../../domain/enums/battle_tactic.dart';
import '../theme/app_colors.dart';
import '../../domain/services/character_generator.dart';
import '../../domain/services/currency_service.dart';
import '../../domain/services/daily_mission_service.dart';
import '../../domain/services/daily_shop_service.dart';
import '../../domain/services/enemy_generator.dart';
import '../../domain/services/gacha_plan_service.dart';
import '../../domain/services/limited_event_service.dart';
import '../../domain/services/season_pass_service.dart';
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
import 'data_backup_screen.dart';
import 'help_screen.dart';

import '../../data/local_storage_service.dart';
import '../../domain/services/daily_reward_service.dart';
import '../../main.dart' show routeObserver;
import '../widgets/daily_reward_dialog.dart';

/// ホーム画面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  Character? _playerCharacter;
  PlayerCurrency? _playerCurrency;
  bool _loading = true;
  bool _isFirstBattle = false;
  bool _canClaimBattleReward = false;
  DailyRewardResult? _pendingLoginReward;
  final _sl = ServiceLocator();
  final DeviceInfoService _deviceInfo = DeviceInfoService();
  final _dailyMissionKey = GlobalKey();
  final _dailyShopKey = GlobalKey();

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
    WidgetsBinding.instance.addObserver(this);
    _initGame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // 他画面からpopでホームに戻ってきた時に保留中のポップアップを表示
    _showPendingLoginReward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLoginRewardOnResume();
    }
  }

  /// アプリ復帰時にログイン報酬の再判定を行う（日付跨ぎ対応）
  Future<void> _checkLoginRewardOnResume() async {
    if (!_sl.dailyRewardService.canClaimLoginReward()) return;

    final loginResult = await _sl.dailyRewardService.claimLoginReward();
    if (loginResult == null) return;

    // 通貨とバトル報酬ステータスも更新
    final currency = _sl.currencyService.load();
    final battleRewardAvailable = _sl.dailyRewardService.canClaimBattleReward();
    if (!mounted) return;
    setState(() {
      _playerCurrency = currency;
      _canClaimBattleReward = battleRewardAvailable;
    });

    // ホームが前面の場合のみポップアップを即時表示、それ以外は保留
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      await DailyRewardDialog.showLoginReward(context, loginResult);
    } else {
      _pendingLoginReward = loginResult;
    }
  }

  /// 保留中のログイン報酬ポップアップがあれば表示する
  Future<void> _showPendingLoginReward() async {
    final pending = _pendingLoginReward;
    if (pending == null) return;
    _pendingLoginReward = null;
    if (!mounted) return;
    await DailyRewardDialog.showLoginReward(context, pending);
  }

  Future<void> _initGame() async {
    final character = await _buildPlayerCharacter();
    final firstBattle = !LocalStorageService().isFirstBattleCompleted();

    // ログイン報酬を付与（その日の初回起動時）
    final loginResult = await _sl.dailyRewardService.claimLoginReward();
    final battleRewardAvailable = _sl.dailyRewardService.canClaimBattleReward();
    final currency = _sl.currencyService.load();

    if (!mounted) return;
    setState(() {
      _playerCharacter = character;
      _playerCurrency = currency;
      _isFirstBattle = firstBattle;
      _canClaimBattleReward = battleRewardAvailable;
      _loading = false;
    });

    // ログイン報酬ポップアップを表示
    if (loginResult != null && mounted) {
      await DailyRewardDialog.showLoginReward(context, loginResult);
    }
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

  void _startBattle({EnemyDifficulty? difficulty}) {
    final player = _playerCharacter;
    if (player == null) return;

    // バトル開始前に敵プレビューを表示
    _showEnemyPreview(player, difficulty: difficulty);
  }

  void _startLimitedEventBattle() {
    final player = _playerCharacter;
    if (player == null) return;

    final event = _sl.limitedEventService.loadEvent();
    final profile = EnemyGenerator.generateFromDeviceSpec(
      deviceSpec: event.definition.rivalEnemy,
      playerLevel: player.level,
    );
    _showEnemyPreview(player, fixedProfile: profile);
  }

  void _startRivalRoadBattle() {
    final player = _playerCharacter;
    if (player == null) return;

    final stage = _sl.rivalRoadService.loadRoad().nextStage;
    if (stage == null) return;

    final profile = EnemyGenerator.generateFromDeviceSpec(
      deviceSpec: stage.enemyDevice,
      playerLevel: player.level,
    );
    _showEnemyPreview(player, fixedProfile: profile);
  }

  /// 敵プレビューボトムシートを表示する
  void _showEnemyPreview(
    Character player, {
    EnemyDifficulty? difficulty,
    EnemyProfile? fixedProfile,
  }) {
    // ランダムに敵を生成してプレビュー表示
    final profile = fixedProfile ??
        (difficulty == null
            ? EnemyGenerator.generateRandom(playerLevel: player.level)
            : EnemyGenerator.generate(
                difficulty: difficulty,
                playerLevel: player.level,
              ));

    SoundService().playButton();

    showModalBottomSheet<BattleTactic>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _EnemyPreviewSheet(
        player: player,
        profile: profile,
        elementColor: elementColor,
      ),
    ).then((selectedTactic) {
      if (selectedTactic != null && mounted) {
        Navigator.of(context)
            .push<String?>(
          MaterialPageRoute(
            builder: (context) => BattleScreen(
              player: player,
              enemy: profile.character,
              enemyDeviceId: profile.deviceSpec.id,
              enemyDifficulty: profile.deviceSpec.difficulty,
              playerTactic: selectedTactic,
            ),
          ),
        )
            .then((nextAction) async {
          await _reloadData();
          if (!mounted) return;
          if (nextAction == 'gacha') {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (context) => const GachaScreen(),
                  ),
                )
                .then((_) => _reloadData());
          } else if (nextAction == 'battle') {
            _startBattle();
          } else if (nextAction == 'friend') {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (context) => const FriendBattleMenuScreen(),
                  ),
                )
                .then((_) => _reloadData());
          } else if (nextAction == 'achievements') {
            _openCollection(player, initialTabIndex: 2);
          } else if (nextAction == 'missions') {
            _focusDailyMissions();
          }
        });
      }
    });
  }

  void _openCollection(Character player, {int initialTabIndex = 0}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CollectionScreen(
              playerCharacter: player,
              initialTabIndex: initialTabIndex,
            ),
          ),
        )
        .then((_) => _reloadData());
  }

  void _openGachaScreen() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const GachaScreen()))
        .then((_) => _reloadData());
  }

  void _openChallengePicker(Character player) {
    SoundService().playButton();
    showModalBottomSheet<EnemyDifficulty>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1B2838),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '高難度に挑戦',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '強い敵ほど勝利時のコイン報酬が増え、BOSSは1日1回だけ専用報酬も獲得できます。',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                _challengeOption(
                  difficulty: EnemyDifficulty.hard,
                  player: player,
                  icon: Icons.local_fire_department,
                  color: Colors.orangeAccent,
                  description: 'ハイエンド端末が中心。育成済みキャラの腕試しに。',
                ),
                const SizedBox(height: 10),
                _challengeOption(
                  difficulty: EnemyDifficulty.boss,
                  player: player,
                  icon: Icons.whatshot,
                  color: Colors.redAccent,
                  description: '最新級フラッグシップ。初回撃破は+300 Coin / +30 Gems。',
                ),
              ],
            ),
          ),
        );
      },
    ).then((difficulty) {
      if (difficulty != null && mounted) {
        _startBattle(difficulty: difficulty);
      }
    });
  }

  /// バトル後にデータを最新状態にリロードする
  Future<void> _reloadData() async {
    final character = await _buildPlayerCharacter();
    final currency = _sl.currencyService.load();
    final firstBattle = !LocalStorageService().isFirstBattleCompleted();
    final battleRewardAvailable = _sl.dailyRewardService.canClaimBattleReward();

    if (!mounted) return;
    setState(() {
      _playerCharacter = character;
      _playerCurrency = currency;
      _isFirstBattle = firstBattle;
      _canClaimBattleReward = battleRewardAvailable;
    });

    // 保留中のログイン報酬ポップアップを表示
    await _showPendingLoginReward();
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

          // デイリー報酬カード
          _buildDailyRewardCard(),
          const SizedBox(height: 16),

          _buildDailyMissionCard(),
          const SizedBox(height: 16),

          if (_playerCurrency != null) ...[
            _buildGachaPlanCard(_playerCurrency!),
            const SizedBox(height: 16),
          ],

          _buildDailyShopCard(),
          const SizedBox(height: 16),

          _buildNextObjectiveCard(player),
          const SizedBox(height: 16),

          _buildRivalRoadCard(),
          const SizedBox(height: 16),

          _buildChallengeCard(player),
          const SizedBox(height: 16),

          _buildWeeklyChallengeCard(),
          const SizedBox(height: 16),

          _buildLimitedEventCard(),
          const SizedBox(height: 16),

          _buildSeasonPassCard(),
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
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (context) => const InventoryScreen(),
                          ),
                        )
                        .then((_) => _reloadData());
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
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (context) => const GachaScreen(),
                          ),
                        )
                        .then((_) => _reloadData()); // 戻ってきたらコイン・キャラ再取得
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
                    _openCollection(player);
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMenuButton(
                  icon: Icons.help_outline,
                  label: 'Help',
                  color: Colors.lightBlueAccent,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const HelpScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMenuButton(
                  icon: Icons.cloud_upload,
                  label: 'Backup',
                  color: Colors.cyanAccent,
                  onTap: () {
                    Navigator.of(context)
                        .push<bool>(
                      MaterialPageRoute(
                        builder: (context) => const DataBackupScreen(),
                      ),
                    )
                        .then((restored) {
                      if (restored == true) _reloadData();
                    });
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
      label: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
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
            border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Text('🪙 ', style: TextStyle(fontSize: 14)),
              Text(
                '${currency.coins}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
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
            border: Border.all(
                color: const Color(0xFFE056FD).withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Text('💎 ', style: TextStyle(fontSize: 14)),
              Text(
                '${currency.premiumGems}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
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
    final title = _sl.playerTitleService.loadTitles().current;

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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: elemColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: elemColor.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Text(
                    title.label,
                    style: TextStyle(
                      color: elemColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _elementBadge(player.element),
                    const SizedBox(width: 8),
                    Text(
                      'Lv.${player.level}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                StatBar(
                  label: 'HP',
                  value: 1.0,
                  color: Colors.greenAccent,
                  trailingText: '${player.currentStats.hp}',
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
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
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
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
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
              child:
                  const Icon(Icons.play_arrow, color: Colors.white, size: 28),
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
            const Icon(Icons.arrow_forward_ios,
                color: Color(0xFFFFD700), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyRewardCard() {
    final loginClaimed = !_sl.dailyRewardService.canClaimLoginReward();
    final battleClaimed = !_canClaimBattleReward;
    final streakDays = _sl.dailyRewardService.previewNextLoginStreakDays();
    final cycleDay = _sl.dailyRewardService.loginCycleDay(streakDays);
    final nextBonus = _sl.dailyRewardService.loginStreakBonusFor(streakDays);
    final cycleProgress =
        cycleDay == 0 ? 0.0 : cycleDay / DailyRewardService.streakCycleDays;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE056FD).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.card_giftcard, color: Color(0xFFE056FD), size: 18),
              SizedBox(width: 6),
              Text(
                'デイリー報酬',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: cycleProgress.clamp(0.0, 1.0).toDouble(),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFFD700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                cycleDay == 0
                    ? '0/${DailyRewardService.streakCycleDays}日'
                    : '$cycleDay/${DailyRewardService.streakCycleDays}日',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nextBonus > 0 && !loginClaimed
                ? '今日のログインでストリークボーナス +$nextBonus Gems'
                : '連続ログインで3日目・7日目にボーナス',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dailyRewardItem(
                  icon: Icons.wb_sunny,
                  label: 'ログイン',
                  gems: DailyRewardService.loginRewardGems,
                  claimed: loginClaimed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dailyRewardItem(
                  icon: Icons.flash_on,
                  label: 'バトル1回',
                  gems: DailyRewardService.battleRewardGems,
                  claimed: battleClaimed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyMissionCard() {
    final missions = _sl.dailyMissionService.loadMissions();
    final completed = missions.where((mission) => mission.completed).length;
    final claimable = missions.where((mission) => mission.claimable).length;

    return Container(
      key: _dailyMissionKey,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00CEC9).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt, color: Color(0xFF00CEC9), size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '今日のミッション',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (claimable > 1) ...[
                SizedBox(
                  height: 30,
                  child: TextButton(
                    onPressed: _claimAllDailyMissions,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFFD700),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('一括受取'),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                '$completed/${missions.length}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            claimable > 0 ? '$claimable件の報酬を受け取れます' : 'バトル・勝利・ガチャで毎日報酬を回収',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...missions.map(_dailyMissionItem),
        ],
      ),
    );
  }

  Widget _dailyMissionItem(DailyMissionSnapshot mission) {
    final definition = mission.definition;
    final color = mission.claimed
        ? Colors.white24
        : mission.completed
            ? const Color(0xFFFFD700)
            : const Color(0xFF00CEC9);
    final progress = mission.progress.clamp(0, definition.target).toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(
              mission.claimed
                  ? Icons.check_circle
                  : mission.completed
                      ? Icons.redeem
                      : Icons.radio_button_unchecked,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: mission.progressRatio,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$progress/${definition.target}  ${_dailyMissionRewardText(definition)}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 34,
              child: ElevatedButton(
                onPressed: mission.claimable
                    ? () => _claimDailyMission(definition.id)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white.withValues(
                    alpha: 0.08,
                  ),
                  disabledForegroundColor: Colors.white30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(
                  mission.claimed
                      ? '済'
                      : mission.completed
                          ? '受取'
                          : '未達',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyShopCard() {
    final shop = _sl.dailyShopService.loadShop();

    return Container(
      key: _dailyShopKey,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF55EFC4).withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront, color: Color(0xFF55EFC4), size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '日替わりショップ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${shop.purchasableCount}/${shop.offers.length}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '余ったCoinを育成・Battery回復・Gemsに変換',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...shop.offers.map(_dailyShopOfferItem),
        ],
      ),
    );
  }

  Widget _dailyShopOfferItem(DailyShopOfferSnapshot offer) {
    final definition = offer.definition;
    final color = offer.purchased
        ? Colors.white24
        : offer.canPurchase
            ? const Color(0xFF55EFC4)
            : Colors.white38;
    final status = offer.purchased
        ? '購入済'
        : offer.blockedReason ?? (offer.affordable ? '購入可' : 'Coin不足');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(_dailyShopIcon(definition.rewardKind), color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${definition.description}  ${_dailyShopRewardText(definition)}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 34,
              child: ElevatedButton(
                onPressed: offer.canPurchase
                    ? () => _purchaseDailyShopOffer(definition.id)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white.withValues(
                    alpha: 0.08,
                  ),
                  disabledForegroundColor: Colors.white30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text('${definition.costCoins}C'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _dailyShopIcon(DailyShopRewardKind kind) {
    return switch (kind) {
      DailyShopRewardKind.trainingExp => Icons.school,
      DailyShopRewardKind.batteryCharge => Icons.battery_charging_full,
      DailyShopRewardKind.premiumGems => Icons.diamond,
    };
  }

  String _dailyShopRewardText(DailyShopOfferDefinition definition) {
    return switch (definition.rewardKind) {
      DailyShopRewardKind.trainingExp => '+${definition.rewardAmount} EXP',
      DailyShopRewardKind.batteryCharge =>
        'Battery +${definition.rewardAmount}%',
      DailyShopRewardKind.premiumGems => '+${definition.rewardAmount} Gems',
    };
  }

  Widget _buildGachaPlanCard(PlayerCurrency currency) {
    final plan = _sl.gachaPlanService.buildPlan(currency);
    final recommended = plan.recommendedTarget;

    return InkWell(
      onTap: _openGachaScreen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2838),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route, color: Color(0xFFFFD700), size: 18),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '解析ロードマップ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    recommended.kind == GachaPlanTargetKind.eventLimited
                        ? '限定優先'
                        : '日替わり優先',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '次の狙い: ${recommended.deviceName} / ${_gachaPlanActionText(recommended)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            _gachaPlanRow(plan.eventLimited, const Color(0xFF55EFC4)),
            const SizedBox(height: 8),
            _gachaPlanRow(plan.premiumFeatured, const Color(0xFFE056FD)),
          ],
        ),
      ),
    );
  }

  Widget _gachaPlanRow(GachaPlanTarget target, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: color, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${target.title}: ${target.deviceName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                target.nextPullGuaranteed
                    ? '次回確定'
                    : 'あと${target.pullsUntilGuarantee}回',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: target.guaranteeProgress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _gachaPlanDetailText(target),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  String _gachaPlanActionText(GachaPlanTarget target) {
    if (target.canReachGuarantee) {
      return '天井分のGems到達';
    }
    if (target.canPullNow) {
      return '${target.affordablePulls}回解析可能';
    }
    return 'あと${target.gemsShortage} Gems';
  }

  String _gachaPlanDetailText(GachaPlanTarget target) {
    final base = target.nextPullGuaranteed
        ? '次回は確定'
        : '天井まで${target.gemsToGuarantee} Gems';
    if (target.gemsShortage == 0) {
      return '$base / いま狙えます';
    }
    return '$base / あと${target.gemsShortage} Gems';
  }

  Future<void> _claimDailyMission(String id) async {
    SoundService().playButton();
    final result = await _sl.dailyMissionService.claim(id);
    if (!mounted || result == null) return;

    await _reloadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_dailyMissionClaimSummary(result)} を受け取りました')),
    );
  }

  Future<void> _claimAllDailyMissions() async {
    SoundService().playButton();
    final result = await _sl.dailyMissionService.claimAllAvailable();
    if (!mounted || result == null) return;

    await _reloadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.claimedCount}件: ${_dailyMissionClaimAllSummary(result)} を受け取りました',
        ),
      ),
    );
  }

  Future<void> _purchaseDailyShopOffer(String id) async {
    SoundService().playButton();
    final result = await _sl.dailyShopService.purchase(id);
    if (!mounted || result == null) return;

    await _reloadData();
    if (!mounted) return;
    final levelText =
        result.levelsGained > 0 ? ' / Lv+${result.levelsGained}' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.summary}$levelText を購入しました')),
    );
  }

  Future<void> _claimWeeklyChallenge() async {
    SoundService().playButton();
    final result = await _sl.weeklyChallengeService.claim();
    if (!mounted || result == null) return;

    await _reloadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.coinsAwarded} Coin / ${result.gemsAwarded} Gems を受け取りました',
        ),
      ),
    );
  }

  Future<void> _claimLimitedEvent() async {
    SoundService().playButton();
    final result = await _sl.limitedEventService.claim();
    if (!mounted || result == null) return;

    await _reloadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.coinsAwarded} Coin / ${result.gemsAwarded} Gems を受け取りました',
        ),
      ),
    );
  }

  Future<void> _claimLimitedEventMilestones() async {
    SoundService().playButton();
    final result = await _sl.limitedEventService.claimAvailableMilestones();
    if (!mounted || result == null) return;

    await _reloadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.claimedCount}件: ${_limitedEventClaimSummary(result)} を受け取りました',
        ),
      ),
    );
  }

  Future<void> _claimSeasonPassRewards() async {
    SoundService().playButton();
    final result = await _sl.seasonPassService.claimAllAvailable();
    if (!mounted || result == null) return;

    await _reloadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.claimedCount}件: ${_seasonPassClaimSummary(result)} を受け取りました',
        ),
      ),
    );
  }

  String _dailyMissionRewardText(DailyMissionDefinition definition) {
    final parts = <String>[];
    if (definition.coinsReward > 0) {
      parts.add('+${definition.coinsReward} Coin');
    }
    if (definition.gemsReward > 0) {
      parts.add('+${definition.gemsReward} Gems');
    }
    return parts.join(' / ');
  }

  String _seasonPassClaimSummary(SeasonPassClaimResult result) {
    final parts = <String>[];
    if (result.coinsAwarded > 0) {
      parts.add('${result.coinsAwarded} Coin');
    }
    if (result.gemsAwarded > 0) {
      parts.add('${result.gemsAwarded} Gems');
    }
    return parts.join(' / ');
  }

  String _limitedEventClaimSummary(LimitedEventClaimResult result) {
    final parts = <String>[];
    if (result.coinsAwarded > 0) parts.add('${result.coinsAwarded} Coin');
    if (result.gemsAwarded > 0) parts.add('${result.gemsAwarded} Gems');
    return parts.join(' / ');
  }

  String _dailyMissionClaimSummary(DailyMissionClaimResult result) {
    final parts = <String>[];
    if (result.coinsAwarded > 0) parts.add('${result.coinsAwarded} Coin');
    if (result.gemsAwarded > 0) parts.add('${result.gemsAwarded} Gems');
    return parts.join(' / ');
  }

  String _dailyMissionClaimAllSummary(DailyMissionClaimAllResult result) {
    final parts = <String>[];
    if (result.coinsAwarded > 0) parts.add('${result.coinsAwarded} Coin');
    if (result.gemsAwarded > 0) parts.add('${result.gemsAwarded} Gems');
    return parts.join(' / ');
  }

  void _focusDailyMissions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _dailyMissionKey.currentContext;
      if (!mounted || context == null) return;

      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('今日のミッションから報酬を受け取れます')),
      );
    });
  }

  void _focusDailyShop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _dailyShopKey.currentContext;
      if (!mounted || context == null) return;

      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('日替わりショップの商品を購入できます')),
      );
    });
  }

  Widget _buildNextObjectiveCard(Character player) {
    final objective = _nextObjective(player);

    return InkWell(
      onTap: objective.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2838),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: objective.color.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: objective.color.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: objective.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: objective.color.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(objective.icon, color: objective.color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    objective.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    objective.description,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: objective.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                objective.buttonLabel,
                style: TextStyle(
                  color: objective.color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRivalRoadCard() {
    final road = _sl.rivalRoadService.loadRoad();
    final nextStage = road.nextStage;
    final completed = road.completed;
    final bestCount = road.bestTurnsByStage.length;
    final color = completed ? const Color(0xFFFFD700) : Colors.lightBlueAccent;

    return InkWell(
      onTap: completed ? null : _startRivalRoadBattle,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2838),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  completed ? Icons.emoji_events : Icons.flag,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'ライバルロード',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${road.clearedStageCount}/${road.totalStageCount}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: road.progressRatio,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 10),
            if (completed)
              Text(
                bestCount == road.totalStageCount
                    ? '全ステージ制覇済み。全ステージの最短ターン更新を狙えます。'
                    : '全ステージ制覇済み。未記録ステージの最短ターンを埋められます。',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.25,
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stage ${nextStage!.index}: ${nextStage.title} / ${nextStage.enemyDevice.deviceName}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (road.bestTurnsFor(nextStage) != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            'BEST ${road.bestTurnsFor(nextStage)}T',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${nextStage.rewardCoins}C / +${nextStage.rewardGems}G',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'BEST $bestCount/${road.totalStageCount}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeCard(Character player) {
    final bountyAvailable = _sl.bossBountyService.canReceiveToday;
    final bossBestTurns = _sl.storage.getBossBestTurns();

    return InkWell(
      onTap: () => _openChallengePicker(player),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2838),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.32),
                ),
              ),
              child: const Icon(
                Icons.local_fire_department,
                color: Colors.redAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '高難度チャレンジ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    bossBestTurns != null
                        ? 'BOSS自己ベスト: ${bossBestTurns}ターン。${bountyAvailable ? '本日報酬も未回収です。' : '記録更新を狙えます。'}'
                        : bountyAvailable
                            ? 'BOSS初回撃破で +300 Coin / +30 Gems'
                            : '本日のBOSS撃破報酬は受取済みです。',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '挑戦',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChallengeCard() {
    final challenge = _sl.weeklyChallengeService.loadChallenge();
    final progressText =
        '${challenge.wins.clamp(0, challenge.targetWins)}/${challenge.targetWins}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events,
                  color: Color(0xFFFFD700), size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '週次チャレンジ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                progressText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: challenge.progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFFD700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            challenge.claimable
                ? 'HARD/BOSS勝利を達成。報酬を受け取れます。'
                : challenge.claimed
                    ? '今週の報酬は受取済みです。'
                    : 'HARD/BOSSのCPU戦で週3勝すると +600 Coin / +50 Gems',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.25,
            ),
          ),
          if (challenge.claimable) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _claimWeeklyChallenge,
                icon: const Icon(Icons.card_giftcard, size: 18),
                label: const Text('週次報酬を受け取る'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: const Color(0xFF1B1B1B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLimitedEventCard() {
    final event = _sl.limitedEventService.loadEvent();
    final progressText =
        '${event.wins.clamp(0, event.definition.targetWins)}/${event.definition.targetWins}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE056FD).withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE056FD).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available,
                  color: Color(0xFFE056FD), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.definition.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '残り${event.daysRemaining}日',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                progressText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: event.progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFE056FD),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            event.claimable
                ? 'イベント達成。限定報酬を受け取れます。'
                : event.claimed
                    ? '今週のイベント報酬は受取済みです。'
                    : '${event.definition.description}。専用ライバル勝利は2勝分カウントされます。',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE056FD).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFE056FD).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt,
                  color: Color(0xFFE056FD),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '今週のライバル: ${event.definition.rivalEnemy.deviceName}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '+${event.definition.rewardCoins} Coin / +${event.definition.rewardGems} Gems',
                  style: const TextStyle(
                    color: Color(0xFFE056FD),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: event.milestones.map(_limitedEventMilestoneChip).toList(),
          ),
          if (event.claimableMilestoneCount > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _claimLimitedEventMilestones,
                icon: const Icon(Icons.redeem, size: 18),
                label: Text('段階報酬を受け取る (${event.claimableMilestoneCount})'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFD700),
                  side: const BorderSide(color: Color(0xFFFFD700)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
          if (event.claimable) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _claimLimitedEvent,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('イベント報酬を受け取る'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE056FD),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _startLimitedEventBattle,
                icon: const Icon(Icons.sports_martial_arts, size: 18),
                label: const Text('イベントライバルに挑戦'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE056FD),
                  side: const BorderSide(color: Color(0xFFE056FD)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _limitedEventMilestoneChip(
    LimitedEventMilestoneSnapshot milestone,
  ) {
    final color = milestone.claimed
        ? Colors.white30
        : milestone.claimable
            ? const Color(0xFFFFD700)
            : const Color(0xFFE056FD);
    final reward = _limitedEventMilestoneRewardText(milestone.definition);

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
            milestone.claimed
                ? Icons.check_circle
                : milestone.claimable
                    ? Icons.card_giftcard
                    : Icons.flag,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            '${milestone.definition.requiredWins}勝 $reward',
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

  String _limitedEventMilestoneRewardText(
    LimitedEventMilestoneDefinition definition,
  ) {
    final parts = <String>[];
    if (definition.rewardCoins > 0)
      parts.add('+${definition.rewardCoins} Coin');
    if (definition.rewardGems > 0) parts.add('+${definition.rewardGems} Gems');
    return parts.join(' / ');
  }

  Widget _buildSeasonPassCard() {
    final pass = _sl.seasonPassService.loadPass();
    final nextReward = pass.nextReward;
    final progress = nextReward?.progress ?? 1.0;
    final progressText = nextReward == null
        ? '${pass.xp} SP'
        : '${pass.xp.clamp(0, nextReward.definition.requiredXp)}/${nextReward.definition.requiredXp} SP';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF55EFC4).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech,
                  color: Color(0xFF55EFC4), size: 19),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'シーズンパス ${pass.seasonId}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '残り${pass.daysRemaining}日',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                progressText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF55EFC4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pass.completed
                ? '今月の報酬はすべて受取済みです。'
                : pass.claimableCount > 0
                    ? '${pass.claimableCount}件のシーズン報酬を受け取れます。'
                    : nextReward == null
                        ? 'バトルでシーズンポイントを集めて報酬を解放します。'
                        : '次: ${nextReward.definition.title}（${_seasonRewardText(nextReward.definition)}）',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pass.rewards
                .map(
                  (reward) => _seasonRewardChip(
                    reward.definition.requiredXp,
                    reward.claimed,
                    reward.unlocked,
                  ),
                )
                .toList(),
          ),
          if (pass.claimableCount > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _claimSeasonPassRewards,
                icon: const Icon(Icons.redeem, size: 18),
                label: const Text('シーズン報酬を受け取る'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF55EFC4),
                  foregroundColor: const Color(0xFF0D1B2A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _seasonRewardChip(int requiredXp, bool claimed, bool unlocked) {
    final color = claimed
        ? Colors.white30
        : unlocked
            ? const Color(0xFF55EFC4)
            : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: unlocked ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            claimed ? Icons.check_circle : Icons.lock_open,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            '${requiredXp}SP',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _seasonRewardText(SeasonPassRewardDefinition definition) {
    final parts = <String>[];
    if (definition.coinsReward > 0) {
      parts.add('+${definition.coinsReward} Coin');
    }
    if (definition.gemsReward > 0) {
      parts.add('+${definition.gemsReward} Gems');
    }
    return parts.join(' / ');
  }

  Widget _challengeOption({
    required EnemyDifficulty difficulty,
    required Character player,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    final reward = CurrencyService.calcBattleCoins(
      won: true,
      playerLevel: player.level,
      difficulty: difficulty,
    );

    return InkWell(
      onTap: () => Navigator.of(context).pop(difficulty),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    difficulty.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '+$reward Coin',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _NextObjective _nextObjective(Character player) {
    final currency = _playerCurrency;
    final roster = _sl.gachaService.loadRoster();
    final equippedId = _sl.storage.getEquippedGachaCharacterId();
    final defeatedCount = _sl.storage.getDefeatedEnemies().length;
    final enemyTotal = EnemyGenerator.allEnemyDevices.length;
    final claimableAchievements = _sl.achievementService.claimableCount();
    final claimableMissions = _sl.dailyMissionService.claimableCount();
    final weeklyChallenge = _sl.weeklyChallengeService.loadChallenge();
    final limitedEvent = _sl.limitedEventService.loadEvent();
    final seasonPass = _sl.seasonPassService.loadPass();
    final dailyShop = _sl.dailyShopService.loadShop();
    final rivalRoad = _sl.rivalRoadService.loadRoad();

    if (claimableAchievements > 0) {
      return _NextObjective(
        icon: Icons.workspace_premium,
        title: '実績報酬が未受取',
        description: '$claimableAchievements件の達成報酬があります。コインやジェムを回収しましょう。',
        buttonLabel: '受取',
        color: const Color(0xFFFFD700),
        onTap: () => _openCollection(player, initialTabIndex: 2),
      );
    }

    if (claimableMissions > 0) {
      return _NextObjective(
        icon: Icons.task_alt,
        title: 'ミッション報酬が未受取',
        description: '$claimableMissions件のデイリー報酬があります。まとめて回収できます。',
        buttonLabel: '確認',
        color: const Color(0xFF00CEC9),
        onTap: _focusDailyMissions,
      );
    }

    if (weeklyChallenge.claimable) {
      return _NextObjective(
        icon: Icons.emoji_events,
        title: '週次チャレンジ達成',
        description: 'HARD/BOSS戦の週次報酬を受け取れます。',
        buttonLabel: '受取',
        color: const Color(0xFFFFD700),
        onTap: _claimWeeklyChallenge,
      );
    }

    if (limitedEvent.claimable) {
      return _NextObjective(
        icon: Icons.event_available,
        title: '期間イベント達成',
        description: '${limitedEvent.definition.title} の報酬を受け取れます。',
        buttonLabel: '受取',
        color: const Color(0xFFE056FD),
        onTap: _claimLimitedEvent,
      );
    }

    if (limitedEvent.claimableMilestoneCount > 0) {
      return _NextObjective(
        icon: Icons.event_available,
        title: 'イベント段階報酬が未受取',
        description: '${limitedEvent.claimableMilestoneCount}件の途中報酬を受け取れます。',
        buttonLabel: '受取',
        color: const Color(0xFFE056FD),
        onTap: _claimLimitedEventMilestones,
      );
    }

    if (seasonPass.claimableCount > 0) {
      return _NextObjective(
        icon: Icons.military_tech,
        title: 'シーズン報酬が未受取',
        description: '${seasonPass.claimableCount}件のシーズンパス報酬を受け取れます。',
        buttonLabel: '受取',
        color: const Color(0xFF55EFC4),
        onTap: _claimSeasonPassRewards,
      );
    }

    if (dailyShop.purchasableCount > 0) {
      return _NextObjective(
        icon: Icons.storefront,
        title: '日替わりショップ更新',
        description: 'Coinを育成・Battery回復・Gemsに変換できる商品があります。',
        buttonLabel: '確認',
        color: const Color(0xFF55EFC4),
        onTap: _focusDailyShop,
      );
    }

    if (!rivalRoad.completed) {
      final nextStage = rivalRoad.nextStage!;
      return _NextObjective(
        icon: Icons.flag,
        title: 'ライバルロード進行中',
        description:
            'Stage ${nextStage.index}: ${nextStage.title} を突破して一度きりの報酬を回収しましょう。',
        buttonLabel: '挑戦',
        color: Colors.lightBlueAccent,
        onTap: _startRivalRoadBattle,
      );
    }

    if (_canClaimBattleReward) {
      return _NextObjective(
        icon: Icons.card_giftcard,
        title: '今日のバトル報酬が未回収',
        description: 'CPU戦を1回遊ぶと、プレミアム解析に使えるジェムが手に入ります。',
        buttonLabel: '挑戦',
        color: const Color(0xFFE056FD),
        onTap: _startBattle,
      );
    }

    if (currency != null && currency.canAffordEventLimitedPull()) {
      return _NextObjective(
        icon: Icons.auto_awesome,
        title: 'イベント解析が可能',
        description: '30ジェムでSR以上確定。期間限定SSRを狙える今週の解析です。',
        buttonLabel: '限定',
        color: const Color(0xFF55EFC4),
        onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const GachaScreen()))
              .then((_) => _reloadData());
        },
      );
    }

    if (currency != null && currency.canAffordPremiumPull()) {
      return _NextObjective(
        icon: Icons.auto_awesome,
        title: 'プレミアム解析が可能',
        description: '20ジェムでSR以上確定。新しい主力候補を狙えます。',
        buttonLabel: '解析',
        color: const Color(0xFFE056FD),
        onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const GachaScreen()))
              .then((_) => _reloadData());
        },
      );
    }

    if (roster.isNotEmpty && equippedId == null) {
      return _NextObjective(
        icon: Icons.group,
        title: 'ガチャキャラを編成しよう',
        description: '所持キャラを装備すると、バトル・共有URLの主役として戦えます。',
        buttonLabel: '編成',
        color: Colors.blueAccent,
        onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const InventoryScreen()))
              .then((_) => _reloadData());
        },
      );
    }

    if (currency != null && currency.coins >= PlayerCurrency.singlePullCost) {
      return _NextObjective(
        icon: Icons.star,
        title: 'コインガチャを引けます',
        description: 'バトル報酬のコインで端末キャラを増やし、編成の幅を広げましょう。',
        buttonLabel: 'ガチャ',
        color: Colors.orangeAccent,
        onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const GachaScreen()))
              .then((_) => _reloadData());
        },
      );
    }

    if (defeatedCount < enemyTotal) {
      return _NextObjective(
        icon: Icons.menu_book,
        title: '図鑑 ${defeatedCount}/$enemyTotal',
        description: '未発見の端末が残っています。勝利してコレクションを埋めましょう。',
        buttonLabel: '確認',
        color: Colors.white70,
        onTap: () => _openCollection(player),
      );
    }

    return _NextObjective(
      icon: Icons.people,
      title: 'フレンド対戦で腕試し',
      description: '育てたキャラをURLで共有して、ほかの端末スペックと戦えます。',
      buttonLabel: '共有',
      color: Colors.greenAccent,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FriendBattleMenuScreen()),
        );
      },
    );
  }

  Widget _dailyRewardItem({
    required IconData icon,
    required String label,
    required int gems,
    required bool claimed,
  }) {
    final color = claimed ? Colors.white24 : const Color(0xFFE056FD);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: claimed
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFE056FD).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  claimed ? '受取済' : '💎 +$gems',
                  style: TextStyle(
                    color: claimed ? Colors.white24 : const Color(0xFFE056FD),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (claimed)
            const Icon(Icons.check_circle, color: Colors.white24, size: 18),
        ],
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

class _EnemyPreviewSheet extends StatefulWidget {
  final Character player;
  final EnemyProfile profile;
  final Color Function(ElementType) elementColor;

  const _EnemyPreviewSheet({
    required this.player,
    required this.profile,
    required this.elementColor,
  });

  @override
  State<_EnemyPreviewSheet> createState() => _EnemyPreviewSheetState();
}

class _EnemyPreviewSheetState extends State<_EnemyPreviewSheet> {
  late BattleTactic _selectedTactic;

  @override
  void initState() {
    super.initState();
    _selectedTactic = _recommendedTactic;
  }

  BattleTactic get _recommendedTactic {
    final enemy = widget.profile.character;
    final playerScore = _battleScore(widget.player, enemy);
    final enemyScore = _battleScore(enemy, widget.player);
    final ratio = enemyScore <= 0 ? 1.0 : playerScore / enemyScore;
    final matchup = widget.player.element.multiplierAgainst(enemy.element);
    return _suggestTactic(ratio, matchup);
  }

  @override
  Widget build(BuildContext context) {
    final enemy = widget.profile.character;
    final device = widget.profile.deviceSpec;
    final enemyColor = widget.elementColor(enemy.element);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final charSize = (screenWidth * 0.18).clamp(50.0, 100.0);

    // 難易度に応じたカラー
    final diffColor = switch (device.difficulty) {
      EnemyDifficulty.easy => Colors.greenAccent,
      EnemyDifficulty.normal => Colors.blueAccent,
      EnemyDifficulty.hard => Colors.orangeAccent,
      EnemyDifficulty.boss => Colors.redAccent,
    };

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1B2838),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ドラッグハンドル
            Container(
              width: 40,
              height: 4,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 13),
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

            _buildBattleInsightCard(
              player: widget.player,
              enemy: enemy,
              difficulty: device.difficulty,
              accentColor: diffColor,
            ),
            const SizedBox(height: 12),

            // 戦術選択
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, size: 16, color: Colors.white54),
                    SizedBox(width: 6),
                    Text(
                      '戦術を選択',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BattleTactic.values
                      .map((tactic) => _tacticChip(tactic))
                      .toList(),
                ),
              ],
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
                    onPressed: () => Navigator.of(context).pop(),
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
                    onPressed: () => Navigator.of(context).pop(_selectedTactic),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 6,
                      shadowColor:
                          const Color(0xFF6C5CE7).withValues(alpha: 0.4),
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
      ),
    );
  }

  Widget _tacticChip(BattleTactic tactic) {
    final selected = tactic == _selectedTactic;
    final bonusText = tactic.hasRewardBonus
        ? 'Coin x${tactic.rewardMultiplier.toStringAsFixed(1)}'
        : 'Coin x1.0';
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTactic = tactic;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF6C5CE7) : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tactic.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle,
                      size: 14, color: Color(0xFF6C5CE7)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tactic.description,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              bonusText,
              style: TextStyle(
                color: tactic.hasRewardBonus
                    ? const Color(0xFFFFD700)
                    : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBattleInsightCard({
    required Character player,
    required Character enemy,
    required EnemyDifficulty difficulty,
    required Color accentColor,
  }) {
    final playerScore = _battleScore(player, enemy);
    final enemyScore = _battleScore(enemy, player);
    final ratio = enemyScore <= 0 ? 1.0 : playerScore / enemyScore;
    final matchup = player.element.multiplierAgainst(enemy.element);
    final suggested = _suggestTactic(ratio, matchup);
    final reward = CurrencyService.calcBattleCoins(
      won: true,
      playerLevel: player.level,
      difficulty: difficulty,
      rewardMultiplier: _selectedTactic.rewardMultiplier,
    );
    final forecastColor = _forecastColor(ratio);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, size: 16, color: Colors.white54),
              const SizedBox(width: 6),
              const Text(
                'バトル解析',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                _forecastLabel(ratio),
                style: TextStyle(
                  color: forecastColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 2.0) / 2.0,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(forecastColor),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _insightPill(
                icon: Icons.monitor_heart,
                label: '${playerScore.round()} vs ${enemyScore.round()}',
                color: Colors.white70,
              ),
              _insightPill(
                icon: Icons.auto_awesome,
                label: _matchupLabel(matchup),
                color: _matchupColor(matchup),
              ),
              _insightPill(
                icon: Icons.tune,
                label: '推奨 ${suggested.label}',
                color: suggested == _selectedTactic
                    ? const Color(0xFFFFD700)
                    : Colors.white70,
              ),
              _insightPill(
                icon: Icons.paid,
                label: '勝利時 +$reward Coin',
                color: _selectedTactic.hasRewardBonus
                    ? const Color(0xFFFFD700)
                    : Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _insightPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  double _battleScore(Character attacker, Character defender) {
    final stats = attacker.battleStats;
    final elementBonus = attacker.element.multiplierAgainst(defender.element);
    return stats.maxHp * 0.35 +
        stats.atk * 3.0 * elementBonus +
        stats.def * 2.1 +
        stats.spd * 1.6;
  }

  BattleTactic _suggestTactic(double ratio, double matchup) {
    if (ratio < 0.88) return BattleTactic.firewall;
    if (matchup >= 1.5) return BattleTactic.burst;
    if (ratio > 1.18) return BattleTactic.overclock;
    return BattleTactic.balanced;
  }

  String _forecastLabel(double ratio) {
    if (ratio >= 1.18) return '優勢';
    if (ratio >= 0.88) return '接戦';
    return '劣勢';
  }

  Color _forecastColor(double ratio) {
    if (ratio >= 1.18) return Colors.greenAccent;
    if (ratio >= 0.88) return Colors.amberAccent;
    return Colors.redAccent;
  }

  String _matchupLabel(double matchup) {
    if (matchup >= 1.5) return '属性有利';
    if (matchup <= 0.75) return '属性不利';
    return '属性互角';
  }

  Color _matchupColor(double matchup) {
    if (matchup >= 1.5) return Colors.greenAccent;
    if (matchup <= 0.75) return Colors.redAccent;
    return Colors.white70;
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
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
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

class _NextObjective {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final Color color;
  final VoidCallback onTap;

  const _NextObjective({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.color,
    required this.onTap,
  });
}
