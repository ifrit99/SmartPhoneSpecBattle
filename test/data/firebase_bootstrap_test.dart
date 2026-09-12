import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spec_battle_game/data/firebase_bootstrap.dart';
import 'package:spec_battle_game/data/firebase_options.dart';
import 'package:spec_battle_game/domain/services/service_locator.dart';

void main() {
  setUp(resetFirebaseBootstrapForTest);

  test('hasConfig が false なら初期化せず false を返す', () async {
    expect(FirebaseOptionsConfig.hasConfig, isFalse);

    final initialized = await ensureFirebaseInitialized();

    expect(initialized, isFalse);
    expect(debugInitializeCallCount, 0);
  });

  test('hasConfig が true なら一度だけ初期化し true を返す', () async {
    debugHasConfigOverride = true;
    var initializeCount = 0;
    debugInitializeApp = (_) async {
      initializeCount++;
    };

    expect(await ensureFirebaseInitialized(), isTrue);
    expect(await ensureFirebaseInitialized(), isTrue);

    expect(initializeCount, 1);
    expect(debugInitializeCallCount, 1);
  });

  test('ServiceLocator.init は Firebase を初期化しない', () async {
    SharedPreferences.setMockInitialValues({});
    await ServiceLocator().resetForTest();
    await ServiceLocator().init();

    expect(debugInitializeCallCount, 0);
    expect(ServiceLocator().rankingService, isA<Object>());
    expect(ServiceLocator().rankingService.isOptedIn, isFalse);
  });
}
