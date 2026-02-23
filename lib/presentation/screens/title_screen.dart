import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/sound_service.dart';
import 'home_screen.dart';

/// タイトル画面
/// アプリ起動時に表示され、タップでホーム画面へ遷移する。
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen>
    with TickerProviderStateMixin {
  /// ロゴのフェードイン＋スケールアニメーション
  late AnimationController _logoController;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;

  /// サブタイトルのフェードイン
  late AnimationController _subtitleController;
  late Animation<double> _subtitleOpacity;

  /// 「タップしてスタート」の点滅アニメーション
  late AnimationController _tapController;
  late Animation<double> _tapOpacity;

  /// 背景パーティクル用
  late AnimationController _particleController;

  /// パーティクルデータ
  final List<_Particle> _particles = [];
  final _random = Random();

  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    // パーティクル生成
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.2 + _random.nextDouble() * 0.6,
        size: 1.0 + _random.nextDouble() * 2.5,
        opacity: 0.1 + _random.nextDouble() * 0.4,
      ));
    }

    // ロゴアニメーション（0.0s → 1.2s）
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // サブタイトルアニメーション（0.8s遅延で開始）
    _subtitleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.easeIn),
    );

    // 「タップしてスタート」の点滅（ループ）
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _tapOpacity = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );

    // パーティクルアニメーション（ループ）
    _particleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // BGM再生開始
    SoundService().playTitleBgm();

    // 演出シーケンスの開始
    _startSequence();
  }

  Future<void> _startSequence() async {
    // ロゴ登場
    _logoController.forward();

    // 0.8秒後にサブタイトル表示
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _subtitleController.forward();

    // さらに0.6秒後に「タップしてスタート」を点滅開始
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _tapController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _subtitleController.dispose();
    _tapController.dispose();
    _particleController.dispose();
    SoundService().stopBgm(); // 念のため破棄時にも停止を試みる
    super.dispose();
  }

  void _onTap() {
    if (_navigating) return;
    _navigating = true;

    SoundService().playButton();
    SoundService().stopBgm(); // BGMをフェードアウト停止

    // ホーム画面へ遷移（タイトル画面はスタックから除去）
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Stack(
          children: [
            // 背景パーティクル
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) => CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _particleController.value,
                ),
              ),
            ),

            // メインコンテンツ
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // タイトルロゴ
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, _) => Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: _buildLogo(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // サブタイトル
                    AnimatedBuilder(
                      animation: _subtitleController,
                      builder: (context, _) => Opacity(
                        opacity: _subtitleOpacity.value,
                        child: const Text(
                          'スマホのスペックで戦え',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white38,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // タップしてスタート
                    AnimatedBuilder(
                      animation: _tapController,
                      builder: (context, _) => Opacity(
                        opacity: _tapController.isAnimating
                            ? _tapOpacity.value
                            : 0.0,
                        child: const Text(
                          'TAP TO START',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            letterSpacing: 6,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),

                    // バージョン表記
                    const Text(
                      'v0.1.0',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// タイトルロゴ部分
  Widget _buildLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // アイコン
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6C5CE7), Color(0xFF00B894)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.flash_on,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),

        // タイトル文字
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFF74B9FF), Color(0xFF00B894)],
          ).createShader(bounds),
          child: const Text(
            'SPEC BATTLE',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 6,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 背景パーティクルのデータとペインタ
// ─────────────────────────────────────────────

class _Particle {
  double x;
  double y;
  final double speed;
  final double size;
  final double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // 下から上へゆっくり浮遊するパーティクル
      final y = (p.y - progress * p.speed) % 1.0;
      final paint = Paint()
        ..color = const Color(0xFF6C5CE7).withValues(alpha: p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
