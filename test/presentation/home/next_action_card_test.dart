import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/presentation/widgets/home/next_action_card.dart';

void main() {
  testWidgets('入力データを描画し、タップでコールバックが発火する', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NextActionCard(
            icon: Icons.task_alt,
            title: 'ミッション報酬が未受取',
            description: '2件のデイリー報酬があります。まとめて回収できます。',
            buttonLabel: '確認',
            color: const Color(0xFF00CEC9),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('ミッション報酬が未受取'), findsOneWidget);
    expect(find.text('2件のデイリー報酬があります。まとめて回収できます。'), findsOneWidget);
    expect(find.text('確認'), findsOneWidget);

    await tester.tap(find.byType(NextActionCard));
    expect(tapped, isTrue);
  });
}
