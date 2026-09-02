import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/data/sound_service.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/presentation/screens/battle_screen.dart';

void main() {
  tearDown(() async {
    await SoundService().setBgmMuted(false);
  });

  testWidgets('バトル背景画像と既存HUD/HP/ログ導線を表示する', (tester) async {
    await SoundService().setBgmMuted(true);

    await tester.pumpWidget(
      MaterialApp(
        home: BattleScreen(
          player: _character('プレイヤー'),
          enemy: _character('敵'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! Image) return false;
        final image = widget.image;
        return image is AssetImage &&
            image.assetName == 'assets/images/battle_bg.png' &&
            widget.fit == BoxFit.cover &&
            widget.alignment == Alignment.topCenter;
      }),
      findsOneWidget,
    );
    expect(find.text('TURN 1'), findsOneWidget);
    expect(find.text('プレイヤー'), findsOneWidget);
    expect(find.text('敵'), findsOneWidget);
    expect(find.text('HP'), findsNWidgets(2));
    expect(find.text('サポートコマンドを選択'), findsOneWidget);
    expect(find.text('BGM'), findsOneWidget);
    expect(find.text('SE'), findsOneWidget);
  });
}

Character _character(String name) {
  const stats = Stats(hp: 100, maxHp: 100, atk: 20, def: 12, spd: 10);
  return Character(
    name: name,
    element: ElementType.fire,
    baseStats: stats,
    currentStats: stats,
    skills: const [],
  );
}
