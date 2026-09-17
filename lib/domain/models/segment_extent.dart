class SegmentProgress {
  const SegmentProgress({
    required this.connectionId,
    required this.startOffset,
    required this.currentOffset,
    required this.endOffset,
    required this.speedBps,
  });

  final int connectionId;
  final int startOffset;
  final int currentOffset;
  final int endOffset;
  final int speedBps;

  double get progress {
    final total = endOffset - startOffset + 1;
    if (total <= 0) return 1.0;
    final done = currentOffset - startOffset;
    return (done / total).clamp(0.0, 1.0);
  }
}
