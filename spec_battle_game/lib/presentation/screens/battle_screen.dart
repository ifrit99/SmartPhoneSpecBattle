import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/models/character.dart';
import '../../domain/enums/element_type.dart';
import '../../domain/services/battle_engine.dart';
import '../../data/sound_service.dart';
import '../widgets/pixel_character.dart';
import '../widgets/stat_bar.dart';
import '../widgets/damage_popup.dart';
import '../widgets/skill_effect_overlay.dart';
import 'result_screen.dart';

/// バトル画面 — 自動バトルのアニメーション表示
class BattleScreen extends StatefulWidget {
  final Character player;
  final Character enemy;
  final String? enemyDeviceName;

  const BattleScreen({
    super.key, 
    required this.player, 
    required this.enemy,
    this.enemyDeviceName,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with TickerProviderStateMixin {
  late BattleResult _result;
  List<BattleLogEntry> _displayedLog = [];
  int _currentLogIndex = 0;
  bool _battleComplete = false;

  late Character _currentPlayer;
  late Character _currentEnemy;

  // アニメーション・演出用
  final List<Widget> _popups = [];
  Widget? _currentSkillOverlay;
  int _currentTurn = 1;

  // サウンドサービス
  final SoundService _sound = SoundService();

  late AnimationController _shakeController;
  late AnimationController _flashController;
  late Animation<double> _shakeAnimation;

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

    // バトル実行
    _runBattle();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  void _runBattle() {
    final engine = BattleEngine();
    _result = engine.executeBattle(widget.player, widget.enemy);

    // バトル開始音を再生
    _sound.playBattleStart();

    // ログを順次表示するアニメーション
    _showNextLog();
  }

  Future<void> _showNextLog() async {
    if (_currentLogIndex >= _result.log.length) {
      if (mounted) {
        // 勝敗に応じた効果音を再生
        if (_result.playerWon) {
          _sound.playVictory();
        } else {
          _sound.playDefeat();
        }
        setState(() {
          _battleComplete = true;
        });
      }
      return;
    }

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
    if (entry.actionType == BattleActionType.skill && !entry.message.contains('防御力が上がった')) {
      // 防御バフ以外（攻撃・回復）の場合にエフェクト表示
      final isPlayerAction = entry.actorName == _currentPlayer.name ||
          entry.actorName == widget.player.name;
      final actor = isPlayerAction ? _currentPlayer : _currentEnemy;

      // スキル種別に応じた効果音
      if (entry.healing > 0) {
        _sound.playHeal();
      } else {
        _sound.playSkill();
      }

      // 簡易的にアクターの属性を使用
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

        // HPバーの更新 & ポップアップ
        if (isPlayerActor) {
          // 敵がダメージ
          final newHp = max(0, _currentEnemy.currentStats.hp - entry.damage);
          _currentEnemy = _currentEnemy.withHp(newHp);
          _addDamagePopup(entry.damage, false, entry.isCritical, false);
        } else {
          // プレイヤーがダメージ
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

    _currentLogIndex++;
    
    // 次のログまでのウェイト
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) _showNextLog();
  }

  void _skipToEnd() {
    setState(() {
      _displayedLog = List.from(_result.log);
      _currentLogIndex = _result.log.length;
      _battleComplete = true;

      // 実際の最終HPを反映
      _currentPlayer = _currentPlayer.withHp(_result.finalPlayerHp);
      _currentEnemy = _currentEnemy.withHp(_result.finalEnemyHp);
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
            // ミュートボタン（右上に配置）
            Positioned(
              top: 8,
              right: 8,
              child: StatefulBuilder(
                builder: (context, setIconState) {
                  return GestureDetector(
                    onTap: () {
                      _sound.toggleMute();
                      setIconState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _sound.isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ),
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
    return Container(
      height: 280,
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
                            (_displayedLog.last.actorName == _currentPlayer.name ||
                             _displayedLog.last.actorName == widget.player.name);
                        return Transform.translate(
                          offset: Offset(isEnemyHit ? _shakeAnimation.value : 0, 0),
                          child: PixelCharacter(
                              character: _currentEnemy,
                              size: 80,
                              flipHorizontal: true),
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
                            _displayedLog.last.actorName != _currentPlayer.name &&
                            _displayedLog.last.actorName != widget.player.name;
                        return Transform.translate(
                          offset: Offset(isPlayerHit ? -_shakeAnimation.value : 0, 0),
                          child: PixelCharacter(
                              character: _currentPlayer, size: 80),
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
          ),
          const SizedBox(height: 4),
          Text(
            'Lv.${char.level}  ${elementName(char.element)}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
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
        reverse: true,
        itemCount: _displayedLog.length,
        itemBuilder: (context, index) {
          final entry = _displayedLog[_displayedLog.length - 1 - index];
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
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (!_battleComplete)
            Expanded(
              child: ElevatedButton(
                onPressed: _skipToEnd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D3748),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('スキップ ▶▶',
                    style: TextStyle(color: Colors.white70)),
              ),
            ),
          if (_battleComplete)
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => ResultScreen(
                        result: _result,
                        player: widget.player,
                        enemy: widget.enemy,
                        enemyDeviceName: widget.enemyDeviceName,
                      ),
                    ),
                  );
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

  /// ダメージポップアップを追加
  void _addDamagePopup(int value, bool isPlayerDamage, bool isCritical, bool isHealing) {
    if (!mounted) return;
    
    final key = UniqueKey();
    final random = Random();
    final offsetX = random.nextDouble() * 60 - 30;
    
    // 画面サイズに対する相対位置の調整 (Container height=280内)
    // 敵: Top付近, プレイヤー: Bottom付近
    
    final widget = Positioned(
      key: key,
      top: isPlayerDamage ? null : 60 + random.nextDouble() * 20,
      bottom: isPlayerDamage ? 60 + random.nextDouble() * 20 : null,
      right: isPlayerDamage ? 60 + offsetX : null, // プレイヤーは右寄り
      left: isPlayerDamage ? null : 60 + offsetX, // 敵は左寄り
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
      _popups.add(widget);
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
    await Future.delayed(const Duration(milliseconds: 1000));
  }
}
