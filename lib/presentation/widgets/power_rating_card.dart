import 'package:flutter/material.dart';
import '../../domain/services/power_rating_service.dart';
import 'stat_bar.dart';

/// ティアごとのテーマカラー
Color powerTierColor(PowerTier tier) {
  return switch (tier) {
    PowerTier.ss => const Color(0xFFFFD700),
    PowerTier.s => const Color(0xFFFF6B35),
    PowerTier.a => const Color(0xFF2ED573),
    PowerTier.b => const Color(0xFF54A0FF),
    PowerTier.c => const Color(0xFF9E9E9E),
    PowerTier.d => const Color(0xFF8D6E63),
  };
}

/// ホーム画面に表示する戦闘力カード。
/// スコア・ティア・推定上位%を一目で把握でき、タップでランキング詳細を開く。
class PowerRatingCard extends StatelessWidget {
  final PowerRating rating;

  const PowerRatingCard({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    final tierColor = powerTierColor(rating.tier);
    // ゲージは「強いほど満ちる」（上位0% = 満タン）
    final strength = (1 - rating.topPercent / 100).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => PowerRankingSheet.show(context, rating),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2838),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tierColor.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: tierColor.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                const Text(
                  'SPEC POWER',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Text(
                  rating.tier.verdict,
                  style: TextStyle(
                    fontSize: 11,
                    color: tierColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ティアバッジ
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tierColor, width: 2),
                  ),
                  child: Text(
                    rating.tier.label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: tierColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // スコア
                Text(
                  '${rating.score}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                // 相対位置
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '推定上位${rating.topPercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: tierColor,
                      ),
                    ),
                    Text(
                      '全${rating.populationSize}端末中 ${rating.rank}位',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            StatBar(
              value: strength,
              color: tierColor,
              height: 6,
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'タップでランキングを見る',
                  style: TextStyle(fontSize: 10, color: Colors.white38),
                ),
                Icon(Icons.chevron_right, size: 12, color: Colors.white38),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 戦闘力ランキングの詳細シート（登場端末との比較リスト）
class PowerRankingSheet extends StatelessWidget {
  final PowerRating rating;

  const PowerRankingSheet({super.key, required this.rating});

  static Future<void> show(BuildContext context, PowerRating rating) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B2838),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PowerRankingSheet(rating: rating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = powerTierColor(rating.tier);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '戦闘力ランキング',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'あなたのスマホは全${rating.populationSize}端末中 '
                '${rating.rank}位（推定上位${rating.topPercent.toStringAsFixed(0)}%）',
                style: TextStyle(fontSize: 13, color: tierColor),
              ),
              const SizedBox(height: 4),
              const Text(
                '※ ゲーム内登場端末とのローカル推定比較です。'
                '世界ランキングは今後のアップデートで対応予定。',
                style: TextStyle(fontSize: 10, color: Colors.white38),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: rating.entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final entry = rating.entries[index];
                    return _rankingRow(index + 1, entry, tierColor);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rankingRow(int position, PowerRankingEntry entry, Color tierColor) {
    final highlight = entry.isPlayer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? tierColor.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: highlight ? Border.all(color: tierColor) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$position位',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: highlight ? tierColor : Colors.white54,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.isPlayer ? 'あなたのスマホ' : entry.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                color: highlight ? Colors.white : Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'PWR ${entry.score}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: highlight ? tierColor : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
