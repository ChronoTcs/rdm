import 'package:flutter/foundation.dart';
import '../../../../domain/models/download_task.dart';
import '../../../../domain/use_cases/start_download_use_case.dart';

class AddDownloadViewModel extends ChangeNotifier {
  AddDownloadViewModel({required this._startDownloadUseCase});

  final StartDownloadUseCase _startDownloadUseCase;

  String _url = '';
  String _filename = '';
  String _destinationPath = 'C:/Downloads';
  int _concurrency = 16;
  int? _limitBps;
  TaskCategory _category = TaskCategory.general;
  bool _isSubmitting = false;
  String? _errorMessage;

  String get url => _url;
  String get filename => _filename;
  String get destinationPath => _destinationPath;
  int get concurrency => _concurrency;
  int? get limitBps => _limitBps;
  TaskCategory get category => _category;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  String get detectedProtocol {
    if (_url.isEmpty) return 'UNKNOWN';
    final lower = _url.toLowerCase();
    if (lower.startsWith('magnet:')) return 'MAGNET';
    if (lower.startsWith('https://')) return 'HTTPS';
    if (lower.startsWith('http://')) return 'HTTP';
    if (lower.startsWith('ftp://')) return 'FTP';
    return 'URL';
  }

  bool get isValidUrl {
    if (_url.isEmpty) return false;
    final lower = _url.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('ftp://') ||
        lower.startsWith('magnet:');
  }

  void setUrl(String newUrl) {
    _url = newUrl.trim();
    _errorMessage = null;

    if (_url.isNotEmpty) {
      try {
        final uri = Uri.parse(_url);
        final last = uri.pathSegments.lastOrNull;
        if (last != null && last.contains('.')) {
          _filename = last;
          _category = TaskCategory.fromExtension(last);
        }
      } catch (_) {}
    }

    notifyListeners();
  }

  void setFilename(String newFilename) {
    _filename = newFilename.trim();
    if (_filename.contains('.')) {
      _category = TaskCategory.fromExtension(_filename);
    }
    notifyListeners();
  }

  void setDestinationPath(String path) {
    _destinationPath = path.trim();
    notifyListeners();
  }

  void setConcurrency(int val) {
    _concurrency = val.clamp(1, 32);
    notifyListeners();
  }

  void setLimitBps(int? val) {
    _limitBps = val;
    notifyListeners();
  }

  void setCategory(TaskCategory cat) {
    _category = cat;
    notifyListeners();
  }

  Future<String?> submit() async {
    if (!isValidUrl) {
      _errorMessage = 'Invalid download URL. Protocol must be HTTP, HTTPS, FTP, or MAGNET.';
      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final taskId = await _startDownloadUseCase(
        url: _url,
        destinationPath: _destinationPath,
        filename: _filename.isNotEmpty ? _filename : null,
        concurrency: _concurrency,
        limitBps: _limitBps,
        category: _category,
      );
      _isSubmitting = false;
      notifyListeners();
      return taskId;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }
}
