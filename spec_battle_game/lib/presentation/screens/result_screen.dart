import 'package:flutter/material.dart';
import '../../data/local_storage_service.dart';
import '../../domain/models/character.dart';
import '../../domain/services/battle_engine.dart';
import '../../domain/services/experience_service.dart';
import '../widgets/pixel_character.dart';

/// バトルリザルト画面
class ResultScreen extends StatefulWidget {
  final BattleResult result;
  final Character player;
  final Character enemy;

  const ResultScreen({
    super.key,
    required this.result,
    required this.player,
    required this.enemy,
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

    // バトル結果を永続化する（Futureを保持して遷移前に完了を保証）
    _saveFuture = _saveResult();
  }

  /// バトル結果をLocalStorageに保存する
  Future<void> _saveResult() async {
    final storage = LocalStorageService();
    await storage.init();
    final expService = ExperienceService(storage);

    // 経験値を加算して保存（レベルアップ判定）
    final currentExp = expService.loadExperience();
    _levelBefore = currentExp.level;
    await expService.addExp(currentExp, widget.result.expGained);
    final newExp = expService.loadExperience();
    _levelAfter = newExp.level;

    // 戦績を記録
    await expService.recordBattle(widget.result.playerWon);

    if (mounted) setState(() {});
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
    return Padding(
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
          Text(
            won ? '🎉 勝利！' : '💀 敗北…',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: won ? const Color(0xFFFFD700) : const Color(0xFFE17055),
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
                        PixelCharacter(
                            character: widget.player, size: 60),
                        const SizedBox(height: 8),
                        Text(widget.player.name,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
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
                        Text(widget.enemy.name,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                _infoRow('ターン数', '${widget.result.turnsPlayed}'),
                _infoRow('獲得経験値', '+${widget.result.expGained} EXP'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                );
              },
            ),
          ],

          const SizedBox(height: 32),
          // ホームに戻るボタン
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // 保存完了を待ってからホーム画面に戻る
                await _saveFuture;
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: won ? const Color(0xFF00B894) : const Color(0xFF2D3748),
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
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
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
