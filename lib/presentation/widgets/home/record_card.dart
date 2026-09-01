import 'package:flutter/material.dart';

/// ホームの戦績カード。バトル数・勝利数・勝率を表示する。
class RecordCard extends StatelessWidget {
  final int battles;
  final int wins;

  const RecordCard({
    super.key,
    required this.battles,
    required this.wins,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _RecordItem(label: 'バトル数', value: '$battles', icon: Icons.sports_mma),
          Container(width: 1, height: 30, color: Colors.white10),
          _RecordItem(label: '勝利数', value: '$wins', icon: Icons.emoji_events),
          Container(width: 1, height: 30, color: Colors.white10),
          _RecordItem(
            label: '勝率',
            value: battles > 0
                ? '${(wins / battles * 100).toStringAsFixed(0)}%'
                : '-',
            icon: Icons.trending_up,
          ),
        ],
      ),
    );
  }
}

class _RecordItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _RecordItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white30, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}
