import 'package:flutter/material.dart';

/// ダメージ数値をポップアップ表示するウィジェット
///
/// 生成されると自動的にアニメーション（跳ねてフェードアウト）を開始します。
/// [onComplete] コールバックでアニメーション終了を通知できます。
class DamagePopup extends StatefulWidget {
  final int value;
  final bool isCritical;
  final bool isHealing;
  final VoidCallback? onComplete;

  const DamagePopup({
    super.key,
    required this.value,
    this.isCritical = false,
    this.isHealing = false,
    this.onComplete,
  });

  @override
  State<DamagePopup> createState() => _DamagePopupState();
}

class _DamagePopupState extends State<DamagePopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // 拡大縮小（出現時に弾む）
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.5), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
    ]).animate(_controller);

    // 不透明度（最後だけフェードアウト）
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    // 位置（上に移動）
    _positionAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -1.5),
    ).animate(CurvedAnimation(
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

  @override
  Widget build(BuildContext context) {
    Color textColor;
    double fontSize;
    FontWeight fontWeight;
    String prefix = '';

    if (widget.isHealing) {
      textColor = const Color(0xFF00B894); // 緑
      fontSize = 24;
      fontWeight = FontWeight.bold;
      prefix = '+';
    } else {
      textColor = widget.isCritical
          ? const Color(0xFFFF7675) // 薄い赤
          : const Color(0xFFFFFFFF); // 白
      fontSize = widget.isCritical ? 32 : 24;
      fontWeight = widget.isCritical ? FontWeight.w900 : FontWeight.bold;
    }

    return SlideTransition(
      position: _positionAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Text(
            '$prefix${widget.value}',
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: fontWeight,
              shadows: [
                const Shadow(
                  offset: Offset(2, 2),
                  blurRadius: 4,
                  color: Colors.black54,
                ),
                if (widget.isCritical)
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 10,
                    color: textColor.withValues(alpha: 0.8),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
