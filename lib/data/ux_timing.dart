import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// debug/profile 専用の UX 壁時計マーク。release では no-op。
///
/// メトリクス名と開始/終了点は `docs/adr/ux-perf-loop.md` が正本。
class UxTiming {
  UxTiming._();

  static const String coldToTitle = 'cold_to_title';
  static const String homeToPwrSheet = 'home_to_pwr_sheet';
  static const String rankingOptinDone = 'ranking_optin_done';

  static bool? _debugEnabledOverride;
  static final Map<String, Stopwatch> _watches = <String, Stopwatch>{};
  static final Map<String, Duration> _last = <String, Duration>{};
  static final Set<String> _pendingFrame = <String>{};

  /// release では false。テストから上書き可能。
  static bool get isEnabled =>
      _debugEnabledOverride ?? (kDebugMode || kProfileMode);

  /// テスト用: `null` で [kDebugMode] / [kProfileMode] に戻す。
  @visibleForTesting
  static set debugEnabledOverride(bool? value) {
    _debugEnabledOverride = value;
  }

  /// テスト用: 進行中の mark と最終値を捨てる。
  @visibleForTesting
  static void resetForTest() {
    _watches.clear();
    _last.clear();
    _pendingFrame.clear();
    _debugEnabledOverride = null;
  }

  /// 直近に閉じた [metric] の経過。未計測なら `null`。
  static Duration? last(String metric) => _last[metric];

  /// [metric] の計測を開始する。release では何もしない。
  static void markStart(String metric) {
    if (!isEnabled) {
      return;
    }
    _watches[metric] = Stopwatch()..start();
  }

  /// [metric] の計測を閉じ、`debugPrint` する。開始していなければ no-op。
  static void markEnd(String metric) {
    if (!isEnabled) {
      return;
    }
    final watch = _watches.remove(metric);
    if (watch == null) {
      return;
    }
    watch.stop();
    _last[metric] = watch.elapsed;
    debugPrint('[UxTiming] $metric ${watch.elapsedMilliseconds}ms');
  }

  /// 次のフレーム描画後に [markEnd] する。同じ [metric] の予約は1回だけ。
  static void markEndAfterFrame(String metric) {
    if (!isEnabled) {
      return;
    }
    if (!_watches.containsKey(metric) || _pendingFrame.contains(metric)) {
      return;
    }
    _pendingFrame.add(metric);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingFrame.remove(metric);
      markEnd(metric);
    });
  }
}
