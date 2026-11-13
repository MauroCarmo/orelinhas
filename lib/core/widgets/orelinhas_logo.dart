import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Marca do Orelinhas: patinha com um coração na almofada.
class OrelinhasLogoMark extends StatelessWidget {
  final double size;
  final Color color;
  final Color heartColor;

  const OrelinhasLogoMark({
    super.key,
    this.size = 40,
    this.color = AppColors.primary,
    this.heartColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _PawHeartPainter(color, heartColor)),
    );
  }
}

/// Logo completo: marca + nome "Orelinhas".
class OrelinhasLogo extends StatelessWidget {
  final double markSize;
  final Color color;
  final Color heartColor;
  final double fontSize;

  const OrelinhasLogo({
    super.key,
    this.markSize = 30,
    this.fontSize = 24,
    this.color = AppColors.primary,
    this.heartColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OrelinhasLogoMark(size: markSize, color: color, heartColor: heartColor),
        SizedBox(width: markSize * 0.25),
        Text(
          'Orelinhas',
          style: AppTextStyles.display(
            color: color,
          ).copyWith(fontSize: fontSize),
        ),
      ],
    );
  }
}

class _PawHeartPainter extends CustomPainter {
  final Color color;
  final Color heartColor;

  _PawHeartPainter(this.color, this.heartColor);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    void toe(double cx, double cy, double w, double h, double angle) {
      canvas.save();
      canvas.translate(cx * s, cy * s);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * s, height: h * s),
        paint,
      );
      canvas.restore();
    }

    // Dedinhos
    toe(17, 42, 19, 25, -0.45);
    toe(36, 20, 20, 27, -0.15);
    toe(64, 20, 20, 27, 0.15);
    toe(83, 42, 19, 25, 0.45);

    // Almofada principal (formato de gota arredondada)
    final pad = Path()
      ..moveTo(50 * s, 42 * s)
      ..cubicTo(68 * s, 42 * s, 86 * s, 62 * s, 84 * s, 78 * s)
      ..cubicTo(82 * s, 92 * s, 66 * s, 96 * s, 50 * s, 90 * s)
      ..cubicTo(34 * s, 96 * s, 18 * s, 92 * s, 16 * s, 78 * s)
      ..cubicTo(14 * s, 62 * s, 32 * s, 42 * s, 50 * s, 42 * s)
      ..close();
    canvas.drawPath(pad, paint);

    // Coração recortado
    const cx = 50.0, cy = 70.0, h = 30.0;
    final heart = Path()
      ..moveTo(cx * s, (cy + h * 0.38) * s)
      ..cubicTo(
        (cx - h * 0.62) * s,
        (cy - h * 0.02) * s,
        (cx - h * 0.38) * s,
        (cy - h * 0.58) * s,
        cx * s,
        (cy - h * 0.22) * s,
      )
      ..cubicTo(
        (cx + h * 0.38) * s,
        (cy - h * 0.58) * s,
        (cx + h * 0.62) * s,
        (cy - h * 0.02) * s,
        cx * s,
        (cy + h * 0.38) * s,
      )
      ..close();
    canvas.drawPath(heart, Paint()..color = heartColor);
  }

  @override
  bool shouldRepaint(covariant _PawHeartPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.heartColor != heartColor;
}
