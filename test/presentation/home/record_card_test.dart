import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/presentation/widgets/home/record_card.dart';

void main() {
  testWidgets('バトル数・勝利数・勝率を表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RecordCard(battles: 10, wins: 7),
        ),
      ),
    );

    expect(find.text('バトル数'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('勝利数'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('勝率'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
  });

  testWidgets('バトル0回のときは勝率をハイフン表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RecordCard(battles: 0, wins: 0),
        ),
      ),
    );

    expect(find.text('-'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });
}
