import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

bool _initialized = false;
Future<bool>? _initializing;

/// テスト用: [FirebaseOptionsConfig.hasConfig] を上書きする。
@visibleForTesting
bool? debugHasConfigOverride;

/// テスト用: 実際の [Firebase.initializeApp] を差し替える。
@visibleForTesting
Future<void> Function(FirebaseOptions options)? debugInitializeApp;

/// テスト用: 遅延初期化の呼び出し回数（実初期化に進んだ回数）。
@visibleForTesting
int debugInitializeCallCount = 0;

/// テスト用: ブートストラップ状態を戻す。
@visibleForTesting
void resetFirebaseBootstrapForTest() {
  _initialized = false;
  _initializing = null;
  debugInitializeCallCount = 0;
  debugInitializeApp = null;
  debugHasConfigOverride = null;
}

/// Firebase を遅延初期化する。
///
/// [FirebaseOptionsConfig.hasConfig] が false なら何もせず false。
/// 起動時（`main` / [ServiceLocator.init]）からは呼ばない。
/// ランキング参加 ON（保存済みフラグ含む）のときだけ呼ぶこと。
/// 同時呼び出しは進行中の初期化 Future を共有し、`initializeApp` は1回だけにする。
Future<bool> ensureFirebaseInitialized() async {
  final hasConfig = debugHasConfigOverride ?? FirebaseOptionsConfig.hasConfig;
  if (!hasConfig) {
    return false;
  }
  if (_initialized) {
    return true;
  }
  final future = _initializing ??= _initializeFirebase();
  try {
    return await future;
  } catch (_) {
    if (identical(_initializing, future)) {
      _initializing = null;
    }
    rethrow;
  }
}

Future<bool> _initializeFirebase() async {
  debugInitializeCallCount++;
  final initialize = debugInitializeApp;
  if (initialize != null) {
    await initialize(FirebaseOptionsConfig.options);
  } else {
    await Firebase.initializeApp(options: FirebaseOptionsConfig.options);
  }
  _initialized = true;
  return true;
}
