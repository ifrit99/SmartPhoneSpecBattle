import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/services/rival_road_service.dart';
import 'package:spec_battle_game/presentation/widgets/home/rival_road_card.dart';

void main() {
  testWidgets('進行中ステージを描画し、タップでコールバックが発火する', (tester) async {
    var tapped = false;
    const stage = RivalRoadStageDefinition(
      index: 1,
      title: 'Entry Gate',
      enemyDeviceId: 'easy_03',
      rewardCoins: 160,
      rewardGems: 5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RivalRoadCard(
            road: const RivalRoadSnapshot(
              clearedStageCount: 0,
              stages: [stage],
              bestTurnsByStage: {1: 12},
            ),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('ライバルロード'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
    expect(find.text('Stage 1: Entry Gate / Clario sense2'), findsOneWidget);
    expect(find.text('BEST 12T'), findsOneWidget);
    expect(find.text('+160C / +5G'), findsOneWidget);

    await tester.tap(find.byType(RivalRoadCard));
    expect(tapped, isTrue);
  });

  testWidgets('全ステージ制覇済みの文言を表示する', (tester) async {
    const stage = RivalRoadStageDefinition(
      index: 1,
      title: 'Entry Gate',
      enemyDeviceId: 'easy_03',
      rewardCoins: 160,
      rewardGems: 5,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RivalRoadCard(
            road: RivalRoadSnapshot(
              clearedStageCount: 1,
              stages: [stage],
              bestTurnsByStage: {1: 12},
            ),
          ),
        ),
      ),
    );

    expect(find.text('全ステージ制覇済み。全ステージの最短ターン更新を狙えます。'), findsOneWidget);
    expect(find.text('Stage 1: Entry Gate / Clario sense2'), findsNothing);
  });
}
