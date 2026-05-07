import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/character.dart';
import '../../domain/enums/battle_tactic.dart';
import '../../domain/services/boss_bounty_service.dart';
import '../../domain/services/battle_engine.dart';
import '../../domain/services/daily_reward_service.dart';
import '../../domain/services/enemy_generator.dart';
import '../../domain/services/rival_road_service.dart';
import '../../domain/services/service_locator.dart';
import '../../domain/services/battle_result_service.dart';
import '../widgets/daily_reward_dialog.dart';
import '../widgets/first_battle_complete_dialog.dart';
import '../widgets/pixel_character.dart';

/// バトルリザルト画面
class ResultScreen extends StatefulWidget {
  final BattleResult result;
  final Character player;
  final Character enemy;
  final String? enemyDeviceId;
  final EnemyDifficulty enemyDifficulty;
  final bool isCpuBattle;

  const ResultScreen({
    super.key,
    required this.result,
    required this.player,
    required this.enemy,
    this.enemyDeviceId,
    this.enemyDifficulty = EnemyDifficulty.normal,
    this.isCpuBattle = true,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Future<void> _saveFuture;
  late Animation<double> _opacityAnimation;

  late AnimationController _levelUpController;
  late Animation<double> _levelUpGlowAnimation;

  int _levelBefore = 1;
  int _levelAfter = 1;
  bool get _leveledUp => _levelAfter > _levelBefore;
  int _coinsGained = 0;
  bool _isFirstBattle = false;
  bool _finishing = false;
  bool _canOpenGacha = false;
  int _claimableAchievementCount = 0;
  int _claimableDailyMissionCount = 0;
  DailyRewardResult? _dailyBattleReward;
  BossBountyResult? _bossBountyReward;
  EnemyDiscoveryBonus? _enemyDiscoveryBonus;
  BossRecordUpdate? _bossRecordUpdate;
  RivalRoadClearResult? _rivalRoadClearResult;
  int _seasonPassXpGained = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();

    _levelUpController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _levelUpGlowAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _levelUpController, curve: Curves.easeInOut),
    );

    _canOpenGacha = _hasGachaPullAvailable();

    // バトル結果を永続化する（Futureを保持して遷移前に完了を保証）
    _saveFuture = _saveResult();
  }

  /// バトル結果をLocalStorageに保存する
  Future<void> _saveResult() async {
    final persisted = await ServiceLocator().battleResultService.persistResult(
          battleResult: widget.result,
          enemyDifficulty: widget.enemyDifficulty,
          isCpuBattle: widget.isCpuBattle,
          enemyDeviceId: widget.enemyDeviceId,
          playerName: widget.player.name,
          enemyName: widget.enemy.name,
        );

    _applyPersistedResult(persisted);

    if (mounted) setState(() {});
  }

  void _applyPersistedResult(PersistedBattleResult persisted) {
    _levelBefore = persisted.levelBefore;
    _levelAfter = persisted.levelAfter;
    _coinsGained = persisted.coinsGained;
    _isFirstBattle = persisted.isFirstBattle;
    _dailyBattleReward = persisted.dailyBattleReward;
    _bossBountyReward = persisted.bossBountyReward;
    _enemyDiscoveryBonus = persisted.enemyDiscoveryBonus;
    _bossRecordUpdate = persisted.bossRecordUpdate;
    _rivalRoadClearResult = persisted.rivalRoadClearResult;
    _seasonPassXpGained = persisted.seasonPassXpGained;
    _canOpenGacha = _hasGachaPullAvailable();
    _claimableAchievementCount =
        ServiceLocator().achievementService.claimableCount();
    _claimableDailyMissionCount =
        ServiceLocator().dailyMissionService.claimableCount();
  }

  bool _hasGachaPullAvailable() {
    final currency = ServiceLocator().currencyService.load();
    return currency.canAffordSingle() ||
        currency.canAffordPremiumPull() ||
        currency.canAffordEventLimitedPull();
  }

  Future<void> _finishAndPop({String? requestedAction}) async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
    });

    // 保存完了を待ってから次画面へ進む
    await _saveFuture;
    if (!mounted) return;

    // デイリーバトル報酬ポップアップ
    if (_dailyBattleReward != null) {
      await DailyRewardDialog.showBattleReward(context, _dailyBattleReward!);
      if (!mounted) return;
    }

    var nextAction = requestedAction;
    if (nextAction == null && _isFirstBattle) {
      nextAction = await FirstBattleCompleteDialog.show(context);
      if (!mounted) return;
    }

    // ResultScreen → BattleScreen にpop（nextActionを伝搬）
    Navigator.of(context).pop(nextAction);
  }

  Future<void> _copyResultSummary() async {
    await _saveFuture;
    if (!mounted) return;

    await Clipboard.setData(ClipboardData(text: _buildShareText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('バトル結果をコピーしました')),
    );
  }

  String _buildShareText() {
    final lines = <String>[
      'SPEC BATTLE',
      '${widget.result.playerWon ? '勝利' : '敗北'}: ${widget.player.name} vs ${widget.enemy.name}',
      'ターン: ${widget.result.turnsPlayed}',
      '戦術: ${widget.result.playerTactic.label} / ${widget.result.supportCommand.label}',
      '獲得: +${widget.result.expGained} EXP / +$_coinsGained Coin',
    ];

    if (_dailyBattleReward != null) {
      lines.add('デイリー報酬: +${_dailyBattleReward!.gemsAwarded} Gems');
    }
    if (_seasonPassXpGained > 0) {
      lines.add('シーズンポイント: +$_seasonPassXpGained SP');
    }
    if (_enemyDiscoveryBonus != null) {
      lines.add(
        '初回撃破ボーナス: +${_enemyDiscoveryBonus!.coinsAwarded} Coin / +${_enemyDiscoveryBonus!.gemsAwarded} Gems',
      );
    }
    if (_bossBountyReward != null) {
      lines.add(
        'BOSS撃破報酬: +${_bossBountyReward!.coinsAwarded} Coin / +${_bossBountyReward!.gemsAwarded} Gems',
      );
    }
    if (_rivalRoadClearResult != null) {
      final stage = _rivalRoadClearResult!.stage;
      if (_rivalRoadClearResult!.stageCleared) {
        lines.add(
          'ライバルロード: ${stage.title} CLEAR +${stage.rewardCoins} Coin / +${stage.rewardGems} Gems',
        );
      }
      if (_rivalRoadClearResult!.bestTurnsUpdated) {
        lines.add('ライバルロード最短: ${_rivalRoadClearResult!.bestTurns}ターン');
      }
    }
    if (_bossRecordUpdate != null) {
      final previous = _bossRecordUpdate!.previousBestTurns;
      lines.add(
        previous == null
            ? 'BOSS自己ベスト: ${_bossRecordUpdate!.bestTurns}ターン'
            : 'BOSS自己ベスト更新: $previous → ${_bossRecordUpdate!.bestTurns}ターン',
      );
    }
    return lines.join('\n');
  }

  @override
  void dispose() {
    _controller.dispose();
    _levelUpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final won = widget.result.playerWon;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: _buildContent(context, won),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool won) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 勝敗アイコン
          Icon(
            won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
            size: 80,
            color: won ? const Color(0xFFFFD700) : const Color(0xFF636E72),
          ),
          const SizedBox(height: 16),
          // 勝敗テキスト
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              won ? '🎉 勝利！' : '💀 敗北…',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: won ? const Color(0xFFFFD700) : const Color(0xFFE17055),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // バトルサマリーカード
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2838),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: won
                    ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                    : Colors.white10,
              ),
            ),
            child: Column(
              children: [
                // キャラクター対決表示
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        PixelCharacter(character: widget.player, size: 60),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 80,
                          child: Text(widget.player.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                    const Text('VS',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        )),
                    Column(
                      children: [
                        PixelCharacter(
                            character: widget.enemy,
                            size: 60,
                            flipHorizontal: true),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 80,
                          child: Text(widget.enemy.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                _infoRow('ターン数', '${widget.result.turnsPlayed}'),
                _infoRow('獲得経験値', '+${widget.result.expGained} EXP'),
                _infoRow('獲得コイン', '+$_coinsGained Coin'),
                if (_seasonPassXpGained > 0)
                  _infoRow('シーズンポイント', '+$_seasonPassXpGained SP'),
                if (_dailyBattleReward != null)
                  _infoRow(
                      'デイリー報酬', '+${_dailyBattleReward!.gemsAwarded} Gems 💎'),
                if (_enemyDiscoveryBonus != null)
                  _infoRow(
                    '初回撃破ボーナス',
                    '+${_enemyDiscoveryBonus!.coinsAwarded} Coin / +${_enemyDiscoveryBonus!.gemsAwarded} Gems',
                  ),
                if (_bossBountyReward != null)
                  _infoRow(
                    'BOSS撃破報酬',
                    '+${_bossBountyReward!.coinsAwarded} Coin / +${_bossBountyReward!.gemsAwarded} Gems',
                  ),
                if (_rivalRoadClearResult != null)
                  if (_rivalRoadClearResult!.stageCleared)
                    _infoRow(
                      'ライバルロード',
                      '+${_rivalRoadClearResult!.stage.rewardCoins} Coin / +${_rivalRoadClearResult!.stage.rewardGems} Gems',
                    ),
                if (_rivalRoadClearResult != null &&
                    _rivalRoadClearResult!.bestTurnsUpdated)
                  _infoRow(
                    'ロード最短更新',
                    _rivalRoadClearResult!.previousBestTurns == null
                        ? '${_rivalRoadClearResult!.bestTurns}ターン'
                        : '${_rivalRoadClearResult!.previousBestTurns} → ${_rivalRoadClearResult!.bestTurns}ターン',
                  ),
                if (_bossRecordUpdate != null)
                  _infoRow(
                    'BOSS最短更新',
                    _bossRecordUpdate!.previousBestTurns == null
                        ? '${_bossRecordUpdate!.bestTurns}ターン'
                        : '${_bossRecordUpdate!.previousBestTurns} → ${_bossRecordUpdate!.bestTurns}ターン',
                  ),
              ],
            ),
          ),

          // 戦術サマリー
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2838),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '戦術: ${widget.result.playerTactic.label}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.result.playerTactic.hasRewardBonus && won)
                  Text(
                    'Coin x${widget.result.playerTactic.rewardMultiplier.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),

          // レベルアップ演出
          if (_leveledUp) ...[
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _levelUpGlowAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _levelUpGlowAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '⭐ LEVEL UP!  Lv.$_levelBefore → Lv.$_levelAfter',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFD700),
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],

          if (_claimableAchievementCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium,
                    color: Color(0xFFFFD700),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '実績達成！',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$_claimableAchievementCount件の報酬を受け取れます',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _finishing
                        ? null
                        : () => _finishAndPop(requestedAction: 'achievements'),
                    child: const Text('開く'),
                  ),
                ],
              ),
            ),
          ],

          if (_claimableDailyMissionCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00CEC9).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF00CEC9).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.task_alt,
                    color: Color(0xFF00CEC9),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ミッション達成！',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$_claimableDailyMissionCount件のデイリー報酬を受け取れます',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _finishing
                        ? null
                        : () => _finishAndPop(requestedAction: 'missions'),
                    child: const Text('受取へ'),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
          if (widget.isCpuBattle) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _finishing
                        ? null
                        : () => _finishAndPop(requestedAction: 'battle'),
                    icon: const Icon(Icons.replay),
                    label: const Text('もう一戦'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFD700),
                      side: BorderSide(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (_canOpenGacha) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _finishing
                          ? null
                          : () => _finishAndPop(requestedAction: 'gacha'),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('ガチャ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orangeAccent,
                        side: BorderSide(
                          color: Colors.orangeAccent.withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _finishing ? null : _copyResultSummary,
              icon: const Icon(Icons.copy),
              label: const Text('結果をコピー'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ホームに戻るボタン
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _finishing ? null : _finishAndPop,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    won ? const Color(0xFF00B894) : const Color(0xFF2D3748),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'ホームに戻る',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
