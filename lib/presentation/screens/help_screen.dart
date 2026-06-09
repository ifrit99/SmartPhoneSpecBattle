import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        title: const Text(
          '遊び方',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: const [
          _HelpSection(
            icon: Icons.route,
            color: Color(0xFF74B9FF),
            title: 'まず目指すこと',
            body:
                'CPU戦でコインと経験値を集め、ガチャで主力を増やします。勝てない相手が出たら編成を見直し、HARD/BOSSや期間イベントで大きな報酬を狙います。',
          ),
          _HelpSection(
            icon: Icons.tune,
            color: Color(0xFFFFD700),
            title: '戦術の選び方',
            body:
                'バランスは安定、オーバークロックは勝てそうな相手への報酬重視、ファイアウォールは不利な相手への防御重視、バーストはスキルで押し切りたい時に有効です。敵プレビューの推奨戦術から始めるのが安全です。',
          ),
          _HelpSection(
            icon: Icons.bolt,
            color: Color(0xFFE056FD),
            title: '支援コマンド',
            body:
                'バトル開始時に一度だけ選べます。攻撃支援は短期決着向け、防御支援は強敵相手の粘り向けです。BOSS自己ベストを狙う時は攻撃支援、初回撃破を安定させたい時は防御支援が目安です。',
          ),
          _HelpSection(
            icon: Icons.auto_awesome,
            color: Color(0xFFFFA502),
            title: 'ガチャと育成',
            body:
                '通常ガチャはコイン、プレミアム解析はジェムを使います。プレミアム解析はSR以上確定で、日替わりSSRピックアップと天井があります。重複キャラは覚醒に変換され、最大+5まで強化されます。',
          ),
          _HelpSection(
            icon: Icons.event_available,
            color: Color(0xFF00CEC9),
            title: '毎日・毎週の報酬',
            body:
                'デイリー報酬、今日のミッション、週次チャレンジ、週替わりイベントを進めるとジェムとコインが安定して増えます。BOSS勝利は1日1回の追加報酬と自己ベスト更新の対象です。',
          ),
          _HelpSection(
            icon: Icons.people,
            color: Color(0xFF55EFC4),
            title: 'フレンド対戦',
            body:
                'Friendから自分のキャラURLをコピーできます。受け取ったURLを入力すると、相手キャラとの相性と推奨戦術を見てから対戦できます。リザルトは結果コピーで共有できます。',
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _HelpSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
