import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spec_battle_game/domain/services/character_codec.dart';
import 'package:spec_battle_game/presentation/screens/qr_guest_preview_screen.dart';
import 'package:spec_battle_game/presentation/widgets/empty_state_card.dart';

void main() {
  testWidgets('デコード失敗時は理由別文言と入力画面への導線を出す', (tester) async {
    var openedInput = false;
    await tester.pumpWidget(
      MaterialApp(
        home: QrGuestPreviewScreen(
          decodeError: const IntegrityException('tampered'),
          onOpenUrlInput: () => openedInput = true,
        ),
      ),
    );

    expect(find.byType(EmptyStateCard), findsOneWidget);
    expect(find.text('改ざん検知'), findsOneWidget);
    await tester.tap(find.text('入力画面へ'));
    expect(openedInput, isTrue);
  });
}
