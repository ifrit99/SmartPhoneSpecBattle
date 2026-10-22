import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// flutterfire が Web で注入するインラインスクリプト（core / auth / firestore）。
/// URL は `firebase_core_web` の `injectService` と同じ規則。
const _firebaseInlineServices = <({String windowVar, String file})>[
  (windowVar: 'firebase_core', file: 'firebase-app.js'),
  (windowVar: 'firebase_auth', file: 'firebase-auth.js'),
  (
    windowVar: 'firebase_firestore',
    file: 'firebase-firestore-pipelines.js',
  ),
];

void main() {
  test('flutterfire のインラインスクリプトハッシュが web/_headers の script-src にある', () {
    final coreWebRoot = _packageRoot('firebase_core_web');
    final coreWebSource = File.fromUri(
      coreWebRoot.resolve('lib/src/firebase_core_web.dart'),
    ).readAsStringSync();
    final sdkVersionSource = File.fromUri(
      coreWebRoot.resolve('lib/src/firebase_sdk_version.dart'),
    ).readAsStringSync();

    final version = RegExp(
      r"supportedFirebaseJsSdkVersion = '([^']+)'",
    ).firstMatch(sdkVersionSource)?.group(1);
    expect(
      version,
      isNotNull,
      reason: 'firebase_sdk_version.dart から JS SDK 版を読めない',
    );

    expect(
      coreWebSource.contains(r'firebase-${service.name}.js'),
      isTrue,
      reason: 'injectService の URL 規則が変わった。テストの file 一覧を見直す',
    );
    expect(
      coreWebSource.contains('firebase-firestore-pipelines.js'),
      isTrue,
      reason: 'Firestore 用バンドル名が変わった。_firebaseInlineServices を更新する',
    );

    final templates = _extractFfTriggerTemplates(coreWebSource);
    expect(
      templates,
      hasLength(2),
      reason: 'Trusted Types あり／なしの ff_trigger 文面が 2 つある想定',
    );

    final hashes = <String>{};
    for (final template in templates) {
      for (final service in _firebaseInlineServices) {
        final url =
            'https://www.gstatic.com/firebasejs/$version/${service.file}';
        hashes.add(
          _cspSha256(_injectedScript(template, service.windowVar, url)),
        );
      }
    }
    expect(hashes, hasLength(6));

    final headers = File('web/_headers').readAsStringSync();
    final scriptSrc = RegExp(r'script-src ([^;]+)').firstMatch(headers)?.group(1);
    expect(scriptSrc, isNotNull, reason: 'web/_headers に script-src が無い');
    expect(
      scriptSrc!.contains("'unsafe-inline'"),
      isFalse,
      reason: "script-src に 'unsafe-inline' を足さない",
    );

    for (final hash in hashes) {
      expect(
        scriptSrc.contains(hash),
        isTrue,
        reason: 'web/_headers の script-src に $hash が無い。'
            'firebase 系を上げたならハッシュを再計算して足す',
      );
    }
  });
}

Uri _packageRoot(String name) {
  final configFile = File('.dart_tool/package_config.json');
  expect(configFile.existsSync(), isTrue, reason: 'flutter pub get が先');

  final root = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final packages = root['packages'] as List<dynamic>;
  final package = packages.cast<Map<String, dynamic>>().where(
    (item) => item['name'] == name,
  );
  expect(package, isNotEmpty, reason: '$name が package_config.json に無い');

  return configFile.absolute.uri.resolve(package.first['rootUri'] as String);
}

/// dart2js は `'''` 直後の改行を注入文面に含めない（本番 main.dart.js と CSP ハッシュで確認）。
String _injectedScript(String template, String windowVar, String url) {
  var text = template;
  if (text.startsWith('\n')) {
    text = text.substring(1);
  }
  return text
      .replaceAll(r'$windowVar', windowVar)
      .replaceAll(r'$stringUrl', url);
}

String _cspSha256(String script) {
  final digest = sha256.convert(utf8.encode(script));
  return "'sha256-${base64.encode(digest.bytes)}'";
}

List<String> _extractFfTriggerTemplates(String source) {
  final templates = <String>[];
  var cursor = 0;
  while (true) {
    final start = source.indexOf("'''", cursor);
    if (start < 0) {
      break;
    }
    final end = source.indexOf("'''", start + 3);
    if (end < 0) {
      break;
    }
    final body = source.substring(start + 3, end);
    if (body.contains('ff_trigger_')) {
      templates.add(body);
    }
    cursor = end + 3;
  }
  return templates;
}
