import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/services/daily_mission_service.dart';
import 'package:spec_battle_game/presentation/widgets/home/daily_mission_card.dart';

DailyMissionSnapshot _mission({
  required String id,
  required String title,
  required int target,
  required int progress,
  required bool claimed,
  int coinsReward = 0,
  int gemsReward = 0,
}) {
  return DailyMissionSnapshot(
    definition: DailyMissionDefinition(
      id: id,
      title: title,
      description: title,
      target: target,
      coinsReward: coinsReward,
      gemsReward: gemsReward,
      progress: (_) => progress,
    ),
    progress: progress,
    claimed: claimed,
  );
}

void main() {
  testWidgets('未達ミッションを描画し、受取可能時はコールバックが発火する', (tester) async {
    String? claimedId;
    var claimedAll = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyMissionCard(
            missions: [
              _mission(
                id: 'battle_1',
                title: '今日の腕試し',
                target: 1,
                progress: 1,
                claimed: false,
                coinsReward: 80,
              ),
              _mission(
                id: 'win_1',
                title: '勝利ボーナス',
                target: 1,
                progress: 0,
                claimed: false,
                gemsReward: 5,
              ),
            ],
            onClaim: (id) => claimedId = id,
            onClaimAll: () => claimedAll = true,
          ),
        ),
      ),
    );

    expect(find.text('今日のミッション'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('1件の報酬を受け取れます'), findsOneWidget);
    expect(find.text('今日の腕試し'), findsOneWidget);
    expect(find.text('1/1  +80 Coin'), findsOneWidget);
    expect(find.text('受取'), findsOneWidget);
    expect(find.text('未達'), findsOneWidget);
    expect(find.text('一括受取'), findsNothing);

    await tester.tap(find.text('受取'));
    expect(claimedId, 'battle_1');
    expect(claimedAll, isFalse);
  });

  testWidgets('受取可能が2件以上なら一括受取が発火する', (tester) async {
    final claimed = <String>[];
    var claimedAll = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyMissionCard(
            missions: [
              _mission(
                id: 'battle_1',
                title: '今日の腕試し',
                target: 1,
                progress: 1,
                claimed: false,
                coinsReward: 80,
              ),
              _mission(
                id: 'win_1',
                title: '勝利ボーナス',
                target: 1,
                progress: 1,
                claimed: false,
                gemsReward: 5,
              ),
            ],
            onClaim: claimed.add,
            onClaimAll: () => claimedAll = true,
          ),
        ),
      ),
    );

    expect(find.text('2件の報酬を受け取れます'), findsOneWidget);
    expect(find.text('一括受取'), findsOneWidget);

    await tester.tap(find.text('一括受取'));
    expect(claimedAll, isTrue);
    expect(claimed, isEmpty);
  });

  testWidgets('受取済のときは済表示に切り替わる', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyMissionCard(
            missions: [
              _mission(
                id: 'battle_1',
                title: '今日の腕試し',
                target: 1,
                progress: 1,
                claimed: true,
                coinsReward: 80,
              ),
            ],
            onClaim: (_) {},
            onClaimAll: () {},
          ),
        ),
      ),
    );

    expect(find.text('バトル・勝利・ガチャで毎日報酬を回収'), findsOneWidget);
    expect(find.text('済'), findsOneWidget);
    expect(find.text('受取'), findsNothing);
  });
}
