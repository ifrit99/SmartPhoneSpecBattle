import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/data/sound_service.dart';
import 'package:spec_battle_game/data/ux_timing.dart';
import 'package:spec_battle_game/domain/services/power_rating_service.dart';
import 'package:spec_battle_game/domain/services/ranking_service.dart';
import 'package:spec_battle_game/presentation/screens/title_screen.dart';
import 'package:spec_battle_game/presentation/widgets/power_rating_card.dart';

void main() {
  setUp(UxTiming.resetForTest);
  tearDown(UxTiming.resetForTest);

  group('UxTiming', () {
    test('debug では start/end で経過を残す', () {
      UxTiming.markStart('probe');
      UxTiming.markEnd('probe');

      expect(UxTiming.last('probe'), isNotNull);
      expect(UxTiming.last('probe')!.inMicroseconds, greaterThanOrEqualTo(0));
    });

    test('release 相当（enabled=false）は no-op', () {
      UxTiming.debugEnabledOverride = false;
      UxTiming.markStart('probe');
      UxTiming.markEnd('probe');

      expect(UxTiming.last('probe'), isNull);
    });

    test('開始していない end は no-op', () {
      UxTiming.markEnd('missing');
      expect(UxTiming.last('missing'), isNull);
    });

    testWidgets('post-frame で一度だけ閉じる', (tester) async {
      UxTiming.markStart('probe');
      await tester.pumpWidget(const SizedBox.shrink());
      UxTiming.markEndAfterFrame('probe');
      UxTiming.markEndAfterFrame('probe');
      expect(UxTiming.last('probe'), isNull);

      await tester.pump();
      expect(UxTiming.last('probe'), isNotNull);
    });
  });

  group('埋め込み', () {
    const rating = PowerRating(
      score: 150,
      rank: 5,
      populationSize: 18,
      topPercent: 27.8,
      tier: PowerTier.a,
      entries: [
        PowerRankingEntry(name: 'あなた', score: 150, isPlayer: true),
      ],
    );

    tearDown(() async {
      await SoundService().setBgmMuted(false);
    });

    testWidgets('TitleScreen 初回 post-frame で cold_to_title を閉じる',
        (tester) async {
      await SoundService().setBgmMuted(true);
      UxTiming.markStart(UxTiming.coldToTitle);

      await tester.pumpWidget(const MaterialApp(home: TitleScreen()));
      expect(UxTiming.last(UxTiming.coldToTitle), isNull);

      await tester.pump();
      expect(UxTiming.last(UxTiming.coldToTitle), isNotNull);
    });

    testWidgets('カードタップからシート初回 post-frame で home_to_pwr_sheet を閉じる',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PowerRatingCard(rating: rating),
          ),
        ),
      );

      await tester.tap(find.byType(PowerRatingCard));
      await tester.pump();

      expect(find.text('🌏 世界ランキング（今週）'), findsOneWidget);
      expect(UxTiming.last(UxTiming.homeToPwrSheet), isNotNull);
    });

    testWidgets('setOptIn 成功後の post-frame で ranking_optin_done を閉じる',
        (tester) async {
      final ranking = _FakeSheetRankingService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PowerRankingSheet(rating: rating, rankingService: ranking),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('ranking_opt_in_button')));
      await tester.pump();
      expect(UxTiming.last(UxTiming.rankingOptinDone), isNull);

      await tester.pump();
      expect(ranking.optInCalls, 1);
      expect(UxTiming.last(UxTiming.rankingOptinDone), isNotNull);
    });

    testWidgets('setOptIn 失敗でも post-frame で ranking_optin_done を閉じる',
        (tester) async {
      final ranking = _FakeSheetRankingService()..failNext = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PowerRankingSheet(rating: rating, rankingService: ranking),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('ranking_opt_in_button')));
      await tester.pump();
      await tester.pump();

      expect(find.text('参加に失敗しました。再試行してください'), findsOneWidget);
      expect(UxTiming.last(UxTiming.rankingOptinDone), isNotNull);
    });
  });
}

class _FakeSheetRankingService implements RankingService {
  bool _optedIn = false;
  int optInCalls = 0;
  bool failNext = false;

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
    if (failNext) {
      failNext = false;
      throw StateError('opt-in failed');
    }
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
