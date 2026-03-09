import 'package:flutter/material.dart';
import 'qr_display_screen.dart';
import 'qr_scan_screen.dart';

/// フレンド対戦メニュー画面（URLシェア / URL入力の2択）
class FriendBattleMenuScreen extends StatelessWidget {
  const FriendBattleMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text('フレンド対戦', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.people, size: 80, color: Colors.greenAccent),
              const SizedBox(height: 24),
              const Text(
                '自分のキャラクターを友達にシェアして対戦しよう！',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 48),
              _buildMenuButton(
                context,
                title: 'URLでシェアする',
                subtitle: '自分のキャラの対戦URLを発行',
                icon: Icons.share,
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ShareScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildMenuButton(
                context,
                title: 'URLを入力して対戦',
                subtitle: '友達から受け取ったURLで対戦',
                icon: Icons.link,
                color: Colors.greenAccent,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const UrlInputScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        padding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        elevation: 0,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}
