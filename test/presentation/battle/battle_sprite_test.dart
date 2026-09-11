import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/presentation/battle/battle_cue.dart';
import 'package:spec_battle_game/presentation/widgets/battle/battle_sprite.dart';

void main() {
  testWidgets('初期フレームは変位 0・ティントなし', (tester) async {
    final controller = BattleSpriteController();
    await _pumpSprite(tester, controller: controller);
    await tester.pump();

    expect(_offset(tester), Offset.zero);
    expect(find.byType(ColorFiltered), findsNothing);
    expect(controller.state, SpriteState.idle);
  });

  testWidgets('play(attack) は 120ms で自が +x、300ms で 0・idle', (tester) async {
    final controller = BattleSpriteController();
    await _pumpSprite(tester, controller: controller);
    await tester.pump();

    controller.play(SpriteState.attack);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(_offset(tester).dx, greaterThan(0));
    expect(controller.state, SpriteState.attack);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(_offset(tester).dx, 0);
    expect(controller.state, SpriteState.idle);
  });

  testWidgets('play(attack) は 120ms で敵が −x', (tester) async {
    final controller = BattleSpriteController();
    await _pumpSprite(
      tester,
      controller: controller,
      flipHorizontal: true,
    );
    await tester.pump();

    controller.play(SpriteState.attack);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(_offset(tester).dx, lessThan(0));
  });

  testWidgets('stopAll() で即時 idle・変位 0', (tester) async {
    final controller = BattleSpriteController();
    await _pumpSprite(tester, controller: controller);
    await tester.pump();

    controller.play(SpriteState.attack);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_offset(tester).dx, isNot(0));

    controller.stopAll();
    await tester.pump();
    expect(controller.state, SpriteState.idle);
    expect(_offset(tester), Offset.zero);
  });

  testWidgets('disableAnimations では変位 0 のまま', (tester) async {
    final controller = BattleSpriteController();
    await _pumpSprite(
      tester,
      controller: controller,
      disableAnimations: true,
    );
    await tester.pump();

    controller.play(SpriteState.attack);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(_offset(tester), Offset.zero);
    expect(controller.state, SpriteState.idle);
  });

  testWidgets('victory は最終状態で止まり idle に戻らない', (tester) async {
    final controller = BattleSpriteController();
    await _pumpSprite(tester, controller: controller);
    await tester.pump();

    controller.play(SpriteState.victory);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.state, SpriteState.victory);

    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.state, SpriteState.victory);
  });

  testWidgets('defeat は最終状態で沈み idle に戻らない', (tester) async {
    final controller = BattleSpriteController();
    await _pumpSprite(tester, controller: controller);
    await tester.pump();

    controller.play(SpriteState.defeat);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.state, SpriteState.defeat);
    expect(_offset(tester).dy, greaterThan(0));
    expect(find.byType(Opacity), findsOneWidget);
    expect(find.byType(ColorFiltered), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.state, SpriteState.defeat);
  });
}

Future<void> _pumpSprite(
  WidgetTester tester, {
  required BattleSpriteController controller,
  bool flipHorizontal = false,
  bool disableAnimations = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: disableAnimations),
          child: child!,
        );
      },
      home: Scaffold(
        body: BattleSprite(
          character: _character(),
          height: 48,
          controller: controller,
          flipHorizontal: flipHorizontal,
        ),
      ),
    ),
  );
}

Offset _offset(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.byKey(const ValueKey<String>('battle_sprite_offset')),
  );
  final translation = transform.transform.getTranslation();
  return Offset(translation.x, translation.y);
}

Character _character() {
  const stats = Stats(hp: 100, maxHp: 100, atk: 10, def: 10, spd: 10);
  return const Character(
    name: 'テスト',
    element: ElementType.fire,
    baseStats: stats,
    currentStats: stats,
    skills: [],
  );
}
