'use strict';

// ランキング参加時だけ呼ぶ。flutterfire のインライン注入を避け、
// Safari / WebKit でも CSP を通す（script-src の gstatic 許可で足りる）。
// core を先に評価してから auth / firestore を読む（WebKit の module TDZ 回避）。
window.__ssbPreloadFirebaseJs = function (version) {
  return (async function () {
    if (
      window.firebase_core &&
      window.firebase_auth &&
      window.firebase_firestore
    ) {
      return;
    }
    var base = 'https://www.gstatic.com/firebasejs/' + version;
    window.firebase_core = await import(base + '/firebase-app.js');
    window.firebase_auth = await import(base + '/firebase-auth.js');
    window.firebase_firestore = await import(
      base + '/firebase-firestore-pipelines.js'
    );
    window.flutterfire_ignore_scripts = ['core', 'auth', 'firestore'];
  })();
};
