import 'package:flutter/material.dart';

import '../../../domain/services/daily_mission_service.dart';

/// ホームのデイリーミッションカード。進捗と受取ボタンを表示する。
class DailyMissionCard extends StatelessWidget {
  final List<DailyMissionSnapshot> missions;
  final void Function(String id) onClaim;
  final VoidCallback onClaimAll;

  const DailyMissionCard({
    super.key,
    required this.missions,
    required this.onClaim,
    required this.onClaimAll,
  });

  @override
  Widget build(BuildContext context) {
    final completed = missions.where((mission) => mission.completed).length;
    final claimable = missions.where((mission) => mission.claimable).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00CEC9).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt, color: Color(0xFF00CEC9), size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '今日のミッション',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (claimable > 1) ...[
                SizedBox(
                  height: 30,
                  child: TextButton(
                    onPressed: onClaimAll,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFFD700),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('一括受取'),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                '$completed/${missions.length}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            claimable > 0 ? '$claimable件の報酬を受け取れます' : 'バトル・勝利・ガチャで毎日報酬を回収',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...missions.map(
            (mission) => _DailyMissionItem(
              mission: mission,
              onClaim: onClaim,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyMissionItem extends StatelessWidget {
  final DailyMissionSnapshot mission;
  final void Function(String id) onClaim;

  const _DailyMissionItem({
    required this.mission,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final definition = mission.definition;
    final color = mission.claimed
        ? Colors.white24
        : mission.completed
            ? const Color(0xFFFFD700)
            : const Color(0xFF00CEC9);
    final progress = mission.progress.clamp(0, definition.target).toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(
              mission.claimed
                  ? Icons.check_circle
                  : mission.completed
                      ? Icons.redeem
                      : Icons.radio_button_unchecked,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: mission.progressRatio,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$progress/${definition.target}  ${_rewardText(definition)}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 34,
              child: ElevatedButton(
                onPressed: mission.claimable
                    ? () => onClaim(definition.id)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white.withValues(
                    alpha: 0.08,
                  ),
                  disabledForegroundColor: Colors.white30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(
                  mission.claimed
                      ? '済'
                      : mission.completed
                          ? '受取'
                          : '未達',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _rewardText(DailyMissionDefinition definition) {
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
