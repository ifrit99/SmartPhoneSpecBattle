import 'dart:async';

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

  test('同時呼び出しでも初期化は1回にまとめる', () async {
    debugHasConfigOverride = true;
    final started = Completer<void>();
    final release = Completer<void>();
    var initializeCount = 0;
    debugInitializeApp = (_) async {
      initializeCount++;
      started.complete();
      await release.future;
    };

    final first = ensureFirebaseInitialized();
    final second = ensureFirebaseInitialized();
    await started.future;
    expect(debugInitializeCallCount, 1);
    release.complete();

    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(initializeCount, 1);
    expect(debugInitializeCallCount, 1);
  });

  test('1回目が同期例外でも2回目は再試行できる', () async {
    debugHasConfigOverride = true;
    var initializeCount = 0;
    debugInitializeApp = (_) {
      initializeCount++;
      if (initializeCount == 1) {
        throw StateError('sync fail');
      }
      return Future<void>.value();
    };

    await expectLater(ensureFirebaseInitialized(), throwsStateError);
    expect(await ensureFirebaseInitialized(), isTrue);
    expect(initializeCount, 2);
    expect(debugInitializeCallCount, 2);
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
