import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/models/character.dart';
import '../../domain/enums/element_type.dart';
import '../../domain/enums/battle_tactic.dart';
import '../../domain/services/battle_engine.dart';
import '../../data/sound_service.dart';
import '../widgets/pixel_character.dart';
import '../widgets/stat_bar.dart';
import '../widgets/damage_popup.dart';
import '../widgets/skill_effect_overlay.dart';
import '../../domain/services/enemy_generator.dart';
import 'result_screen.dart';

/// バトル画面 — 自動バトルのアニメーション表示
class BattleScreen extends StatefulWidget {
  final Character player;
  final Character enemy;
  final String? enemyDeviceId;
  final EnemyDifficulty enemyDifficulty;
  final bool isCpuBattle;
  final BattleTactic playerTactic;

  const BattleScreen({
    super.key,
    required this.player,
    required this.enemy,
    this.enemyDeviceId,
    this.enemyDifficulty = EnemyDifficulty.normal,
    this.isCpuBattle = true,
    this.playerTactic = BattleTactic.balanced,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with TickerProviderStateMixin {
  late BattleResult _result;
  List<BattleLogEntry> _displayedLog = [];
  int _currentLogIndex = 0;
  bool _supportSelected = false;
  bool _battleComplete = false;

  late Character _currentPlayer;
  late Character _currentEnemy;

  // アニメーション・演出用
  final List<Widget> _popups = [];
  Widget? _currentSkillOverlay;
  int _currentTurn = 1;

  // サウンドサービス
  final SoundService _sound = SoundService();
  final List<double> _playbackSpeeds = const [1.0, 1.5, 2.0, 3.0];
  double _playbackSpeed = 1.0;

  late AnimationController _shakeController;
  late AnimationController _flashController;
  late Animation<double> _shakeAnimation;
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentPlayer = widget.player;
    _currentEnemy = widget.enemy;

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // バトル開始前にプレイヤーの支援コマンド選択を待つ
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _flashController.dispose();
    _logScrollController.dispose();
    _sound.stopBgmImmediate(); // 画面離脱時にBGMを確実に停止
    super.dispose();
  }

  void _runBattle(BattleSupportCommand supportCommand) {
    setState(() {
      _supportSelected = true;
    });

    final engine = BattleEngine();
    _result = engine.executeBattle(
      widget.player,
      widget.enemy,
      playerTactic: widget.playerTactic,
      supportCommand: supportCommand,
    );

    // バトルBGM + 開始SEを再生
    _sound.playBgm();
    _sound.playBattleStart();

    // ログを順次表示するアニメーション
    _showNextLog();
  }

  /// バトルログを順次再生する（イテレーティブ実装）
  Future<void> _showNextLog() async {
    while (_currentLogIndex < _result.log.length) {
      if (!mounted) return;

      final entry = _result.log[_currentLogIndex];

      // ターン更新の検知
      if (entry.message.contains('--- ターン')) {
        final match = RegExp(r'ターン (\d+)').firstMatch(entry.message);
        if (match != null) {
          setState(() {
            _currentTurn = int.parse(match.group(1)!);
          });
        }
      }

      // アクションに応じた効果音を再生
      if (entry.actionType == BattleActionType.attack) {
        _sound.playAttack();
      } else if (entry.actionType == BattleActionType.defend) {
        if (entry.healing > 0) {
          _sound.playHeal();
        } else {
          _sound.playDefend();
        }
      }

      // スキル発動時のエフェクト待機＋効果音
      if (entry.actionType == BattleActionType.skill &&
          !entry.message.contains('防御力が上がった')) {
        final isPlayerAction = entry.actorName == _currentPlayer.name ||
            entry.actorName == widget.player.name;
        final actor = isPlayerAction ? _currentPlayer : _currentEnemy;

        if (entry.healing > 0) {
          _sound.playHeal();
        } else {
          _sound.playSkill();
        }

        await _showSkillEffect(entry.actionName, actor.element);
      }

      if (!mounted) return;

      setState(() {
        _displayedLog.add(entry);

        final isPlayerActor = entry.actorName == _currentPlayer.name ||
            entry.actorName == widget.player.name;

        // ダメージ演出
        if (entry.damage > 0) {
          _shakeController.forward().then((_) => _shakeController.reverse());
          _flashController.forward().then((_) => _flashController.reverse());

          if (isPlayerActor) {
            final newHp = max(0, _currentEnemy.currentStats.hp - entry.damage);
            _currentEnemy = _currentEnemy.withHp(newHp);
            _addDamagePopup(entry.damage, false, entry.isCritical, false);
          } else {
            final newHp = max(0, _currentPlayer.currentStats.hp - entry.damage);
            _currentPlayer = _currentPlayer.withHp(newHp);
            _addDamagePopup(entry.damage, true, entry.isCritical, false);
          }
        }
        // 回復演出
        else if (entry.healing > 0) {
          if (isPlayerActor) {
            final newHp = min(_currentPlayer.currentStats.maxHp,
                _currentPlayer.currentStats.hp + entry.healing);
            _currentPlayer = _currentPlayer.withHp(newHp);
            _addDamagePopup(entry.healing, true, false, true);
          } else {
            final newHp = min(_currentEnemy.currentStats.maxHp,
                _currentEnemy.currentStats.hp + entry.healing);
            _currentEnemy = _currentEnemy.withHp(newHp);
            _addDamagePopup(entry.healing, false, false, true);
          }
        }
      });
      _scrollLogToBottom();

      _currentLogIndex++;

      // 次のログまでのウェイト
      await Future.delayed(Duration(milliseconds: _logDelayMs));
    }

    // ログ再生完了
    if (mounted) {
      // バトルBGMを停止し、結果SEを再生
      await _sound.stopBgmImmediate();
      if (_result.playerWon) {
        _sound.playVictory();
      } else {
        _sound.playDefeat();
      }
      setState(() {
        _battleComplete = true;
      });
    }
  }

  void _skipToEnd() {
    // バトルBGMを停止し、結果SEを再生
    _sound.stopBgmImmediate();
    if (_result.playerWon) {
      _sound.playVictory();
    } else {
      _sound.playDefeat();
    }

    setState(() {
      _displayedLog = List.from(_result.log);
      _currentLogIndex = _result.log.length;
      _battleComplete = true;

      // 実際の最終HPを反映
      _currentPlayer = _currentPlayer.withHp(_result.finalPlayerHp);
      _currentEnemy = _currentEnemy.withHp(_result.finalEnemyHp);
    });
    _scrollLogToBottom();
  }

  void _scrollLogToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_logScrollController.hasClients) return;
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  int get _logDelayMs => (800 / _playbackSpeed).round().clamp(220, 800);
  int get _skillEffectDelayMs =>
      (1000 / _playbackSpeed).round().clamp(320, 1000);

  void _cyclePlaybackSpeed() {
    final currentIndex = _playbackSpeeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % _playbackSpeeds.length;
    SoundService().playButton();
    setState(() {
      _playbackSpeed = _playbackSpeeds[nextIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // バトルフィールド上部
                _buildBattleField(),
                // バトルログ
                Expanded(child: _buildBattleLog()),
                // ボタン
                _buildActionButtons(),
              ],
            ),
            // BGM/SEミュートボタン（右上に配置）
            Positioned(
              top: 8,
              right: 8,
              child: StatefulBuilder(
                builder: (context, setIconState) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMuteButton(
                        label: 'BGM',
                        isMuted: _sound.isBgmMuted,
                        onIcon: Icons.music_note,
                        offIcon: Icons.music_off,
                        onTap: () {
                          _sound.toggleBgmMute();
                          setIconState(() {});
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildMuteButton(
                        label: 'SE',
                        isMuted: _sound.isSeMuted,
                        onIcon: Icons.volume_up,
                        offIcon: Icons.volume_off,
                        onTap: () {
                          _sound.toggleSeMute();
                          setIconState(() {});
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            // スキルエフェクトオーバーレイ
            if (_currentSkillOverlay != null) _currentSkillOverlay!,
          ],
        ),
      ),
    );
  }

  Widget _buildBattleField() {
    final screenSize = MediaQuery.sizeOf(context);
    // 画面高さの38%を基準に、最小200・最大320の範囲で制約
    final fieldHeight = (screenSize.height * 0.38).clamp(200.0, 320.0);
    // キャラサイズは画面幅の18%を基準に、最小50・最大100の範囲
    final charSize = (screenSize.width * 0.18).clamp(50.0, 100.0);
    final enemySpriteTopPadding = (charSize * 0.52).clamp(28.0, 42.0);

    return Container(
      height: fieldHeight,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1B2838),
            Color(0xFF0D1B2A),
          ],
        ),
      ),
      child: Stack(
        children: [
          // ターン表示
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                'TURN $_currentTurn',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Column(
            children: [
              // 上部: 敵キャラクター
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildCharacterInfo(_currentEnemy, false)),
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        final isEnemyHit = _displayedLog.isNotEmpty &&
                            _displayedLog.last.damage > 0 &&
                            (_displayedLog.last.actorName ==
                                    _currentPlayer.name ||
                                _displayedLog.last.actorName ==
                                    widget.player.name);
                        return Transform.translate(
                          offset:
                              Offset(isEnemyHit ? _shakeAnimation.value : 0, 0),
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: enemySpriteTopPadding,
                              right: 4,
                            ),
                            child: PixelCharacter(
                                character: _currentEnemy,
                                size: charSize,
                                flipHorizontal: true),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 下部: プレイヤーキャラクター
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        final isPlayerHit = _displayedLog.isNotEmpty &&
                            _displayedLog.last.damage > 0 &&
                            _displayedLog.last.actorName !=
                                _currentPlayer.name &&
                            _displayedLog.last.actorName != widget.player.name;
                        return Transform.translate(
                          offset: Offset(
                              isPlayerHit ? -_shakeAnimation.value : 0, 0),
                          child: PixelCharacter(
                              character: _currentPlayer, size: charSize),
                        );
                      },
                    ),
                    Expanded(child: _buildCharacterInfo(_currentPlayer, true)),
                  ],
                ),
              ),
            ],
          ),
          // ダメージポップアップレイヤー
          ..._popups,
        ],
      ),
    );
  }

  Widget _buildCharacterInfo(Character char, bool isPlayer) {
    final stats = char.currentStats;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment:
            isPlayer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            char.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Lv.${char.level}  ${elementName(char.element)}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          StatBar(
            label: 'HP',
            value: stats.hpPercentage,
            color: stats.hpPercentage > 0.5
                ? Colors.greenAccent
                : stats.hpPercentage > 0.2
                    ? Colors.orangeAccent
                    : Colors.redAccent,
            trailingText: '${stats.hp}/${stats.maxHp}',
            height: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildBattleLog() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListView.builder(
        controller: _logScrollController,
        itemCount: _displayedLog.length,
        itemBuilder: (context, index) {
          final entry = _displayedLog[index];
          final baseColor = entry.damage > 0
              ? Colors.redAccent[100]!
              : entry.healing > 0
                  ? Colors.greenAccent[100]!
                  : Colors.white70;

          // アクションタイプに応じたプレフィックスアイコン
          String prefix = '';
          if (entry.actionType == BattleActionType.attack) prefix = '⚔️ ';
          if (entry.actionType == BattleActionType.defend) prefix = '🛡️ ';
          if (entry.actionType == BattleActionType.skill) prefix = '✨ ';

          final fullMessage = prefix + entry.message;

          // スキル名がある場合は金色ハイライト
          if (entry.actionType == BattleActionType.skill &&
              entry.actionName.isNotEmpty) {
            final parts = fullMessage.split(entry.actionName);
            if (parts.length == 2) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: baseColor, fontSize: 13),
                    children: [
                      TextSpan(text: parts[0]),
                      TextSpan(
                        text: entry.actionName,
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: parts[1]),
                    ],
                  ),
                ),
              );
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              fullMessage,
              style: TextStyle(color: baseColor, fontSize: 13),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    if (!_supportSelected) {
      return _buildSupportCommandPicker();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (!_battleComplete) ...[
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: _cyclePlaybackSpeed,
                icon: const Icon(Icons.speed, size: 18),
                label: Text(
                  'x${_playbackSpeed.toStringAsFixed(_playbackSpeed == 1.0 ? 0 : 1)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFD700),
                  side: BorderSide(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor:
                      const Color(0xFFFFD700).withValues(alpha: 0.06),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: ElevatedButton(
                onPressed: _skipToEnd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D3748),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'スキップ ▶▶',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
          if (_battleComplete)
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  final nextAction = await Navigator.of(context).push<String?>(
                    MaterialPageRoute(
                      builder: (context) => ResultScreen(
                        result: _result,
                        player: widget.player,
                        enemy: widget.enemy,
                        enemyDeviceId: widget.enemyDeviceId,
                        enemyDifficulty: widget.enemyDifficulty,
                        isCpuBattle: widget.isCpuBattle,
                      ),
                    ),
                  );
                  if (mounted) {
                    Navigator.of(context).pop(nextAction);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _result.playerWon
                      ? const Color(0xFF00B894)
                      : const Color(0xFFE17055),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'リザルトへ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSupportCommandPicker() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'サポートコマンドを選択',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _supportCommandButton(
                  command: BattleSupportCommand.none,
                  icon: Icons.play_arrow,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _supportCommandButton(
                  command: BattleSupportCommand.overdrive,
                  icon: Icons.flash_on,
                  color: const Color(0xFFFFD700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _supportCommandButton(
                  command: BattleSupportCommand.barrier,
                  icon: Icons.shield,
                  color: const Color(0xFF00CEC9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _supportCommandButton({
    required BattleSupportCommand command,
    required IconData icon,
    required Color color,
  }) {
    return OutlinedButton(
      onPressed: () {
        SoundService().playButton();
        _runBattle(command);
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        backgroundColor: color.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 4),
          Text(
            command.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            command.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  /// BGM/SE共通のミュートトグルボタン
  Widget _buildMuteButton({
    required String label,
    required bool isMuted,
    required IconData onIcon,
    required IconData offIcon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMuted ? offIcon : onIcon,
              color: Colors.white54,
              size: 18,
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ダメージポップアップを追加
  void _addDamagePopup(
      int value, bool isPlayerDamage, bool isCritical, bool isHealing) {
    if (!mounted) return;

    final key = UniqueKey();
    final random = Random();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final offsetX =
        random.nextDouble() * (screenWidth * 0.15) - (screenWidth * 0.075);
    final baseOffset = screenWidth * 0.15;

    final popup = Positioned(
      key: key,
      top: isPlayerDamage ? null : baseOffset + random.nextDouble() * 20,
      bottom: isPlayerDamage ? baseOffset + random.nextDouble() * 20 : null,
      right: isPlayerDamage ? baseOffset + offsetX : null,
      left: isPlayerDamage ? null : baseOffset + offsetX,
      child: DamagePopup(
        value: value,
        isCritical: isCritical,
        isHealing: isHealing,
        onComplete: () {
          if (mounted) {
            setState(() {
              _popups.removeWhere((w) => w.key == key);
            });
          }
        },
      ),
    );

    setState(() {
      _popups.add(popup);
    });
  }

  /// スキルエフェクトを表示
  Future<void> _showSkillEffect(String skillName, ElementType element) async {
    if (!mounted) return;

    setState(() {
      _currentSkillOverlay = SkillEffectOverlay(
        skillName: skillName,
        element: element,
        onComplete: () {
          if (mounted) {
            setState(() {
              _currentSkillOverlay = null;
            });
          }
        },
      );
    });

    // エフェクトのピークまで少し待つ
    await Future.delayed(Duration(milliseconds: _skillEffectDelayMs));
  }
}
