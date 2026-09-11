import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/models/character.dart';
import '../../battle/battle_cue.dart';
import '../../theme/app_colors.dart';
import '../character_portrait.dart';

/// バトルスプライトの排他ステートを再生するコントローラ（RFC §4-1）。
class BattleSpriteController extends ChangeNotifier {
  SpriteState _state = SpriteState.idle;

  /// 現在の排他ステート。
  SpriteState get state => _state;

  void Function(SpriteState state)? _onPlay;
  VoidCallback? _onStopAll;

  /// [s] を排他で再生する。完了で idle に戻る（victory / defeat は除く）。
  void play(SpriteState s) {
    _state = s;
    final handler = _onPlay;
    if (handler != null) {
      handler(s);
    }
    notifyListeners();
  }

  /// 進行中の演出を止め、idle に戻す（スキップ用）。
  void stopAll() {
    _state = SpriteState.idle;
    _onStopAll?.call();
    notifyListeners();
  }

  void _bind({
    required void Function(SpriteState state) onPlay,
    required VoidCallback onStopAll,
  }) {
    _onPlay = onPlay;
    _onStopAll = onStopAll;
  }

  void _unbind() {
    _onPlay = null;
    _onStopAll = null;
  }

  void _setState(SpriteState s) {
    if (_state == s) {
      return;
    }
    _state = s;
    notifyListeners();
  }
}

/// `CharacterPortrait(variant: battle)` を包み、ボブ・突進・ティントを外側から掛ける。
class BattleSprite extends StatefulWidget {
  final Character character;
  final double height;
  final bool flipHorizontal;
  final BattleSpriteController controller;
  final double playbackSpeed;

  const BattleSprite({
    super.key,
    required this.character,
    required this.height,
    required this.controller,
    this.flipHorizontal = false,
    this.playbackSpeed = 1.0,
  });

  @override
  State<BattleSprite> createState() => _BattleSpriteState();
}

class _BattleSpriteState extends State<BattleSprite>
    with TickerProviderStateMixin {
  static const Color _healTint = Color(0xFF00B894);

  /// 彩度を 60% 落とす行列（RFC §2-1 defeat）。
  static const List<double> _defeatGrayMatrix = <double>[
    0.52756, 0.42912, 0.04332, 0, 0,
    0.52756, 0.42912, 0.04332, 0, 0,
    0.52756, 0.42912, 0.04332, 0, 0,
    0, 0, 0, 1, 0,
  ];

  late final AnimationController _idle;
  late final AnimationController _action;
  SpriteState _actionState = SpriteState.idle;

  /// 相手方向。自は +x、敵は −x（RFC §2-1）。
  int get _lungeSign => widget.flipHorizontal ? -1 : 1;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _action = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _action.addStatusListener(_onActionStatus);
    _action.addListener(_onActionTick);
    widget.controller._bind(onPlay: _play, onStopAll: _stopAll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncIdleBob();
  }

  @override
  void didUpdateWidget(covariant BattleSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._unbind();
      widget.controller._bind(onPlay: _play, onStopAll: _stopAll);
    }
  }

  @override
  void dispose() {
    widget.controller._unbind();
    _idle.dispose();
    _action.dispose();
    super.dispose();
  }

  void _syncIdleBob() {
    if (_reduceMotion) {
      _idle.stop();
      _idle.value = 0;
      return;
    }
    if (!_idle.isAnimating) {
      _idle.repeat();
    }
  }

  int _durationMs(SpriteState state) {
    final base = switch (state) {
      SpriteState.attack => 300,
      SpriteState.cast => 360,
      SpriteState.hit => 300,
      SpriteState.guard => 300,
      SpriteState.heal => 500,
      SpriteState.victory => 400,
      SpriteState.defeat => 600,
      SpriteState.idle => 0,
    };
    return scaleDurationMs(base, widget.playbackSpeed);
  }

  void _play(SpriteState state) {
    if (state == SpriteState.idle) {
      _stopAll();
      return;
    }
    _actionState = state;
    final ms = _durationMs(state);
    _action.stop();
    _action.duration = Duration(milliseconds: math.max(ms, 1));
    if (_reduceMotion || ms == 0) {
      _action.value = 1;
      _finishAction(state);
      return;
    }
    _action.reset();
    _action.forward();
  }

  void _onActionStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _finishAction(_actionState);
    }
  }

  void _onActionTick() {
    if (_action.isCompleted) {
      _finishAction(_actionState);
    }
  }

  void _finishAction(SpriteState state) {
    if (state == SpriteState.victory || state == SpriteState.defeat) {
      widget.controller._setState(state);
      return;
    }
    if (state == SpriteState.idle || _actionState == SpriteState.idle) {
      return;
    }
    _actionState = SpriteState.idle;
    widget.controller._setState(SpriteState.idle);
    if (mounted) {
      setState(() {});
    }
  }

  void _stopAll() {
    _action.stop();
    _action.value = 0;
    _actionState = SpriteState.idle;
    widget.controller._setState(SpriteState.idle);
    if (mounted) {
      setState(() {});
    }
  }

  double get _bobY {
    if (_reduceMotion) {
      return 0;
    }
    final amp = widget.height >= 96 ? 2.0 : 1.0;
    final phase = widget.flipHorizontal ? math.pi : 0.0;
    return amp * math.sin(2 * math.pi * _idle.value + phase);
  }

  _SpritePose _pose() {
    final t = _action.value;
    final size = widget.height;
    final sign = _lungeSign.toDouble();
    switch (_actionState) {
      case SpriteState.idle:
        return const _SpritePose();
      case SpriteState.attack:
        return _SpritePose(dx: sign * 0.12 * size * _lungeProgress(t));
      case SpriteState.cast:
        return _castPose(t, size, sign);
      case SpriteState.hit:
        return _hitPose(t, sign);
      case SpriteState.guard:
        return _SpritePose(
          dx: -sign * 0.06 * size,
          showGuard: t < 1,
        );
      case SpriteState.heal:
        return _SpritePose(healTint: 0.30 * math.sin(math.pi * t));
      case SpriteState.victory:
        return _SpritePose(dy: _victoryY(t, size));
      case SpriteState.defeat:
        return _SpritePose(
          dy: 0.04 * size * t,
          opacity: 1 - 0.65 * t,
          grayscale: true,
        );
    }
  }

  /// 行き 40%（120ms / 300ms）easeOut、戻り 60% easeIn。
  double _lungeProgress(double t) {
    if (t <= 0.4) {
      return Curves.easeOut.transform(t / 0.4);
    }
    return 1 - Curves.easeIn.transform((t - 0.4) / 0.6);
  }

  _SpritePose _castPose(double t, double size, double sign) {
    // 前半で浮き、後半で 6% 前進して戻る（skill の「lunge 後半」）。
    final floatT = t <= 0.4 ? Curves.easeOut.transform(t / 0.4) : 1.0;
    final sinkT = t <= 0.4 ? 0.0 : Curves.easeIn.transform((t - 0.4) / 0.6);
    final dy = -0.06 * size * (floatT * (1 - sinkT));
    final lunge = t <= 0.4 ? 0.0 : _lungeProgress((t - 0.4) / 0.6);
    return _SpritePose(
      dx: sign * 0.06 * size * lunge,
      dy: dy,
      castTint: 0.40 * (1 - sinkT).clamp(0.0, 1.0),
    );
  }

  _SpritePose _hitPose(double t, double sign) {
    final go = t <= 0.5 ? t / 0.5 : (1 - t) / 0.5;
    final shake = 8 * Curves.elasticIn.transform(go.clamp(0.0, 1.0));
    final ms = t * 300;
    final blinkOn = (ms < 60) || (ms >= 100 && ms < 160);
    return _SpritePose(
      dx: -sign * shake,
      hitTint: blinkOn && t < 1,
    );
  }

  double _victoryY(double t, double size) {
    final hop = t < 0.5 ? t / 0.5 : (t - 0.5) / 0.5;
    final up = hop <= 0.5;
    final local = up ? hop / 0.5 : (hop - 0.5) / 0.5;
    final curved = up
        ? Curves.easeOut.transform(local)
        : 1 - Curves.bounceOut.transform(local);
    return -0.10 * size * curved;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _action]),
      builder: (context, child) {
        final pose = _pose();
        final dx = pose.dx.roundToDouble();
        final dy = (pose.dy + _bobY).roundToDouble();
        Widget portrait = CharacterPortrait(
          character: widget.character,
          variant: PortraitVariant.battle,
          height: widget.height,
          flipHorizontal: widget.flipHorizontal,
        );
        if (pose.showGuard) {
          portrait = Stack(
            alignment: Alignment.center,
            children: [
              portrait,
              CustomPaint(
                size: Size(widget.height, widget.height),
                painter: _GuardShieldPainter(
                  color: elementColor(widget.character.element),
                  towardSign: _lungeSign,
                ),
              ),
            ],
          );
        }
        final filter = _colorFilter(pose);
        if (filter != null) {
          portrait = ColorFiltered(colorFilter: filter, child: portrait);
        }
        if (pose.opacity < 1) {
          portrait = Opacity(opacity: pose.opacity, child: portrait);
        }
        return RepaintBoundary(
          child: SizedBox(
            width: widget.height,
            height: widget.height,
            child: Transform.translate(
              key: const ValueKey<String>('battle_sprite_offset'),
              offset: Offset(dx, dy),
              child: portrait,
            ),
          ),
        );
      },
    );
  }

  ColorFilter? _colorFilter(_SpritePose pose) {
    if (pose.grayscale) {
      return const ColorFilter.matrix(_defeatGrayMatrix);
    }
    if (pose.hitTint) {
      return const ColorFilter.mode(Colors.white, BlendMode.srcATop);
    }
    if (pose.castTint > 0) {
      return ColorFilter.mode(
        elementColor(widget.character.element)
            .withValues(alpha: pose.castTint),
        BlendMode.srcATop,
      );
    }
    if (pose.healTint > 0) {
      return ColorFilter.mode(
        _healTint.withValues(alpha: pose.healTint),
        BlendMode.srcATop,
      );
    }
    return null;
  }
}

class _SpritePose {
  final double dx;
  final double dy;
  final double opacity;
  final double castTint;
  final double healTint;
  final bool hitTint;
  final bool grayscale;
  final bool showGuard;

  const _SpritePose({
    this.dx = 0,
    this.dy = 0,
    this.opacity = 1,
    this.castTint = 0,
    this.healTint = 0,
    this.hitTint = false,
    this.grayscale = false,
    this.showGuard = false,
  });
}

/// 防御時に前面へ置く細い縦長楕円。
class _GuardShieldPainter extends CustomPainter {
  final Color color;
  final int towardSign;

  _GuardShieldPainter({
    required this.color,
    required this.towardSign,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2 + towardSign * size.width * 0.22,
      size.height / 2,
    );
    final rect = Rect.fromCenter(
      center: center,
      width: size.width * 0.16,
      height: size.height * 0.72,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(covariant _GuardShieldPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.towardSign != towardSign;
  }
}
