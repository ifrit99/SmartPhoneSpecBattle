import 'package:flutter/material.dart';

/// ホームのデイリー報酬カード。ログイン／バトル報酬の受取状況を表示する。
class DailyRewardCard extends StatelessWidget {
  final bool loginClaimed;
  final bool battleClaimed;
  final int cycleDay;
  final int streakCycleDays;
  final int nextBonus;
  final int loginRewardGems;
  final int battleRewardGems;

  const DailyRewardCard({
    super.key,
    required this.loginClaimed,
    required this.battleClaimed,
    required this.cycleDay,
    required this.streakCycleDays,
    required this.nextBonus,
    required this.loginRewardGems,
    required this.battleRewardGems,
  });

  @override
  Widget build(BuildContext context) {
    final cycleProgress =
        cycleDay == 0 ? 0.0 : cycleDay / streakCycleDays;

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
                    ? '0/$streakCycleDays日'
                    : '$cycleDay/$streakCycleDays日',
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
                child: _DailyRewardItem(
                  icon: Icons.wb_sunny,
                  label: 'ログイン',
                  gems: loginRewardGems,
                  claimed: loginClaimed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DailyRewardItem(
                  icon: Icons.flash_on,
                  label: 'バトル1回',
                  gems: battleRewardGems,
                  claimed: battleClaimed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyRewardItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int gems;
  final bool claimed;

  const _DailyRewardItem({
    required this.icon,
    required this.label,
    required this.gems,
    required this.claimed,
  });

  @override
  Widget build(BuildContext context) {
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
}
