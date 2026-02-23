import 'package:flutter/material.dart';
import '../../domain/enums/element_type.dart';

/// スキル発動時のエフェクトオーバーレイ
class SkillEffectOverlay extends StatefulWidget {
  final String skillName;
  final ElementType element;
  final VoidCallback? onComplete;

  const SkillEffectOverlay({
    super.key,
    required this.skillName,
    required this.element,
    this.onComplete,
  });

  @override
  State<SkillEffectOverlay> createState() => _SkillEffectOverlayState();
}

class _SkillEffectOverlayState extends State<SkillEffectOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.2), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getElementColor(ElementType element) {
    switch (element) {
      case ElementType.fire:
        return const Color(0xFFFF6B6B);
      case ElementType.water:
        return const Color(0xFF74B9FF);
      case ElementType.earth:
        return const Color(0xFFFDCB6E);
      case ElementType.wind:
        return const Color(0xFF55EFC4);
      case ElementType.light:
        return const Color(0xFFFFF176);
      case ElementType.dark:
        return const Color(0xFFAB47BC);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getElementColor(widget.element);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.value == 0 || _controller.value == 1) {
          return const SizedBox.shrink();
        }
        return Container(
          color: color.withValues(alpha: 0.2 * _opacityAnimation.value),
          child: Center(
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    border: Border.all(
                      color: color,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SKILL ACTIVATE',
                        style: TextStyle(
                          color: color.withValues(alpha: 0.8),
                          fontSize: 12,
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.skillName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: Colors.black,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
