import 'package:flutter/material.dart';

import '../../battle/battle_cue.dart';

/// ターンバッジ直下の小さなスキル名帯（RFC §2-3）。
class SkillNameBanner extends StatefulWidget {
  final String skillName;
  final Color color;
  final VoidCallback? onComplete;
  final double playbackSpeed;

  const SkillNameBanner({
    super.key,
    required this.skillName,
    required this.color,
    this.onComplete,
    this.playbackSpeed = 1.0,
  });

  @override
  State<SkillNameBanner> createState() => _SkillNameBannerState();
}

class _SkillNameBannerState extends State<SkillNameBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _notifiedComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: scaleDurationMs(600, widget.playbackSpeed)),
    );
    _controller.forward().then((_) {
      if (mounted) {
        _notifyComplete();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _notifyComplete();
    }
  }

  void _notifyComplete() {
    if (_notifiedComplete) {
      return;
    }
    _notifiedComplete = true;
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// fade in 80 / hold 400 / fade out 120（合計 600ms の比率）。
  double get _opacity {
    final t = _controller.value;
    if (t < 80 / 600) {
      return t / (80 / 600);
    }
    if (t < 480 / 600) {
      return 1;
    }
    return ((1 - t) / (120 / 600)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.clamp(0.0, 1.0),
          child: child,
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          border: Border.all(color: widget.color, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Text(
            widget.skillName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
