import 'package:flutter/material.dart';
import '../../../domain/models/segment_extent.dart';
import '../theme/color_tokens.dart';

class SegmentVisualizerPainter extends CustomPainter {
  const SegmentVisualizerPainter({
    required this.segments,
    required this.totalBytes,
    this.isIndeterminate = false,
    this.pulseOpacity = 1.0,
  });

  final List<SegmentProgress> segments;
  final int totalBytes;
  final bool isIndeterminate;
  final double pulseOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw track background
    final bgPaint = Paint()
      ..color = ColorTokens.darkBgElevated
      ..style = PaintingStyle.fill;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.drawRRect(rrect, bgPaint);

    if (isIndeterminate) {
      // Draw indeterminate animated wave
      final indeterminatePaint = Paint()
        ..color = ColorTokens.statusActive.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, indeterminatePaint);
      return;
    }

    if (totalBytes <= 0 || segments.isEmpty) {
      return;
    }

    canvas.save();
    canvas.clipRRect(rrect);

    // 2. Paint segments
    final donePaint = Paint()
      ..color = ColorTokens.statusDone
      ..style = PaintingStyle.fill;

    final activeHeadPaint = Paint()
      ..color = ColorTokens.statusActive.withValues(alpha: pulseOpacity.clamp(0.4, 1.0))
      ..style = PaintingStyle.fill;

    final laneHeight = size.height;

    for (final seg in segments) {
      final segStartRatio = seg.startOffset / totalBytes;
      final segEndRatio = (seg.endOffset + 1) / totalBytes;
      final segCurrentRatio = seg.currentOffset / totalBytes;

      final startX = segStartRatio * size.width;
      final endX = segEndRatio * size.width;
      final currentX = segCurrentRatio * size.width;

      // Draw completed portion [start, current]
      if (currentX > startX) {
        final completedRect = Rect.fromLTRB(startX, 0, currentX, laneHeight);
        canvas.drawRect(completedRect, donePaint);
      }

      // Draw active in-flight head (small cyan marker if currently streaming)
      if (currentX < endX && seg.speedBps > 0) {
        final headWidth = 3.0.clamp(1.0, endX - currentX);
        final headRect = Rect.fromLTRB(currentX, 0, currentX + headWidth, laneHeight);
        canvas.drawRect(headRect, activeHeadPaint);
      }

      // Draw subtle segment boundary divider
      final dividerPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(startX, 0), Offset(startX, laneHeight), dividerPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SegmentVisualizerPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.totalBytes != totalBytes ||
        oldDelegate.isIndeterminate != isIndeterminate ||
        oldDelegate.pulseOpacity != pulseOpacity;
  }
}
