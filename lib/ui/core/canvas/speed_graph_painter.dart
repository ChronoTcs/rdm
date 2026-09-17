import 'package:flutter/material.dart';
import '../theme/color_tokens.dart';

class SpeedGraphPainter extends CustomPainter {
  const SpeedGraphPainter({
    required this.speedHistory,
    required this.peakSpeed,
  });

  final List<double> speedHistory;
  final double peakSpeed;

  @override
  void paint(Canvas canvas, Size size) {
    if (speedHistory.isEmpty) return;

    final width = size.width;
    final height = size.height;
    final maxSpeed = (peakSpeed > 0 ? peakSpeed : 1.0) * 1.1; // 10% headroom

    final points = <Offset>[];
    final stepX = width / (speedHistory.length - 1).clamp(1, double.infinity);

    for (var i = 0; i < speedHistory.length; i++) {
      final x = i * stepX;
      final speedRatio = (speedHistory[i] / maxSpeed).clamp(0.0, 1.0);
      final y = height - (speedRatio * height);
      points.add(Offset(x, y));
    }

    // Build smoothed path
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPointX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlPointX, p0.dy, controlPointX, p1.dy, p1.dx, p1.dy);
    }

    // Draw area fill under curve
    final fillPath = Path.from(path)
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        ColorTokens.accentPrimary.withValues(alpha: 0.4),
        ColorTokens.accentPrimary.withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw curve line
    final linePaint = Paint()
      ..color = ColorTokens.accentPrimary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // Draw horizontal dotted peak line if peak > 0
    if (peakSpeed > 0) {
      final peakY = height - ((peakSpeed / maxSpeed).clamp(0.0, 1.0) * height);
      final peakPaint = Paint()
        ..color = ColorTokens.darkTextSecondary.withValues(alpha: 0.5)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      const dashWidth = 4.0;
      const dashSpace = 4.0;
      var startX = 0.0;
      while (startX < width) {
        canvas.drawLine(
          Offset(startX, peakY),
          Offset(startX + dashWidth, peakY),
          peakPaint,
        );
        startX += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant SpeedGraphPainter oldDelegate) {
    return oldDelegate.speedHistory != speedHistory ||
        oldDelegate.peakSpeed != peakSpeed;
  }
}
