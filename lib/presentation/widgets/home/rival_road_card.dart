import 'package:flutter/material.dart';

import '../../../domain/services/rival_road_service.dart';

/// ホームのライバルロードカード。進行状況と次ステージを表示する。
class RivalRoadCard extends StatelessWidget {
  final RivalRoadSnapshot road;
  final VoidCallback? onTap;

  const RivalRoadCard({
    super.key,
    required this.road,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nextStage = road.nextStage;
    final completed = road.completed;
    final bestCount = road.bestTurnsByStage.length;
    final color = completed ? const Color(0xFFFFD700) : Colors.lightBlueAccent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2838),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  completed ? Icons.emoji_events : Icons.flag,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'ライバルロード',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${road.clearedStageCount}/${road.totalStageCount}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: road.progressRatio,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 10),
            if (completed)
              Text(
                bestCount == road.totalStageCount
                    ? '全ステージ制覇済み。全ステージの最短ターン更新を狙えます。'
                    : '全ステージ制覇済み。未記録ステージの最短ターンを埋められます。',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.25,
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stage ${nextStage!.index}: ${nextStage.title} / ${nextStage.enemyDevice.deviceName}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (road.bestTurnsFor(nextStage) != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            'BEST ${road.bestTurnsFor(nextStage)}T',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${nextStage.rewardCoins}C / +${nextStage.rewardGems}G',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'BEST $bestCount/${road.totalStageCount}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
