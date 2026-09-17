import 'download_task.dart';
import 'segment_extent.dart';

abstract class TelemetryEvent {
  const TelemetryEvent();
}

class TelemetryProgressEvent extends TelemetryEvent {
  const TelemetryProgressEvent({
    required this.taskId,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.indeterminate,
    required this.speedBps,
    required this.etaSeconds,
    required this.activeConnections,
    required this.segments,
  });

  final String taskId;
  final int downloadedBytes;
  final int totalBytes;
  final bool indeterminate;
  final int speedBps;
  final int etaSeconds;
  final int activeConnections;
  final List<SegmentProgress> segments;
}

class TelemetryStatusChangedEvent extends TelemetryEvent {
  const TelemetryStatusChangedEvent({
    required this.taskId,
    required this.oldStatus,
    required this.newStatus,
    this.errorMessage,
  });

  final String taskId;
  final TaskStatus oldStatus;
  final TaskStatus newStatus;
  final String? errorMessage;
}

class TelemetryUrlExpiredEvent extends TelemetryEvent {
  const TelemetryUrlExpiredEvent({
    required this.taskId,
    required this.originalUrl,
    required this.httpStatus,
  });

  final String taskId;
  final String originalUrl;
  final int httpStatus;
}

class TelemetryTaskCompletedEvent extends TelemetryEvent {
  const TelemetryTaskCompletedEvent({
    required this.taskId,
    required this.filePath,
    required this.fileSize,
    required this.sha256Hash,
  });

  final String taskId;
  final String filePath;
  final int fileSize;
  final String sha256Hash;
}
