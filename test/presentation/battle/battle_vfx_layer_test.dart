import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/presentation/battle/battle_cue.dart';
import 'package:spec_battle_game/presentation/widgets/battle/battle_vfx_layer.dart';

void main() {
  group('slashLength / slashAlpha', () {
    test('t=0.3 で長さは最大・alpha は 1', () {
      expect(slashLength(0.3), 1.0);
      expect(slashAlpha(0.3), 1.0);
    });

    test('t=1 で alpha は 0', () {
      expect(slashAlpha(1.0), 0.0);
    });
  });

  testWidgets('spawn 後に描画対象があり、寿命経過で空になる', (tester) async {
    final controller = BattleVfxController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleVfxLayer(controller: controller),
        ),
      ),
    );
    await tester.pump();

    controller.spawn(
      VfxKind.slash,
      target: const Rect.fromLTWH(20, 20, 48, 48),
      color: const Color(0xFFFF6B6B),
    );
    await tester.pump();
    expect(controller.isEmpty, isFalse);
    expect(find.byType(CustomPaint), findsWidgets);

    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.isEmpty, isTrue);
  });

  testWidgets('clear() で即時空になる', (tester) async {
    final controller = BattleVfxController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleVfxLayer(controller: controller),
        ),
      ),
    );
    await tester.pump();

    controller.spawn(
      VfxKind.burst,
      target: const Rect.fromLTWH(0, 0, 64, 64),
      color: Colors.white,
    );
    await tester.pump();
    expect(controller.isEmpty, isFalse);

    controller.clear();
    await tester.pump();
    expect(controller.isEmpty, isTrue);
  });
}
