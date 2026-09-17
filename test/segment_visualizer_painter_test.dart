import 'package:flutter_test/flutter_test.dart';
import 'package:rdm/domain/models/segment_extent.dart';
import 'package:rdm/ui/core/canvas/segment_visualizer_painter.dart';
import 'package:rdm/ui/core/canvas/speed_graph_painter.dart';

void main() {
  test('SegmentVisualizerPainter repainting logic', () {
    const seg1 = SegmentProgress(
      connectionId: 1,
      startOffset: 0,
      currentOffset: 50,
      endOffset: 100,
      speedBps: 1000,
    );

    const painter1 = SegmentVisualizerPainter(
      segments: [seg1],
      totalBytes: 100,
      isIndeterminate: false,
    );

    const painter2 = SegmentVisualizerPainter(
      segments: [seg1],
      totalBytes: 100,
      isIndeterminate: false,
    );

    expect(painter1.shouldRepaint(painter2), isFalse);

    const painter3 = SegmentVisualizerPainter(
      segments: [seg1],
      totalBytes: 200,
      isIndeterminate: false,
    );
    expect(painter1.shouldRepaint(painter3), isTrue);
  });

  test('SpeedGraphPainter repainting logic', () {
    const painter1 = SpeedGraphPainter(
      speedHistory: [10.0, 20.0, 30.0],
      peakSpeed: 30.0,
    );

    const painter2 = SpeedGraphPainter(
      speedHistory: [10.0, 20.0, 30.0],
      peakSpeed: 30.0,
    );

    expect(painter1.shouldRepaint(painter2), isFalse);

    const painter3 = SpeedGraphPainter(
      speedHistory: [10.0, 20.0, 30.0],
      peakSpeed: 50.0,
    );

    expect(painter1.shouldRepaint(painter3), isTrue);
  });
}
