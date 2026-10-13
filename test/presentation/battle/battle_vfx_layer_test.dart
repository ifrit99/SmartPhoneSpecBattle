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

  testWidgets('burst の寿命は 320ms のまま', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.isEmpty, isFalse);

    await tester.pump(const Duration(milliseconds: 80));
    expect(controller.isEmpty, isTrue);
  });

  testWidgets('sparkle の寿命は 500ms のまま', (tester) async {
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
      VfxKind.sparkle,
      target: const Rect.fromLTWH(0, 0, 64, 64),
      color: Colors.white,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.isEmpty, isFalse);

    await tester.pump(const Duration(milliseconds: 110));
    expect(controller.isEmpty, isTrue);
  });

  group('particleDistance（easeOutCubic）', () {
    test('t=0.5 で距離が最大の 70% 以上', () {
      final atHalf = particleDistance(0.5);
      final atEnd = particleDistance(1);
      expect(atHalf, greaterThanOrEqualTo(0.7 * atEnd));
    });

    test('t=1 で距離は最大', () {
      expect(particleDistance(1), 1.0);
      expect(particleDistance(0), 0.0);
      expect(particleDistance(0.5), lessThan(particleDistance(1)));
      expect(particleDistance(0.99), lessThan(particleDistance(1)));
    });
  });

  group('burstFall（t²）', () {
    test('落下量は単調増加', () {
      const charSize = 48.0;
      var prev = burstFall(0, charSize);
      expect(prev, 0);
      for (final t in <double>[
        0.1,
        0.2,
        0.3,
        0.4,
        0.5,
        0.6,
        0.7,
        0.8,
        0.9,
        1.0,
      ]) {
        final next = burstFall(t, charSize);
        expect(next, greaterThan(prev), reason: 't=$t');
        prev = next;
      }
    });

    test('t=1 の落下は 0.1〜0.15 charSize', () {
      const charSize = 100.0;
      expect(burstFall(1, charSize), greaterThanOrEqualTo(0.1 * charSize));
      expect(burstFall(1, charSize), lessThanOrEqualTo(0.15 * charSize));
    });
  });

  group('particleAlpha', () {
    test('t=0.6 まで 1、t=1 で 0', () {
      expect(particleAlpha(0), 1.0);
      expect(particleAlpha(0.6), 1.0);
      expect(particleAlpha(0.8), closeTo(0.5, 1e-9));
      expect(particleAlpha(1), 0.0);
    });
  });
}
