import '../models/download_task.dart';
import '../models/telemetry_event.dart';

abstract class DownloadRepository {
  Stream<List<DownloadTask>> watchAllTasks();
  Stream<TelemetryProgressEvent> watchTaskTelemetry(String taskId);
  Stream<TelemetryEvent> watchAllEvents();

  Future<List<DownloadTask>> getAllTasks();
  Future<String> startDownload({
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
  Future<void> refreshDownloadUrl(
    String taskId,
    String newUrl, {
    Map<String, String> headers = const {},
  });
  Future<void> setTaskBandwidthLimit(String taskId, int limitBps);
  Future<void> setGlobalBandwidthLimit(int limitBps);
}
