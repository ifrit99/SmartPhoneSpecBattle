import 'dart:convert';
import 'dart:io';

/// `docs/perf/baselines.json` をログするだけ。
/// `threshold_ms` が null / 未設定、または計測ファイルが無ければ exit 0。
void main(List<String> args) {
  final baselinePath = _argValue(args, '--baselines') ??
      'docs/perf/baselines.json';
  final resultsPath = _argValue(args, '--results');

  final baselineFile = File(baselinePath);
  if (!baselineFile.existsSync()) {
    stdout.writeln('UX perf: $baselinePath が無い → measure-only (no fail)');
    return;
  }

  final root = jsonDecode(baselineFile.readAsStringSync());
  if (root is! Map<String, dynamic>) {
    stdout.writeln('UX perf: baselines の root が object ではない → skip fail');
    return;
  }
  final metrics = root['metrics'];
  if (metrics is! Map<String, dynamic>) {
    stdout.writeln('UX perf: metrics が無い → measure-only (no fail)');
    return;
  }

  final results = _readResults(resultsPath);
  var compared = 0;
  var failed = 0;

  for (final entry in metrics.entries) {
    final spec = entry.value;
    final threshold = spec is Map<String, dynamic> ? spec['threshold_ms'] : null;
    stdout.writeln('${entry.key}: threshold_ms=$threshold');
    if (threshold is! num) {
      stdout.writeln('  unset → measure-only (no fail)');
      continue;
    }
    final measured = results?[entry.key];
    if (measured == null) {
      stdout.writeln('  threshold はあるが CI 計測値が無い → skip fail');
      continue;
    }
    compared++;
    stdout.writeln('  measured_ms=$measured');
    if (measured > threshold.toDouble()) {
      failed++;
      stdout.writeln('  FAIL: $measured > $threshold');
    }
  }

  stdout.writeln('compared=$compared failed=$failed');
  if (failed > 0) {
    exit(1);
  }
}

Map<String, double>? _readResults(String? path) {
  if (path == null) {
    return null;
  }
  final file = File(path);
  if (!file.existsSync()) {
    stdout.writeln('UX perf: results $path が無い → skip comparison');
    return null;
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    return null;
  }
  final out = <String, double>{};
  for (final entry in decoded.entries) {
    final value = entry.value;
    if (value is num) {
      out[entry.key] = value.toDouble();
    } else if (value is Map<String, dynamic> && value['ms'] is num) {
      out[entry.key] = (value['ms'] as num).toDouble();
    }
  }
  return out;
}

String? _argValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}
