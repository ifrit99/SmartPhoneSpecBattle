import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/data/sound_service.dart';
import 'package:spec_battle_game/presentation/screens/title_screen.dart';

void main() {
  tearDown(() async {
    await SoundService().setBgmMuted(false);
  });

  testWidgets('タイトル背景画像と既存ロゴ/TAP TO STARTを表示する', (tester) async {
    // リピート中のBGMフェードでテストが延びないようミュートする
    await SoundService().setBgmMuted(true);

    await tester.pumpWidget(const MaterialApp(home: TitleScreen()));
    await tester.pump();

    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! Image) return false;
        final image = widget.image;
        return image is AssetImage &&
            image.assetName == 'assets/images/title_bg.png' &&
            widget.fit == BoxFit.cover &&
            widget.alignment == Alignment.topCenter;
      }),
      findsOneWidget,
    );
    expect(find.text('SPEC BATTLE'), findsOneWidget);
    expect(find.text('TAP TO START'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('SPEC BATTLE'), findsOneWidget);
    expect(find.text('TAP TO START'), findsOneWidget);
  });
}
