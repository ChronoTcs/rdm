import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../domain/models/segment_extent.dart';
import '../../../../domain/repositories/download_repository.dart';

class TaskInspectorViewModel extends ChangeNotifier {
  TaskInspectorViewModel({
    required this._taskId,
    required this._downloadRepository,
  });

  final String _taskId;
  final DownloadRepository _downloadRepository;
  StreamSubscription? _telemetrySub;

  List<SegmentProgress> _segments = const [];
  List<SegmentProgress> get segments => _segments;

  final List<double> _speedHistory = List<double>.filled(60, 0.0, growable: true);
  List<double> get speedHistory => List.unmodifiable(_speedHistory);

  double _peakSpeedBps = 0.0;
  double get peakSpeedBps => _peakSpeedBps;

  bool _isIndeterminate = false;
  bool get isIndeterminate => _isIndeterminate;

  int _downloadedBytes = 0;
  int get downloadedBytes => _downloadedBytes;

  int _totalBytes = 0;
  int get totalBytes => _totalBytes;

  int _currentSpeedBps = 0;
  int get currentSpeedBps => _currentSpeedBps;

  void attach() {
    _telemetrySub?.cancel();
    _telemetrySub = _downloadRepository.watchTaskTelemetry(_taskId).listen((telemetry) {
      _segments = telemetry.segments;
      _isIndeterminate = telemetry.indeterminate;
      _downloadedBytes = telemetry.downloadedBytes;
      _totalBytes = telemetry.totalBytes;
      _currentSpeedBps = telemetry.speedBps;

      final currentSpeed = telemetry.speedBps.toDouble();
      if (currentSpeed > _peakSpeedBps) {
        _peakSpeedBps = currentSpeed;
      }

      _speedHistory.removeAt(0);
      _speedHistory.add(currentSpeed);

      notifyListeners();
    });
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    super.dispose();
  }
}
