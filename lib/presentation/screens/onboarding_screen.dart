import 'package:flutter/material.dart';
import '../../data/local_storage_service.dart';
import 'home_screen.dart';

/// 初回起動時に表示するオンボーディング画面（3ページ構成）
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 3;

  /// 各ページのデータ
  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      icon: Icons.smartphone,
      gradientColors: [Color(0xFF6C5CE7), Color(0xFF74B9FF)],
      title: 'あなたのスマホが\nキャラクターに！',
      description: 'このゲームでは、あなたが今使っている\nスマートフォンがバトルキャラクターになります。',
    ),
    _OnboardingPageData(
      icon: Icons.auto_awesome,
      gradientColors: [Color(0xFF00B894), Color(0xFF55EFC4)],
      title: 'スペックが\n能力値に変わる',
      description: 'CPU → 攻撃力、RAM → HP、\nストレージ → 防御力、バッテリー → 素早さ\nに変換されてバトルします。',
    ),
    _OnboardingPageData(
      icon: Icons.flash_on,
      gradientColors: [Color(0xFFFFD700), Color(0xFFFFA502)],
      title: 'まずは1回\nバトルしてみよう！',
      description: '難しい操作は不要。\nバトルはオートで進みます。\nさっそく始めましょう！',
    ),
  ];

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skip() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    await LocalStorageService().setOnboardingCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Column(
          children: [
            // スキップボタン
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 16),
                child: TextButton(
                  onPressed: _skip,
                  child: const Text(
                    'スキップ',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

            // ページコンテンツ
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalPages,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // ページインジケーター
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF6C5CE7)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // 次へ / はじめるボタン
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    shadowColor: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                  ),
                  child: Text(
                    _currentPage == _totalPages - 1 ? 'はじめる！' : '次へ',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPageData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // アイコン
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: data.gradientColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: data.gradientColors[0].withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              data.icon,
              color: Colors.white,
              size: 56,
            ),
          ),
          const SizedBox(height: 40),

          // タイトル
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.3,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),

          // 説明文
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white60,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// オンボーディングページのデータクラス
class _OnboardingPageData {
  final IconData icon;
  final List<Color> gradientColors;
  final String title;
  final String description;

  const _OnboardingPageData({
    required this.icon,
    required this.gradientColors,
    required this.title,
    required this.description,
  });
}
