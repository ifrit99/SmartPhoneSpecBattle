import 'package:flutter/material.dart';

import '../../../domain/services/season_pass_service.dart';

/// ホームのシーズンパスカード。SP進捗と報酬チップを表示する。
class SeasonPassCard extends StatelessWidget {
  final SeasonPassSnapshot pass;
  final VoidCallback onClaim;

  const SeasonPassCard({
    super.key,
    required this.pass,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final nextReward = pass.nextReward;
    final progress = nextReward?.progress ?? 1.0;
    final progressText = nextReward == null
        ? '${pass.xp} SP'
        : '${pass.xp.clamp(0, nextReward.definition.requiredXp)}/${nextReward.definition.requiredXp} SP';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF55EFC4).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech,
                  color: Color(0xFF55EFC4), size: 19),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'シーズンパス ${pass.seasonId}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '残り${pass.daysRemaining}日',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                progressText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF55EFC4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pass.completed
                ? '今月の報酬はすべて受取済みです。'
                : pass.claimableCount > 0
                    ? '${pass.claimableCount}件のシーズン報酬を受け取れます。'
                    : nextReward == null
                        ? 'バトルでシーズンポイントを集めて報酬を解放します。'
                        : '次: ${nextReward.definition.title}（${_rewardText(nextReward.definition)}）',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pass.rewards
                .map(
                  (reward) => _SeasonRewardChip(
                    requiredXp: reward.definition.requiredXp,
                    claimed: reward.claimed,
                    unlocked: reward.unlocked,
                  ),
                )
                .toList(),
          ),
          if (pass.claimableCount > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onClaim,
                icon: const Icon(Icons.redeem, size: 18),
                label: const Text('シーズン報酬を受け取る'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF55EFC4),
                  foregroundColor: const Color(0xFF0D1B2A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _rewardText(SeasonPassRewardDefinition definition) {
    final parts = <String>[];
    if (definition.coinsReward > 0) {
      parts.add('+${definition.coinsReward} Coin');
    }
    if (definition.gemsReward > 0) {
      parts.add('+${definition.gemsReward} Gems');
    }
    return parts.join(' / ');
  }
}

class _SeasonRewardChip extends StatelessWidget {
  final int requiredXp;
  final bool claimed;
  final bool unlocked;

  const _SeasonRewardChip({
    required this.requiredXp,
    required this.claimed,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    final color = claimed
        ? Colors.white30
        : unlocked
            ? const Color(0xFF55EFC4)
            : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: unlocked ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            claimed ? Icons.check_circle : Icons.lock_open,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            '${requiredXp}SP',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
