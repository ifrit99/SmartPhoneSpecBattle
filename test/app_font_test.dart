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

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.fontFamily, appFontFamily);
    expect(app.theme!.fontFamilyFallback, const ['Roboto']);
  });

  test('preloadAppFont が登録済みサブセットを読み込める', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await preloadAppFont();
  });
}
