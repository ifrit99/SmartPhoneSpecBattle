import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../battle/battle_cue.dart';

/// 単一 Ticker で寿命管理する VFX キュー（RFC §4-1）。
class BattleVfxController extends ChangeNotifier {
  final List<BattleVfxEvent> _events = <BattleVfxEvent>[];
  int _seq = 0;

  List<BattleVfxEvent> get events => List<BattleVfxEvent>.unmodifiable(_events);

  bool get isEmpty => _events.isEmpty;

  void Function(BattleVfxEvent event)? _onSpawn;

  /// [kind] をターゲット矩形中心に出す。crit は slash 3本＋白フラッシュ。
  void spawn(
    VfxKind kind, {
    required Rect target,
    required Color color,
    bool crit = false,
  }) {
    _seq += 1;
    final event = BattleVfxEvent(
      id: _seq,
      kind: kind,
      target: target,
      color: color,
      crit: crit,
      seed: Object.hash(_seq, kind, target.center.dx.round()),
      createdAtMs: 0,
      durationMs: _durationMs(kind),
    );
    _events.add(event);
    _onSpawn?.call(event);
    notifyListeners();
  }

  /// 進行中の粒を破棄する（スキップ用）。
  void clear() {
    if (_events.isEmpty) {
      return;
    }
    _events.clear();
    notifyListeners();
  }

  void _bind(void Function(BattleVfxEvent event) onSpawn) {
    _onSpawn = onSpawn;
  }

  void _unbind() {
    _onSpawn = null;
  }

  void _prune(int nowMs) {
    _events.removeWhere((e) => nowMs - e.createdAtMs >= e.durationMs);
  }

  static int _durationMs(VfxKind kind) {
    return switch (kind) {
      VfxKind.flash => 160,
      VfxKind.slash => 180,
      VfxKind.burst => 320,
      VfxKind.ring => 300,
      VfxKind.sparkle => 500,
      VfxKind.crit => 180,
    };
  }
}

/// 1 件の VFX。軌道は [seed] から毎フレーム再計算する。
class BattleVfxEvent {
  final int id;
  final VfxKind kind;
  final Rect target;
  final Color color;
  final bool crit;
  final int seed;
  final int createdAtMs;
  final int durationMs;

  const BattleVfxEvent({
    required this.id,
    required this.kind,
    required this.target,
    required this.color,
    required this.crit,
    required this.seed,
    required this.createdAtMs,
    required this.durationMs,
  });

  BattleVfxEvent copyWithCreatedAt(int createdAtMs) {
    return BattleVfxEvent(
      id: id,
      kind: kind,
      target: target,
      color: color,
      crit: crit,
      seed: seed,
      createdAtMs: createdAtMs,
      durationMs: durationMs,
    );
  }

  double progress(int nowMs) {
    if (durationMs <= 0) {
      return 1;
    }
    return ((nowMs - createdAtMs) / durationMs).clamp(0.0, 1.0);
  }
}

/// 粒の正規化距離 0→1。`Curves.easeOutCubic`（速く出てゆっくり止まる）。
double particleDistance(double t) {
  return Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
}

/// burst の最大落下（charSize 比）。ガイド §4 候補 2 の 0.1〜0.15。
const double burstFallFactor = 0.12;

/// burst の下方向落下（論理 px）。`t²` に比例して 0 → [burstFallFactor] × charSize。
double burstFall(double t, double charSize) {
  final x = t.clamp(0.0, 1.0);
  return burstFallFactor * charSize * x * x;
}

/// 粒の不透明度。t=0.6 まで 1、その後線形で t=1 に 0。
double particleAlpha(double t) {
  final x = t.clamp(0.0, 1.0);
  if (x <= 0.6) {
    return 1.0;
  }
  return (1.0 - x) / 0.4;
}

/// フィールド全面に 1 枚置く VFX。VFX ごとの AnimationController は持たない。
class BattleVfxLayer extends StatefulWidget {
  final BattleVfxController controller;
  final double playbackSpeed;

  const BattleVfxLayer({
    super.key,
    required this.controller,
    this.playbackSpeed = 1.0,
  });

  @override
  State<BattleVfxLayer> createState() => _BattleVfxLayerState();
}

class _BattleVfxLayerState extends State<BattleVfxLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _elapsedMs = 0;
  bool _ticking = false;

  final Paint _fillPaint = Paint()..isAntiAlias = false;
  final Paint _strokePaint = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _linePaint = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.square
    ..strokeWidth = 3;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.controller._bind(_onSpawn);
    widget.controller.addListener(_onController);
  }

  @override
  void didUpdateWidget(covariant BattleVfxLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._unbind();
      oldWidget.controller.removeListener(_onController);
      widget.controller._bind(_onSpawn);
      widget.controller.addListener(_onController);
    }
  }

  @override
  void dispose() {
    widget.controller._unbind();
    widget.controller.removeListener(_onController);
    _ticker.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  void _onSpawn(BattleVfxEvent event) {
    if (_reduceMotion) {
      widget.controller._events.remove(event);
      return;
    }
    final scaled = scaleDurationMs(event.durationMs, widget.playbackSpeed);
    final started = event.copyWithCreatedAt(_elapsedMs).copyWithDuration(scaled);
    final index = widget.controller._events.indexWhere((e) => e.id == event.id);
    if (index >= 0) {
      widget.controller._events[index] = started;
    }
    _ensureTicking();
  }

  void _onController() {
    if (widget.controller.isEmpty) {
      _stopTicker();
    } else {
      _ensureTicking();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _ensureTicking() {
    if (!_ticking) {
      _ticking = true;
      _ticker.start();
    }
  }

  void _stopTicker() {
    if (_ticking) {
      _ticking = false;
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    _elapsedMs = elapsed.inMilliseconds;
    widget.controller._prune(_elapsedMs);
    if (widget.controller.isEmpty) {
      _stopTicker();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BattleVfxPainter(
          events: widget.controller.events,
          nowMs: _elapsedMs,
          fillPaint: _fillPaint,
          strokePaint: _strokePaint,
          linePaint: _linePaint,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

extension on BattleVfxEvent {
  BattleVfxEvent copyWithDuration(int durationMs) {
    return BattleVfxEvent(
      id: id,
      kind: kind,
      target: target,
      color: color,
      crit: crit,
      seed: seed,
      createdAtMs: createdAtMs,
      durationMs: durationMs,
    );
  }
}

double slashLength(double t) {
  return (t / 0.2).clamp(0.0, 1.0);
}

double slashAlpha(double t) {
  if (t <= 0.45) {
    return 1.0;
  }
  return ((1.0 - t) / 0.55).clamp(0.0, 1.0);
}

class _BattleVfxPainter extends CustomPainter {
  final List<BattleVfxEvent> events;
  final int nowMs;
  final Paint fillPaint;
  final Paint strokePaint;
  final Paint linePaint;

  _BattleVfxPainter({
    required this.events,
    required this.nowMs,
    required this.fillPaint,
    required this.strokePaint,
    required this.linePaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final event in events) {
      final t = event.progress(nowMs);
      switch (event.kind) {
        case VfxKind.flash:
          _paintFlash(canvas, size, event, t);
        case VfxKind.slash:
          _paintSlash(canvas, event, t);
        case VfxKind.burst:
          _paintBurst(canvas, event, t);
        case VfxKind.ring:
          _paintRing(canvas, event, t);
        case VfxKind.sparkle:
          _paintSparkle(canvas, event, t);
        case VfxKind.crit:
          _paintFlash(canvas, size, event, t, white: true);
      }
    }
  }

  void _paintFlash(
    Canvas canvas,
    Size size,
    BattleVfxEvent event,
    double t, {
    bool white = false,
  }) {
    final peak = (event.crit || white) ? 0.50 : 0.35;
    fillPaint.color = (white ? Colors.white : event.color)
        .withValues(alpha: peak * (1 - t));
    canvas.drawRect(Offset.zero & size, fillPaint);
  }

  void _paintSlash(Canvas canvas, BattleVfxEvent event, double t) {
    final center = event.target.center;
    final charSize = math.min(event.target.width, event.target.height);
    final length = charSize * 1.2 * slashLength(t);
    final alpha = slashAlpha(t);
    final count = event.crit ? 3 : 2;
    const angles = <double>[-0.7, 0.7, 0.0];
    for (var i = 0; i < count; i++) {
      final angle = angles[i];
      final dx = math.cos(angle) * length / 2;
      final dy = math.sin(angle) * length / 2;
      final a = center.translate(-dx, -dy);
      final b = center.translate(dx, dy);
      linePaint
        ..color = event.color.withValues(alpha: alpha)
        ..strokeWidth = 5;
      canvas.drawLine(a, b, linePaint);
      linePaint
        ..color = Colors.white.withValues(alpha: alpha)
        ..strokeWidth = 3;
      canvas.drawLine(a, b, linePaint);
    }
  }

  void _paintBurst(Canvas canvas, BattleVfxEvent event, double t) {
    final center = event.target.center;
    final charSize = math.min(event.target.width, event.target.height);
    final rng = math.Random(event.seed);
    final count = 8 + rng.nextInt(5);
    final dist = 0.6 * charSize * particleDistance(t);
    final fall = burstFall(t, charSize);
    final alpha = particleAlpha(t);
    for (var i = 0; i < count; i++) {
      final angle = (2 * math.pi * i / count) + rng.nextDouble() * 0.2;
      // 粒は 2 / 3 / 4px の正方形のみ。burst は 3 か 4。
      final particleSize = 3.0 + rng.nextInt(2);
      final pos = Offset(
        (center.dx + math.cos(angle) * dist).roundToDouble(),
        (center.dy + math.sin(angle) * dist + fall).roundToDouble(),
      );
      fillPaint.color = event.color.withValues(alpha: alpha);
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: particleSize, height: particleSize),
        fillPaint,
      );
    }
  }

  void _paintRing(Canvas canvas, BattleVfxEvent event, double t) {
    final center = event.target.center;
    final charSize = math.min(event.target.width, event.target.height);
    final radius = charSize * (0.3 + 0.5 * t);
    strokePaint
      ..color = event.color.withValues(alpha: 1 - t)
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, strokePaint);
  }

  void _paintSparkle(Canvas canvas, BattleVfxEvent event, double t) {
    final feet = Offset(event.target.center.dx, event.target.bottom);
    final charSize = math.min(event.target.width, event.target.height);
    final rng = math.Random(event.seed);
    final rise = 0.5 * charSize * particleDistance(t);
    final alpha = particleAlpha(t);
    for (var i = 0; i < 6; i++) {
      final drift = (rng.nextDouble() - 0.5) * charSize * 0.4;
      final pos = Offset(
        (feet.dx + drift).roundToDouble(),
        (feet.dy - rise).roundToDouble(),
      );
      fillPaint.color = event.color.withValues(alpha: alpha);
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: 2, height: 2),
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BattleVfxPainter oldDelegate) {
    return oldDelegate.nowMs != nowMs ||
        oldDelegate.events.length != events.length ||
        !identical(oldDelegate.events, events);
  }
}
