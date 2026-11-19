import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'firebase_js_sdk_version.dart';

final JSString _loaderName = '__ssbPreloadFirebaseJs'.toJS;
final JSString _coreName = 'firebase_core'.toJS;
final JSString _authName = 'firebase_auth'.toJS;
final JSString _firestoreName = 'firebase_firestore'.toJS;

/// flutterfire のインライン注入の前に、gstatic の Firebase JS を順に import する。
///
/// `window.firebase_core` が既にあると `_initializeCore` は注入を全部飛ばす。
/// Safari は動的インラインの CSP ハッシュを Chrome と同じに扱わないことがある。
Future<void> preloadFirebaseJsSdks() async {
  if (_alreadyLoaded()) {
    return;
  }
  if (globalContext.getProperty(_loaderName) == null) {
    await _injectLoaderScript();
  }
  final loader = globalContext.getProperty(_loaderName);
  if (loader == null) {
    throw StateError('$firebaseJsPreloadScript のローダが見つかりません');
  }
  final result = (loader as JSFunction).callAsFunction(
    null,
    firebaseJsSdkVersion.toJS,
  );
  if (result != null) {
    await (result as JSPromise).toDart;
  }
}

bool _alreadyLoaded() {
  return globalContext.getProperty(_coreName) != null &&
      globalContext.getProperty(_authName) != null &&
      globalContext.getProperty(_firestoreName) != null;
}

Future<void> _injectLoaderScript() {
  final completer = Completer<void>();
  final document = globalContext.getProperty('document'.toJS) as JSObject;
  final script = document.callMethod<JSObject>(
    'createElement'.toJS,
    'script'.toJS,
  );
  script.setProperty('src'.toJS, firebaseJsPreloadScript.toJS);

  void onLoad() {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  void onError() {
    if (!completer.isCompleted) {
      completer.completeError(
        StateError('$firebaseJsPreloadScript の読み込みに失敗しました'),
      );
    }
  }

  script.setProperty('onload'.toJS, onLoad.toJS);
  script.setProperty('onerror'.toJS, onError.toJS);
  final head = document.getProperty('head'.toJS) as JSObject;
  head.callMethod<JSAny?>('appendChild'.toJS, script);
  return completer.future;
}
