import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('baselines の閾値未設定は CI fail 対象にしない', () {
    final file = File('docs/perf/baselines.json');
    expect(file.existsSync(), isTrue);

    final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final metrics = root['metrics'] as Map<String, dynamic>;

    const expected = <String>{
      'cold_to_title',
      'home_to_pwr_sheet',
      'ranking_optin_done',
    };
    expect(metrics.keys.toSet(), expected);

    for (final name in expected) {
      final spec = metrics[name] as Map<String, dynamic>;
      expect(
        spec['threshold_ms'],
        isNull,
        reason: '$name の threshold_ms が未設定なら fail しない',
      );
    }
  });
}
