import 'package:flutter/material.dart';
import '../../domain/models/character.dart';
import '../../domain/enums/element_type.dart';

/// ドット絵風キャラクターを描画するウィジェット
/// アセット画像がない場合はCanvasでシンプルなピクセルキャラを描画
class PixelCharacter extends StatelessWidget {
  final Character character;
  final double size;
  final bool flipHorizontal;

  const PixelCharacter({
    Key key,
    this.character,
    this.size = 120,
    this.flipHorizontal = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: flipHorizontal
          ? (Matrix4.identity()..scale(-1.0, 1.0))
          : Matrix4.identity(),
      child: CustomPaint(
        size: Size(size, size),
        painter: _PixelCharacterPainter(
          character: character,
        ),
      ),
    );
  }
}

/// キャラクターのカラーパレット
List<Color> _getPalette(int index) {
  final palettes = [
    [Color(0xFFFF6B6B), Color(0xFFFF8E8E), Color(0xFFCC5555)], // 赤系
    [Color(0xFF4ECDC4), Color(0xFF7EDDD7), Color(0xFF3BA99E)], // 青緑系
    [Color(0xFFFFD93D), Color(0xFFFFE46D), Color(0xFFCCAD30)], // 黄系
    [Color(0xFF6C5CE7), Color(0xFF8F84ED), Color(0xFF5647BA)], // 紫系
    [Color(0xFF00B894), Color(0xFF33C9A8), Color(0xFF009577)], // 緑系
    [Color(0xFFFD79A8), Color(0xFFFE97BB), Color(0xFFCA6186)], // ピンク系
  ];
  return palettes[index % palettes.length];
}

/// 属性に対応する色
Color _elementColor(ElementType element) {
  switch (element) {
    case ElementType.fire:
      return Color(0xFFFF6B6B);
    case ElementType.water:
      return Color(0xFF74B9FF);
    case ElementType.earth:
      return Color(0xFFFDCB6E);
    case ElementType.wind:
      return Color(0xFF55EFC4);
    case ElementType.light:
      return Color(0xFFFFF176);
    case ElementType.dark:
      return Color(0xFFAB47BC);
  }
  return Colors.white;
}

class _PixelCharacterPainter extends CustomPainter {
  final Character character;

  _PixelCharacterPainter({this.character});

  @override
  void paint(Canvas canvas, Size size) {
    if (character == null) return;

    final palette = _getPalette(character.colorPaletteIndex);
    final pixelSize = size.width / 12;
    final elemColor = _elementColor(character.element);

    // 体のベースカラー
    final bodyPaint = Paint()..color = palette[0];
    final accentPaint = Paint()..color = palette[1];
    final shadowPaint = Paint()..color = palette[2];
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = Color(0xFF2D3436);

    // --- 頭の描画 (headIndex で形状を変える) ---
    final headShape = character.headIndex % 4;
    final headY = 1.0;
    switch (headShape) {
      case 0: // 丸頭
        _drawPixelRect(canvas, 4, headY, 4, 3, pixelSize, bodyPaint);
        _drawPixelRect(canvas, 3, headY + 0.5, 1, 2, pixelSize, bodyPaint);
        _drawPixelRect(canvas, 8, headY + 0.5, 1, 2, pixelSize, bodyPaint);
        break;
      case 1: // 角張った頭
        _drawPixelRect(canvas, 3, headY, 6, 3, pixelSize, bodyPaint);
        break;
      case 2: // とがった頭
        _drawPixelRect(canvas, 4, headY, 4, 3, pixelSize, bodyPaint);
        _drawPixelRect(canvas, 5, headY - 1, 2, 1, pixelSize, accentPaint);
        break;
      case 3: // 大きな頭
        _drawPixelRect(canvas, 3, headY, 6, 4, pixelSize, bodyPaint);
        break;
    }

    // 目
    _drawPixelRect(canvas, 4.5, headY + 1, 1, 1, pixelSize, eyePaint);
    _drawPixelRect(canvas, 6.5, headY + 1, 1, 1, pixelSize, eyePaint);
    _drawPixelRect(canvas, 4.8, headY + 1.2, 0.5, 0.5, pixelSize, pupilPaint);
    _drawPixelRect(canvas, 6.8, headY + 1.2, 0.5, 0.5, pixelSize, pupilPaint);

    // 口
    _drawPixelRect(canvas, 5.5, headY + 2.2, 1, 0.3, pixelSize, shadowPaint);

    // --- 体の描画 (bodyIndex で変化) ---
    final bodyY = headY + 3.5;
    final bodyWidth = 3 + (character.bodyIndex % 3);
    final bodyX = 6.0 - bodyWidth / 2;
    _drawPixelRect(canvas, bodyX, bodyY, bodyWidth.toDouble(), 3, pixelSize, bodyPaint);
    _drawPixelRect(canvas, bodyX + 0.5, bodyY + 0.5, bodyWidth.toDouble() - 1, 2, pixelSize, accentPaint);

    // 属性マーク
    _drawPixelRect(canvas, 5.5, bodyY + 1, 1, 1, pixelSize,
        Paint()..color = elemColor);

    // --- 腕の描画 (armIndex で変化) ---
    final armY = bodyY + 0.5;
    final armLength = 1.5 + (character.armIndex % 3) * 0.5;
    _drawPixelRect(canvas, bodyX - 1, armY, 1, armLength, pixelSize, bodyPaint);
    _drawPixelRect(canvas, bodyX + bodyWidth, armY, 1, armLength, pixelSize, bodyPaint);

    // --- 脚の描画 (legIndex で変化) ---
    final legY = bodyY + 3;
    final legWidth = 1.0 + (character.legIndex % 2) * 0.5;
    _drawPixelRect(canvas, bodyX + 0.5, legY, legWidth, 2, pixelSize, shadowPaint);
    _drawPixelRect(canvas, bodyX + bodyWidth - legWidth - 0.5, legY, legWidth, 2, pixelSize, shadowPaint);
  }

  void _drawPixelRect(Canvas canvas, double x, double y, double w, double h,
      double pixelSize, Paint paint) {
    canvas.drawRect(
      Rect.fromLTWH(x * pixelSize, y * pixelSize, w * pixelSize, h * pixelSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
