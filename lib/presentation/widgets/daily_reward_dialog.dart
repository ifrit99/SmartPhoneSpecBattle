import 'package:flutter/material.dart';

import '../../domain/services/daily_reward_service.dart';

/// デイリー報酬受取時のポップアップダイアログ
class DailyRewardDialog {
  DailyRewardDialog._();

  /// ログイン報酬のポップアップを表示
  static Future<void> showLoginReward(
      BuildContext context, DailyRewardResult result) {
    final hasBonus = result.bonusGems > 0;
    return _show(
      context,
      title: 'ログインボーナス！',
      message: hasBonus
          ? '連続${result.loginStreakDays}日目のボーナス達成！'
          : '連続${result.loginStreakDays}日目。7日目で大ボーナス！',
      gems: result.gemsAwarded,
      bonusGems: result.bonusGems,
      streakText:
          'ログイン ${result.loginCycleDay}/${DailyRewardService.streakCycleDays}日目',
      icon: Icons.wb_sunny,
      iconColor: const Color(0xFFFFD700),
    );
  }

  /// バトル報酬のポップアップを表示
  static Future<void> showBattleReward(
      BuildContext context, DailyRewardResult result) {
    return _show(
      context,
      title: 'デイリーバトル報酬！',
      message: '今日の初バトル完了！',
      gems: result.gemsAwarded,
      icon: Icons.flash_on,
      iconColor: const Color(0xFF6C5CE7),
    );
  }

  static Future<void> _show(
    BuildContext context, {
    required String title,
    required String message,
    required int gems,
    int bonusGems = 0,
    String? streakText,
    required IconData icon,
    required Color iconColor,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1B2838),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // アイコン
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 16),
              // タイトル
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              if (streakText != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    streakText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // ジェム表示
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE056FD).withValues(alpha: 0.2),
                      const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE056FD).withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Text(
                          '+$gems',
                          style: const TextStyle(
                            color: Color(0xFFE056FD),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Gems',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      ],
                    ),
                    if (bonusGems > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'ストリークボーナス +$bonusGems',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // OKボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '受け取る',
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
        ),
      ),
    );
  }
}
