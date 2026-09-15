import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/services/power_rating_service.dart';
import 'package:spec_battle_game/domain/services/ranking_service.dart';
import 'package:spec_battle_game/presentation/widgets/power_rating_card.dart';

void main() {
  const rating = PowerRating(
    score: 150,
    rank: 5,
    populationSize: 18,
    topPercent: 27.8,
    tier: PowerTier.a,
    entries: [
      PowerRankingEntry(name: 'Forge Phone 9 Pro', score: 220, isPlayer: false),
      PowerRankingEntry(name: 'Stellar S24 Ultra', score: 210, isPlayer: false),
      PowerRankingEntry(name: 'FruitPhone 16 Pro', score: 190, isPlayer: false),
      PowerRankingEntry(name: 'Prism 9 Pro', score: 170, isPlayer: false),
      PowerRankingEntry(name: 'あなた', score: 150, isPlayer: true),
      PowerRankingEntry(name: 'Stellar J2 Lite', score: 90, isPlayer: false),
    ],
  );

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PowerRatingCard(rating: rating),
        ),
      ),
    );
  }

  group('PowerRatingCard', () {
    testWidgets('スコア・ティア・推定上位%・順位を表示する', (tester) async {
      await pumpCard(tester);

      expect(find.text('150'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('推定上位28%'), findsOneWidget);
      expect(find.text('全18端末中 5位'), findsOneWidget);
      expect(find.text(PowerTier.a.verdict), findsOneWidget);
    });

    testWidgets('タップでランキング詳細シートが開きプレイヤー行が強調される', (tester) async {
      await pumpCard(tester);

      await tester.tap(find.byType(PowerRatingCard));
      await tester.pumpAndSettle();

      expect(find.text('戦闘力ランキング'), findsOneWidget);
      expect(find.text('Forge Phone 9 Pro'), findsOneWidget);
      expect(find.textContaining('世界ランキングは今後のアップデート'), findsOneWidget);
      expect(find.text('🌏 世界ランキング（今週）'), findsOneWidget);
      expect(find.text('参加して実際の順位を見る'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('あなたのスマホ'),
        80,
        scrollable: find
            .descendant(
              of: find.byType(PowerRankingSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('あなたのスマホ'), findsOneWidget);
    });

    testWidgets('参加ボタンで setOptIn(true) が呼ばれる', (tester) async {
      final ranking = _FakeSheetRankingService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PowerRankingSheet(rating: rating, rankingService: ranking),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('ranking_opt_in_button')));
      await tester.pumpAndSettle();

      expect(ranking.optInCalls, 1);
      expect(ranking.isOptedIn, isTrue);
      expect(find.byKey(const Key('ranking_opt_in_switch')), findsOneWidget);
    });
  });
}

class _FakeSheetRankingService implements RankingService {
  bool _optedIn = false;
  int optInCalls = 0;

  @override
  bool get isOptedIn => _optedIn;

  @override
  Future<void> setOptIn(
    bool enabled, {
    PowerRating? local,
    String characterCode = '',
    String title = '',
  }) async {
    optInCalls++;
    _optedIn = enabled;
  }

  @override
  Future<RankingSnapshot> loadMyStanding(PowerRating local) async {
    return RankingSnapshot.estimated(local, weekId: '2026-05-04');
  }

  @override
  Future<RankingSnapshot> loadLeaderboard(PowerRating local) async {
    return RankingSnapshot.estimated(local, weekId: '2026-05-04');
  }

  @override
  Future<void> submitIfNeeded({
    required PowerRating local,
    String characterCode = '',
    String title = '',
  }) async {}
}
