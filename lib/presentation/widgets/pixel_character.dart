import 'package:flutter/material.dart';
import '../../domain/models/character.dart';
import '../theme/app_colors.dart';

/// ドット絵風キャラクターを描画するウィジェット
/// アセット画像がない場合はCanvasでシンプルなピクセルキャラを描画
class PixelCharacter extends StatelessWidget {
  final Character character;
  final double size;
  final bool flipHorizontal;

  const PixelCharacter({
    super.key,
    required this.character,
    this.size = 120,
    this.flipHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: flipHorizontal
          ? (Matrix4.identity()..setEntry(0, 0, -1.0))
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

/// キャラクターのカラーパレット（12種）
List<Color> _getPalette(int index) {
  final palettes = [
    [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E), const Color(0xFFCC5555)], // 赤系
    [const Color(0xFF4ECDC4), const Color(0xFF7EDDD7), const Color(0xFF3BA99E)], // 青緑系
    [const Color(0xFFFFD93D), const Color(0xFFFFE46D), const Color(0xFFCCAD30)], // 黄系
    [const Color(0xFF6C5CE7), const Color(0xFF8F84ED), const Color(0xFF5647BA)], // 紫系
    [const Color(0xFF00B894), const Color(0xFF33C9A8), const Color(0xFF009577)], // 緑系
    [const Color(0xFFFD79A8), const Color(0xFFFE97BB), const Color(0xFFCA6186)], // ピンク系
    [const Color(0xFFFF9F43), const Color(0xFFFFB976), const Color(0xFFCC7F36)], // オレンジ系
    [const Color(0xFF54A0FF), const Color(0xFF87BDFF), const Color(0xFF4380CC)], // スカイブルー系
    [const Color(0xFFDFE6E9), const Color(0xFFF5F8FA), const Color(0xFFB2BEC3)], // 白銀系
    [const Color(0xFF40407A), const Color(0xFF606498), const Color(0xFF2C2C54)], // 黒紫系
    [const Color(0xFFA3CB38), const Color(0xFFBEDB6A), const Color(0xFF82A22D)], // ライム系
    [const Color(0xFFF6B93B), const Color(0xFFFAD390), const Color(0xFFC4932F)], // ゴールド系
  ];
  return palettes[index % palettes.length];
}

// elementColor は element_type.dart から利用

class _PixelCharacterPainter extends CustomPainter {
  final Character character;

  _PixelCharacterPainter({required this.character});

  @override
  void paint(Canvas canvas, Size size) {
    final palette = _getPalette(character.colorPaletteIndex);
    final pixelSize = size.width / 12;
    final elemColor = elementColor(character.element);

    // 体のベースカラー
    final bodyPaint = Paint()..color = palette[0];
    final accentPaint = Paint()..color = palette[1];
    final shadowPaint = Paint()..color = palette[2];
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF2D3436);

    // --- オーラ（キャラの背面に描画） ---
    _drawAura(canvas, pixelSize, elemColor);

    // --- 頭の描画 (headIndex で形状を変える) ---
    final headShape = character.headIndex % 8;
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
      case 4: // ヘルメット頭（上部にバイザー縁）
        _drawPixelRect(canvas, 3.5, headY, 5, 3, pixelSize, bodyPaint);
        _drawPixelRect(canvas, 3, headY - 0.5, 6, 1, pixelSize, shadowPaint);
        break;
      case 5: // ツインヘッド（左右に出っ張り）
        _drawPixelRect(canvas, 4, headY, 4, 3, pixelSize, bodyPaint);
        _drawPixelRect(canvas, 2.5, headY - 0.5, 1.5, 1.5, pixelSize, accentPaint);
        _drawPixelRect(canvas, 8, headY - 0.5, 1.5, 1.5, pixelSize, accentPaint);
        break;
      case 6: // フード頭（丸み+下に影）
        _drawPixelRect(canvas, 3.5, headY - 0.5, 5, 1, pixelSize, shadowPaint);
        _drawPixelRect(canvas, 3, headY + 0.5, 6, 2.5, pixelSize, bodyPaint);
        break;
      case 7: // モヒカン頭（中央に縦の飾り）
        _drawPixelRect(canvas, 4, headY, 4, 3, pixelSize, bodyPaint);
        _drawPixelRect(canvas, 5.5, headY - 1, 1, 1.2, pixelSize, accentPaint);
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
    final bodyShape = character.bodyIndex % 6;
    final double bodyWidth;
    final double bodyX;
    switch (bodyShape) {
      case 0:
      case 1:
      case 2: // 標準（幅違い 3-5）
        bodyWidth = (3 + bodyShape).toDouble();
        bodyX = 6.0 - bodyWidth / 2;
        _drawPixelRect(canvas, bodyX, bodyY, bodyWidth, 3, pixelSize, bodyPaint);
        _drawPixelRect(canvas, bodyX + 0.5, bodyY + 0.5, bodyWidth - 1, 2, pixelSize, accentPaint);
        break;
      case 3: // 逆三角（上が広い）
        bodyWidth = 5;
        bodyX = 6.0 - bodyWidth / 2;
        _drawPixelRect(canvas, bodyX, bodyY, bodyWidth, 1.5, pixelSize, bodyPaint);
        _drawPixelRect(canvas, bodyX + 1, bodyY + 1.5, bodyWidth - 2, 1.5, pixelSize, bodyPaint);
        _drawPixelRect(canvas, bodyX + 0.5, bodyY + 0.4, bodyWidth - 1, 0.8, pixelSize, accentPaint);
        break;
      case 4: // 丸型（中央膨らみ）
        bodyWidth = 4;
        bodyX = 6.0 - bodyWidth / 2;
        _drawPixelRect(canvas, bodyX - 0.5, bodyY + 0.7, bodyWidth + 1, 1.6, pixelSize, bodyPaint);
        _drawPixelRect(canvas, bodyX, bodyY, bodyWidth, 3, pixelSize, bodyPaint);
        _drawPixelRect(canvas, bodyX + 0.5, bodyY + 0.5, bodyWidth - 1, 2, pixelSize, accentPaint);
        break;
      default: // 5: スリム+ベルト
        bodyWidth = 3;
        bodyX = 6.0 - bodyWidth / 2;
        _drawPixelRect(canvas, bodyX, bodyY, bodyWidth, 3, pixelSize, bodyPaint);
        _drawPixelRect(canvas, bodyX, bodyY + 1.8, bodyWidth, 0.6, pixelSize, shadowPaint);
        break;
    }

    // 属性マーク
    final elemPaint = Paint()..color = elemColor;
    _drawPixelRect(canvas, 5.5, bodyY + 1, 1, 1, pixelSize, elemPaint);

    // --- 腕の描画 (armIndex で変化) ---
    final armShape = character.armIndex % 5;
    switch (armShape) {
      case 0:
      case 1:
      case 2: // 長さ違い（1.5 / 2.0 / 2.5）
        final armY = bodyY + 0.5;
        final armLength = 1.5 + armShape * 0.5;
        _drawPixelRect(canvas, bodyX - 1, armY, 1, armLength, pixelSize, bodyPaint);
        _drawPixelRect(canvas, bodyX + bodyWidth, armY, 1, armLength, pixelSize, bodyPaint);
        break;
      case 3: // 太腕
        final armY = bodyY + 0.4;
        _drawPixelRect(canvas, bodyX - 1.5, armY, 1.5, 2, pixelSize, bodyPaint);
        _drawPixelRect(canvas, bodyX + bodyWidth, armY, 1.5, 2, pixelSize, bodyPaint);
        break;
      default: // 4: バンザイ腕（上向き）
        final armY = bodyY - 1;
        _drawPixelRect(canvas, bodyX - 1, armY, 1, 2, pixelSize, bodyPaint);
        _drawPixelRect(canvas, bodyX + bodyWidth, armY, 1, 2, pixelSize, bodyPaint);
        break;
    }

    // --- 脚の描画 (legIndex で変化) ---
    final legY = bodyY + 3;
    final legShape = character.legIndex % 5;
    switch (legShape) {
      case 0:
      case 1: // 幅違い（1.0 / 1.5）
        final legWidth = 1.0 + legShape * 0.5;
        _drawPixelRect(canvas, bodyX + 0.5, legY, legWidth, 2, pixelSize, shadowPaint);
        _drawPixelRect(canvas, bodyX + bodyWidth - legWidth - 0.5, legY, legWidth, 2, pixelSize, shadowPaint);
        break;
      case 2: // 長い脚
        _drawPixelRect(canvas, bodyX + 0.5, legY, 1, 2.5, pixelSize, shadowPaint);
        _drawPixelRect(canvas, bodyX + bodyWidth - 1.5, legY, 1, 2.5, pixelSize, shadowPaint);
        break;
      case 3: // ワイドスタンス（外寄り）
        _drawPixelRect(canvas, bodyX, legY, 1, 2, pixelSize, shadowPaint);
        _drawPixelRect(canvas, bodyX + bodyWidth - 1, legY, 1, 2, pixelSize, shadowPaint);
        break;
      default: // 4: 一本足（中央太）
        _drawPixelRect(canvas, 6.0 - 0.9, legY, 1.8, 2, pixelSize, shadowPaint);
        break;
    }

    // --- アクセサリー（最前面に描画） ---
    _drawAccessory(canvas, pixelSize, headY, bodyY, accentPaint, shadowPaint);
  }

  /// アクセサリーの描画（accessoryIndex: 0 = なし）
  void _drawAccessory(
    Canvas canvas,
    double pixelSize,
    double headY,
    double bodyY,
    Paint accentPaint,
    Paint shadowPaint,
  ) {
    final accessory = character.accessoryIndex % 8;
    switch (accessory) {
      case 0: // なし
        break;
      case 1: // アンテナ
        final paint = Paint()..color = const Color(0xFFB2BEC3);
        final tip = Paint()..color = const Color(0xFFFF6B6B);
        _drawPixelRect(canvas, 5.8, headY - 1.2, 0.4, 1.4, pixelSize, paint);
        _drawPixelRect(canvas, 5.6, headY - 1.6, 0.8, 0.6, pixelSize, tip);
        break;
      case 2: // とんがり帽
        final paint = Paint()..color = const Color(0xFF6C5CE7);
        _drawPixelRect(canvas, 4, headY - 0.4, 4, 0.6, pixelSize, paint);
        _drawPixelRect(canvas, 4.8, headY - 1.1, 2.4, 0.8, pixelSize, paint);
        _drawPixelRect(canvas, 5.5, headY - 1.8, 1, 0.8, pixelSize, paint);
        break;
      case 3: // ツノ
        final paint = Paint()..color = const Color(0xFFFFD93D);
        _drawPixelRect(canvas, 3.6, headY - 0.8, 0.8, 1.2, pixelSize, paint);
        _drawPixelRect(canvas, 7.6, headY - 0.8, 0.8, 1.2, pixelSize, paint);
        break;
      case 4: // 王冠
        final paint = Paint()..color = const Color(0xFFF6B93B);
        _drawPixelRect(canvas, 4.2, headY - 0.6, 3.6, 0.7, pixelSize, paint);
        _drawPixelRect(canvas, 4.2, headY - 1.2, 0.7, 0.7, pixelSize, paint);
        _drawPixelRect(canvas, 5.65, headY - 1.2, 0.7, 0.7, pixelSize, paint);
        _drawPixelRect(canvas, 7.1, headY - 1.2, 0.7, 0.7, pixelSize, paint);
        break;
      case 5: // リボン
        final paint = Paint()..color = const Color(0xFFFD79A8);
        _drawPixelRect(canvas, 7.2, headY - 0.7, 0.9, 0.9, pixelSize, paint);
        _drawPixelRect(canvas, 8.2, headY - 0.7, 0.9, 0.9, pixelSize, paint);
        _drawPixelRect(canvas, 7.9, headY - 0.4, 0.5, 0.5, pixelSize, shadowPaint);
        break;
      case 6: // サングラス
        final paint = Paint()..color = const Color(0xFF2D3436);
        _drawPixelRect(canvas, 4.2, headY + 1, 1.6, 0.9, pixelSize, paint);
        _drawPixelRect(canvas, 6.2, headY + 1, 1.6, 0.9, pixelSize, paint);
        _drawPixelRect(canvas, 5.6, headY + 1.2, 0.8, 0.3, pixelSize, paint);
        break;
      default: // 7: マフラー
        final paint = Paint()..color = const Color(0xFFFF6B6B);
        _drawPixelRect(canvas, 4, bodyY - 0.6, 4, 0.8, pixelSize, paint);
        _drawPixelRect(canvas, 6.8, bodyY + 0.1, 0.9, 1.4, pixelSize, paint);
        break;
    }
  }

  /// オーラの描画（auraIndex: 0 = なし、キャラの背面）
  void _drawAura(Canvas canvas, double pixelSize, Color elemColor) {
    final aura = character.auraIndex % 6;
    switch (aura) {
      case 0: // なし
        break;
      case 1: // 光輪（頭上のリング）
        final paint = Paint()
          ..color = const Color(0xFFF6B93B).withValues(alpha: 0.9);
        _drawPixelRect(canvas, 4.5, 0.0, 3, 0.5, pixelSize, paint);
        _drawPixelRect(canvas, 4.2, 0.15, 0.6, 0.25, pixelSize, paint);
        _drawPixelRect(canvas, 7.2, 0.15, 0.6, 0.25, pixelSize, paint);
        break;
      case 2: // 星屑（周囲に小さな星）
        final paint = Paint()
          ..color = const Color(0xFFFFE46D).withValues(alpha: 0.95);
        for (final pos in const [
          (1.2, 2.0),
          (10.2, 1.4),
          (0.8, 6.0),
          (10.6, 5.4),
          (1.8, 9.4),
          (9.8, 9.0),
        ]) {
          _drawPixelRect(canvas, pos.$1, pos.$2, 0.6, 0.6, pixelSize, paint);
        }
        break;
      case 3: // 炎（足元と両脇に揺らめき）
        final outer = Paint()
          ..color = const Color(0xFFFF6B6B).withValues(alpha: 0.55);
        final inner = Paint()
          ..color = const Color(0xFFFF9F43).withValues(alpha: 0.7);
        _drawPixelRect(canvas, 1.4, 4.2, 1, 5.2, pixelSize, outer);
        _drawPixelRect(canvas, 9.6, 4.2, 1, 5.2, pixelSize, outer);
        _drawPixelRect(canvas, 1.7, 3.2, 0.5, 1.4, pixelSize, inner);
        _drawPixelRect(canvas, 9.9, 3.2, 0.5, 1.4, pixelSize, inner);
        _drawPixelRect(canvas, 2.2, 9.6, 7.6, 0.9, pixelSize, outer);
        break;
      case 4: // 電撃（黄色のジグザグ）
        final paint = Paint()
          ..color = const Color(0xFFFFD93D).withValues(alpha: 0.9);
        _drawPixelRect(canvas, 1.4, 2.4, 0.6, 1.4, pixelSize, paint);
        _drawPixelRect(canvas, 0.9, 3.6, 0.6, 1.4, pixelSize, paint);
        _drawPixelRect(canvas, 10.0, 5.0, 0.6, 1.4, pixelSize, paint);
        _drawPixelRect(canvas, 10.5, 6.2, 0.6, 1.4, pixelSize, paint);
        _drawPixelRect(canvas, 1.6, 7.8, 0.6, 1.4, pixelSize, paint);
        break;
      default: // 5: 雪（水色の結晶）
        final paint = Paint()
          ..color = const Color(0xFF87BDFF).withValues(alpha: 0.9);
        for (final pos in const [
          (1.6, 1.8),
          (10.0, 2.6),
          (0.9, 5.2),
          (10.6, 7.0),
          (2.2, 8.8),
          (9.2, 10.0),
        ]) {
          _drawPixelRect(canvas, pos.$1, pos.$2, 0.5, 0.5, pixelSize, paint);
          _drawPixelRect(
              canvas, pos.$1 - 0.25, pos.$2 + 0.15, 1.0, 0.2, pixelSize, paint);
        }
        break;
    }
  }

  void _drawPixelRect(Canvas canvas, double x, double y, double w, double h,
      double pixelSize, Paint paint) {
    canvas.drawRect(
      Rect.fromLTWH(x * pixelSize, y * pixelSize, w * pixelSize, h * pixelSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PixelCharacterPainter oldDelegate) {
    return oldDelegate.character.name != character.name ||
        oldDelegate.character.element != character.element ||
        oldDelegate.character.colorPaletteIndex != character.colorPaletteIndex ||
        oldDelegate.character.headIndex != character.headIndex ||
        oldDelegate.character.bodyIndex != character.bodyIndex ||
        oldDelegate.character.armIndex != character.armIndex ||
        oldDelegate.character.legIndex != character.legIndex ||
        oldDelegate.character.accessoryIndex != character.accessoryIndex ||
        oldDelegate.character.auraIndex != character.auraIndex;
  }
}
