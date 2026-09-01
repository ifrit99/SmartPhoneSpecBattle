import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/presentation/widgets/home/daily_reward_card.dart';

void main() {
  testWidgets('未受取時はストリークボーナス案内とジェム数を表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyRewardCard(
            loginClaimed: false,
            battleClaimed: false,
            cycleDay: 3,
            streakCycleDays: 7,
            nextBonus: 10,
            loginRewardGems: 10,
            battleRewardGems: 15,
          ),
        ),
      ),
    );

    expect(find.text('デイリー報酬'), findsOneWidget);
    expect(find.text('3/7日'), findsOneWidget);
    expect(find.text('今日のログインでストリークボーナス +10 Gems'), findsOneWidget);
    expect(find.text('ログイン'), findsOneWidget);
    expect(find.text('バトル1回'), findsOneWidget);
    expect(find.text('💎 +10'), findsOneWidget);
    expect(find.text('💎 +15'), findsOneWidget);
  });

  testWidgets('受取済のときは受取済表示に切り替わる', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyRewardCard(
            loginClaimed: true,
            battleClaimed: true,
            cycleDay: 3,
            streakCycleDays: 7,
            nextBonus: 10,
            loginRewardGems: 10,
            battleRewardGems: 15,
          ),
        ),
      ),
    );

    expect(find.text('連続ログインで3日目・7日目にボーナス'), findsOneWidget);
    expect(find.text('受取済'), findsNWidgets(2));
    expect(find.text('💎 +10'), findsNothing);
  });
}
