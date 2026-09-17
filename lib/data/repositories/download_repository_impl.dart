import 'dart:async';
import '../../domain/models/download_task.dart';
import '../../domain/models/telemetry_event.dart';
import '../../domain/repositories/download_repository.dart';
import '../services/rust_engine_service.dart';

class DownloadRepositoryImpl implements DownloadRepository {
  DownloadRepositoryImpl({required this._engineService}) {
    _initListener();
  }

  final RustEngineService _engineService;
  final _tasksController = StreamController<List<DownloadTask>>.broadcast();
  final Map<String, DownloadTask> _cachedTasks = {};

  void _initListener() {
    _engineService.telemetryEvents.listen((event) {
      if (event is TelemetryProgressEvent) {
        final existing = _cachedTasks[event.taskId];
        if (existing != null) {
          _cachedTasks[event.taskId] = existing.copyWith(
            downloadedBytes: event.downloadedBytes,
            totalBytes: event.totalBytes,
            speedBps: event.speedBps,
            etaSeconds: event.etaSeconds,
            activeConnections: event.activeConnections,
            indeterminate: event.indeterminate,
          );
          _tasksController.add(_cachedTasks.values.toList());
        }
      } else if (event is TelemetryStatusChangedEvent) {
        final existing = _cachedTasks[event.taskId];
        if (existing != null) {
          _cachedTasks[event.taskId] = existing.copyWith(
            status: event.newStatus,
            errorMessage: event.errorMessage,
          );
          _tasksController.add(_cachedTasks.values.toList());
        }
      } else if (event is TelemetryUrlExpiredEvent) {
        final existing = _cachedTasks[event.taskId];
        if (existing != null) {
          _cachedTasks[event.taskId] = existing.copyWith(
            status: TaskStatus.expiredLink,
            speedBps: 0,
            activeConnections: 0,
            errorMessage: 'HTTP ${event.httpStatus} Link Expired',
          );
          _tasksController.add(_cachedTasks.values.toList());
        }
      } else if (event is TelemetryTaskCompletedEvent) {
        final existing = _cachedTasks[event.taskId];
        if (existing != null) {
          _cachedTasks[event.taskId] = existing.copyWith(
            status: TaskStatus.completed,
            downloadedBytes: event.fileSize,
            speedBps: 0,
            activeConnections: 0,
            sha256Hash: event.sha256Hash.isNotEmpty ? event.sha256Hash : existing.sha256Hash,
          );
          _tasksController.add(_cachedTasks.values.toList());
        }
      }
    });
  }

  @override
  Stream<List<DownloadTask>> watchAllTasks() {
    // Immediately emit current state
    Future.microtask(() async {
      final tasks = await _engineService.fetchAllTasks();
      for (final t in tasks) {
        _cachedTasks[t.id] = t;
      }
      _tasksController.add(_cachedTasks.values.toList());
    });
    return _tasksController.stream;
  }

  @override
  Stream<TelemetryProgressEvent> watchTaskTelemetry(String taskId) {
    return _engineService.progressEvents.where((e) => e.taskId == taskId);
  }

  @override
  Stream<TelemetryEvent> watchAllEvents() {
    return _engineService.telemetryEvents;
  }

  @override
  Future<List<DownloadTask>> getAllTasks() async {
    final tasks = await _engineService.fetchAllTasks();
    for (final t in tasks) {
      _cachedTasks[t.id] = t;
    }
    return tasks;
  }

  @override
  Future<String> startDownload({
    required String url,
    required String destinationPath,
    String? filename,
    int concurrency = 16,
    int? limitBps,
    Map<String, String> headers = const {},
    TaskCategory? category,
  }) async {
    final id = await _engineService.addDownload(
      url: url,
      destinationPath: destinationPath,
      filename: filename,
      concurrency: concurrency,
      limitBps: limitBps,
      headers: headers,
      category: category,
    );
    final tasks = await _engineService.fetchAllTasks();
    for (final t in tasks) {
      _cachedTasks[t.id] = t;
    }
    _tasksController.add(_cachedTasks.values.toList());
    return id;
  }

  @override
  Future<void> pauseDownload(String taskId) async {
    await _engineService.pauseDownload(taskId);
    final existing = _cachedTasks[taskId];
    if (existing != null) {
      _cachedTasks[taskId] = existing.copyWith(
        status: TaskStatus.paused,
        speedBps: 0,
        activeConnections: 0,
      );
      _tasksController.add(_cachedTasks.values.toList());
    }
  }

  @override
  Future<void> resumeDownload(String taskId) async {
    await _engineService.resumeDownload(taskId);
    final existing = _cachedTasks[taskId];
    if (existing != null) {
      _cachedTasks[taskId] = existing.copyWith(
        status: TaskStatus.downloading,
      );
      _tasksController.add(_cachedTasks.values.toList());
    }
  }

  @override
  Future<void> cancelDownload(String taskId, {bool deleteFile = false}) async {
    await _engineService.cancelDownload(taskId, deleteFile: deleteFile);
    _cachedTasks.remove(taskId);
    _tasksController.add(_cachedTasks.values.toList());
  }

  @override
  Future<void> refreshDownloadUrl(
    String taskId,
    String newUrl, {
    Map<String, String> headers = const {},
  }) async {
    final existing = _cachedTasks[taskId];
    if (existing != null) {
      _cachedTasks[taskId] = existing.copyWith(
        url: newUrl,
        status: TaskStatus.downloading,
        errorMessage: null,
      );
      _tasksController.add(_cachedTasks.values.toList());
    }
    await _engineService.refreshTaskUrl(taskId, newUrl, headers: headers);
  }

  @override
  Future<void> setTaskBandwidthLimit(String taskId, int limitBps) async {
    await _engineService.setTaskBandwidthLimit(taskId, limitBps);
  }

  @override
  Future<void> setGlobalBandwidthLimit(int limitBps) async {
    await _engineService.setGlobalBandwidthLimit(limitBps);
  }

  void dispose() {
    _tasksController.close();
  }
}
