import 'package:flutter/material.dart';
import '../../domain/models/character.dart';
import '../../domain/services/character_codec.dart';
import '../../domain/services/power_rating_service.dart';
import '../../domain/services/ranking_service.dart';
import '../../domain/services/service_locator.dart';
import 'character_portrait.dart';
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

  /// ランキング詳細の自分の行に表示するアバター（カスタマイズ反映済み）
  final Character? playerAvatar;

  const PowerRatingCard({super.key, required this.rating, this.playerAvatar});

  @override
  Widget build(BuildContext context) {
    final tierColor = powerTierColor(rating.tier);
    // ゲージは「強いほど満ちる」（上位0% = 満タン）
    final strength = (1 - rating.topPercent / 100).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () =>
          PowerRankingSheet.show(context, rating, playerAvatar: playerAvatar),
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

  /// 自分の行に表示するアバター（カスタマイズ反映済み）
  final Character? playerAvatar;

  /// テスト注入用。未指定なら [ServiceLocator]（未初期化時は推定サービス）。
  final RankingService? rankingService;

  const PowerRankingSheet({
    super.key,
    required this.rating,
    this.playerAvatar,
    this.rankingService,
  });

  static Future<void> show(
    BuildContext context,
    PowerRating rating, {
    Character? playerAvatar,
    RankingService? rankingService,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B2838),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PowerRankingSheet(
        rating: rating,
        playerAvatar: playerAvatar,
        rankingService: rankingService,
      ),
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
              _WorldRankingOptInSection(
                rating: rating,
                playerAvatar: playerAvatar,
                rankingService: rankingService,
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
          // 自分の行にはカスタマイズ済みアバターを表示
          if (highlight && playerAvatar != null) ...[
            CharacterPortrait(
              character: playerAvatar!,
              variant: PortraitVariant.bust,
              height: 28,
              square: true,
            ),
            const SizedBox(width: 6),
          ],
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

/// PR-B 最小 UI: 世界ランキング見出しと参加トグルのみ。一覧・ラベル切替は PR-C。
class _WorldRankingOptInSection extends StatefulWidget {
  final PowerRating rating;
  final Character? playerAvatar;
  final RankingService? rankingService;

  const _WorldRankingOptInSection({
    required this.rating,
    this.playerAvatar,
    this.rankingService,
  });

  @override
  State<_WorldRankingOptInSection> createState() =>
      _WorldRankingOptInSectionState();
}

class _WorldRankingOptInSectionState extends State<_WorldRankingOptInSection> {
  late RankingService _service;
  late bool _optedIn;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.rankingService ?? _resolveService();
    _optedIn = _service.isOptedIn;
  }

  RankingService _resolveService() {
    if (ServiceLocator().isInitialized) {
      return ServiceLocator().rankingService;
    }
    return EstimatedRankingService();
  }

  String get _characterCode {
    final avatar = widget.playerAvatar;
    if (avatar == null) {
      return '';
    }
    try {
      return CharacterCodec.encode(avatar);
    } catch (_) {
      return '';
    }
  }

  String get _title {
    if (ServiceLocator().isInitialized) {
      return ServiceLocator().playerTitleService.loadTitles().current.label;
    }
    return '';
  }

  Future<void> _setOptIn(bool enabled) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.setOptIn(
        enabled,
        local: widget.rating,
        characterCode: _characterCode,
        title: _title,
      );
      if (!mounted) {
        return;
      }
      setState(() => _optedIn = _service.isOptedIn);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _optedIn = _service.isOptedIn;
        if (enabled) {
          _error = '参加に失敗しました。再試行してください';
        } else {
          _error = '削除に失敗しました。再試行してください';
        }
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🌏 世界ランキング（今週）',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (_optedIn)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '参加中',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
                Switch(
                  key: const Key('ranking_opt_in_switch'),
                  value: true,
                  onChanged: _busy ? null : _setOptIn,
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('ranking_opt_in_button'),
                onPressed: _busy ? null : () => _setOptIn(true),
                child: const Text('参加して実際の順位を見る'),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: const TextStyle(fontSize: 11, color: Color(0xFFFF8A80)),
            ),
          ],
        ],
      ),
    );
  }
}
