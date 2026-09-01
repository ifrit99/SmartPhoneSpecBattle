import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/services/season_pass_service.dart';
import 'package:spec_battle_game/presentation/widgets/home/season_pass_card.dart';

void main() {
  testWidgets('次報酬とチップを描画し、受取ボタンでコールバックが発火する', (tester) async {
    var claimed = false;
    final starter = SeasonPassService.rewards.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeasonPassCard(
            pass: SeasonPassSnapshot(
              seasonId: '2026-09',
              xp: 100,
              daysRemaining: 12,
              rewards: [
                SeasonPassRewardSnapshot(
                  definition: starter,
                  currentXp: 100,
                  claimed: false,
                ),
              ],
            ),
            onClaim: () => claimed = true,
          ),
        ),
      ),
    );

    expect(find.text('シーズンパス 2026-09'), findsOneWidget);
    expect(find.text('残り12日'), findsOneWidget);
    expect(find.text('100/100 SP'), findsOneWidget);
    expect(find.text('1件のシーズン報酬を受け取れます。'), findsOneWidget);
    expect(find.text('100SP'), findsOneWidget);
    expect(find.text('シーズン報酬を受け取る'), findsOneWidget);

    await tester.tap(find.text('シーズン報酬を受け取る'));
    expect(claimed, isTrue);
  });

  testWidgets('全報酬受取済みのときは完了文言を表示する', (tester) async {
    var claimed = false;
    final starter = SeasonPassService.rewards.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeasonPassCard(
            pass: SeasonPassSnapshot(
              seasonId: '2026-09',
              xp: 100,
              daysRemaining: 12,
              rewards: [
                SeasonPassRewardSnapshot(
                  definition: starter,
                  currentXp: 100,
                  claimed: true,
                ),
              ],
            ),
            onClaim: () => claimed = true,
          ),
        ),
      ),
    );

    expect(find.text('今月の報酬はすべて受取済みです。'), findsOneWidget);
    expect(find.text('100 SP'), findsOneWidget);
    expect(find.text('シーズン報酬を受け取る'), findsNothing);
    expect(claimed, isFalse);
  });
}
