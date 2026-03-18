import 'package:flutter/material.dart';

/// 初回バトル完了後に表示する次アクション案内ダイアログ
class FirstBattleCompleteDialog extends StatelessWidget {
  const FirstBattleCompleteDialog({super.key});

  /// ダイアログを表示するユーティリティメソッド
  /// 返り値: 'gacha', 'friend', または null（閉じた場合）
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const FirstBattleCompleteDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1B2838),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダーアイコン
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA502)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(
                Icons.celebration,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'はじめてのバトル完了！',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '次はこんなことができます',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 20),

            // ガチャ案内
            _buildActionTile(
              context,
              icon: Icons.star,
              color: Colors.orangeAccent,
              title: 'ガチャを引く',
              description: 'コインで新しいキャラクターを\n手に入れよう',
              actionKey: 'gacha',
            ),
            const SizedBox(height: 12),

            // フレンド対戦案内
            _buildActionTile(
              context,
              icon: Icons.people,
              color: Colors.greenAccent,
              title: 'フレンドに共有',
              description: 'URLを送って友だちの\nスマホと対戦しよう',
              actionKey: 'friend',
            ),
            const SizedBox(height: 20),

            // 閉じるボタン
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text(
                'あとで',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required String actionKey,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).pop(actionKey),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
