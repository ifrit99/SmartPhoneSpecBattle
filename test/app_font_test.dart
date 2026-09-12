import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/data/sound_service.dart';
import 'package:spec_battle_game/domain/services/service_locator.dart';
import 'package:spec_battle_game/main.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServiceLocator().init();
    await SoundService().setBgmMuted(true);
  });

  tearDown(() async {
    await SoundService().setBgmMuted(false);
  });

  testWidgets('テーマは NotoSansJP を使い Roboto をフォールバックする', (tester) async {
    await tester.pumpWidget(const SpecBattleApp());
    await tester.pump();

    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    expect(theme.textTheme.bodyMedium?.fontFamily, appFontFamily);
    expect(theme.textTheme.bodyMedium?.fontFamilyFallback, const ['Roboto']);

    // TitleScreen の演出ディレイ（0.8s + 0.6s）を消化して pending timer を残さない
    await tester.pump(const Duration(milliseconds: 1500));
  });

  test('preloadAppFont が登録済みサブセットを読み込める', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await preloadAppFont();
  });
}
