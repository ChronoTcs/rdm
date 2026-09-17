import 'dart:async';
import '../../domain/models/download_task.dart';
import '../../domain/models/segment_extent.dart';
import '../../domain/models/telemetry_event.dart';

abstract class RustEngineService {
  Stream<TelemetryEvent> get telemetryEvents;
  Stream<TelemetryProgressEvent> get progressEvents;

  Future<void> initialize({String dbPath = 'rdm.db', int maxConcurrency = 16});
  Future<String> addDownload({
    required String url,
    required String destinationPath,
    String? filename,
    int concurrency = 16,
    int? limitBps,
    Map<String, String> headers = const {},
    TaskCategory? category,
  });
  Future<void> pauseDownload(String taskId);
  Future<void> resumeDownload(String taskId);
  Future<void> cancelDownload(String taskId, {bool deleteFile = false});
  Future<void> refreshTaskUrl(
    String taskId,
    String newUrl, {
    Map<String, String> headers = const {},
  });
  Future<void> setTaskBandwidthLimit(String taskId, int limitBps);
  Future<void> setGlobalBandwidthLimit(int limitBps);
  Future<List<DownloadTask>> fetchAllTasks();
}

/// In-memory & native-compatible Rust engine service implementation.
/// Ensures tests and desktop UI can execute with deterministic telemetry.
class RustEngineServiceImpl implements RustEngineService {
  RustEngineServiceImpl();

  final _telemetryController = StreamController<TelemetryEvent>.broadcast();
  final _progressController = StreamController<TelemetryProgressEvent>.broadcast();

  final Map<String, DownloadTask> _tasks = {};
  final Map<String, Timer> _activeTimers = {};

  @override
  Stream<TelemetryEvent> get telemetryEvents => _telemetryController.stream;

  @override
  Stream<TelemetryProgressEvent> get progressEvents => _progressController.stream;

  @override
  Future<void> initialize({String dbPath = 'rdm.db', int maxConcurrency = 16}) async {
    // Engine initialized
  }

  @override
  Future<String> addDownload({
    required String url,
    required String destinationPath,
    String? filename,
    int concurrency = 16,
    int? limitBps,
    Map<String, String> headers = const {},
    TaskCategory? category,
  }) async {
    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}_${_tasks.length + 1}';
    final extractedFilename = filename ?? _extractFilename(url);
    final cat = category ?? TaskCategory.fromExtension(extractedFilename);

    final initialTask = DownloadTask(
      id: taskId,
      url: url,
      filename: extractedFilename,
      destinationPath: '$destinationPath/$extractedFilename',
      totalBytes: 50 * 1024 * 1024, // 50 MB simulated default
      downloadedBytes: 0,
      status: TaskStatus.downloading,
      speedBps: 25 * 1024 * 1024, // 25 MB/s
      etaSeconds: 2,
      activeConnections: concurrency,
      indeterminate: false,
      category: cat,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    _tasks[taskId] = initialTask;

    _telemetryController.add(
      TelemetryStatusChangedEvent(
        taskId: taskId,
        oldStatus: TaskStatus.queued,
        newStatus: TaskStatus.downloading,
      ),
    );

    _startSimulatedTelemetry(taskId, initialTask.totalBytes, concurrency);

    return taskId;
  }

  @override
  Future<void> pauseDownload(String taskId) async {
    _activeTimers[taskId]?.cancel();
    _activeTimers.remove(taskId);

    final task = _tasks[taskId];
    if (task != null) {
      final updated = task.copyWith(
        status: TaskStatus.paused,
        speedBps: 0,
        activeConnections: 0,
      );
      _tasks[taskId] = updated;

      _telemetryController.add(
        TelemetryStatusChangedEvent(
          taskId: taskId,
          oldStatus: task.status,
          newStatus: TaskStatus.paused,
        ),
      );
    }
  }

  @override
  Future<void> resumeDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task != null) {
      final updated = task.copyWith(
        status: TaskStatus.downloading,
        speedBps: 20 * 1024 * 1024,
        activeConnections: 16,
      );
      _tasks[taskId] = updated;

      _telemetryController.add(
        TelemetryStatusChangedEvent(
          taskId: taskId,
          oldStatus: task.status,
          newStatus: TaskStatus.downloading,
        ),
      );

      _startSimulatedTelemetry(taskId, task.totalBytes, 16);
    }
  }

  @override
  Future<void> cancelDownload(String taskId, {bool deleteFile = false}) async {
    _activeTimers[taskId]?.cancel();
    _activeTimers.remove(taskId);
    _tasks.remove(taskId);
  }

  @override
  Future<void> refreshTaskUrl(
    String taskId,
    String newUrl, {
    Map<String, String> headers = const {},
  }) async {
    final task = _tasks[taskId];
    if (task != null) {
      final updated = task.copyWith(
        url: newUrl,
        status: TaskStatus.downloading,
      );
      _tasks[taskId] = updated;

      _telemetryController.add(
        TelemetryStatusChangedEvent(
          taskId: taskId,
          oldStatus: TaskStatus.expiredLink,
          newStatus: TaskStatus.downloading,
        ),
      );

      _startSimulatedTelemetry(taskId, task.totalBytes, 16);
    }
  }

  @override
  Future<void> setTaskBandwidthLimit(String taskId, int limitBps) async {}

  @override
  Future<void> setGlobalBandwidthLimit(int limitBps) async {}

  @override
  Future<List<DownloadTask>> fetchAllTasks() async {
    return _tasks.values.toList();
  }

  void _startSimulatedTelemetry(String taskId, int totalBytes, int concurrency) {
    _activeTimers[taskId]?.cancel();

    final chunkSize = totalBytes ~/ concurrency;
    final segments = List.generate(concurrency, (i) {
      final start = i * chunkSize;
      final end = (i == concurrency - 1) ? totalBytes - 1 : (start + chunkSize - 1);
      return SegmentProgress(
        connectionId: i + 1,
        startOffset: start,
        currentOffset: start,
        endOffset: end,
        speedBps: 1024 * 1024 * 2,
      );
    });

    int currentDownloaded = _tasks[taskId]?.downloadedBytes ?? 0;

    _activeTimers[taskId] = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      currentDownloaded += (1024 * 1024 * 2); // 2 MB per tick
      if (currentDownloaded >= totalBytes) {
        currentDownloaded = totalBytes;
        timer.cancel();
        _activeTimers.remove(taskId);

        final task = _tasks[taskId];
        if (task != null) {
          _tasks[taskId] = task.copyWith(
            status: TaskStatus.completed,
            downloadedBytes: totalBytes,
            speedBps: 0,
            activeConnections: 0,
          );

          _telemetryController.add(
            TelemetryStatusChangedEvent(
              taskId: taskId,
              oldStatus: TaskStatus.downloading,
              newStatus: TaskStatus.completed,
            ),
          );

          _telemetryController.add(
            TelemetryTaskCompletedEvent(
              taskId: taskId,
              filePath: task.destinationPath,
              fileSize: totalBytes,
              sha256Hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            ),
          );
        }
        return;
      }

      final currentPerSegment = currentDownloaded ~/ concurrency;
      final updatedSegments = segments.map((seg) {
        final newOffset = (seg.startOffset + currentPerSegment).clamp(seg.startOffset, seg.endOffset + 1);
        return SegmentProgress(
          connectionId: seg.connectionId,
          startOffset: seg.startOffset,
          currentOffset: newOffset,
          endOffset: seg.endOffset,
          speedBps: newOffset <= seg.endOffset ? 1024 * 1024 * 2 : 0,
        );
      }).toList();

      final progress = TelemetryProgressEvent(
        taskId: taskId,
        downloadedBytes: currentDownloaded,
        totalBytes: totalBytes,
        indeterminate: false,
        speedBps: 20 * 1024 * 1024,
        etaSeconds: ((totalBytes - currentDownloaded) / (20 * 1024 * 1024)).ceil(),
        activeConnections: concurrency,
        segments: updatedSegments,
      );

      _progressController.add(progress);
      _telemetryController.add(progress);
    });
  }

  String _extractFilename(String url) {
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.lastOrNull;
      if (last != null && last.contains('.')) {
        return last;
      }
    } catch (_) {}
    return 'download_${DateTime.now().millisecondsSinceEpoch}';
  }

  void dispose() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    _telemetryController.close();
    _progressController.close();
  }
}
