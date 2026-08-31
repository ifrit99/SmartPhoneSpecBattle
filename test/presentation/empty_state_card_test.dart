import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spec_battle_game/presentation/widgets/empty_state_card.dart';

void main() {
  testWidgets('文言を表示し、導線ボタンでコールバックが走る', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateCard(
            icon: Icons.sports_mma,
            title: 'まだバトルしていません',
            message: 'バトルすると直近20件が残ります',
            actionLabel: 'バトルへ',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('まだバトルしていません'), findsOneWidget);
    expect(find.text('バトルすると直近20件が残ります'), findsOneWidget);
    await tester.tap(find.text('バトルへ'));
    expect(tapped, isTrue);
  });
}
