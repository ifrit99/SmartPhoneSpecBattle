/// [firebase_core_web] の `supportedFirebaseJsSdkVersion` と一致させる。
/// 参加時の先読みがこの版を gstatic から import する。
/// 版を上げたら `test/data/firebase_csp_headers_test.dart` が落ちる。
const firebaseJsSdkVersion = '12.18.0';

/// `web/` に置く先読みスクリプト。`'self'` の外部ファイルなので CSP ハッシュ不要。
const firebaseJsPreloadScript = 'firebase_js_preload.js';
