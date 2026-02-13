import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/main.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(SpecBattleApp());
    expect(find.text('SPEC BATTLE'), findsOneWidget);
  });
}
