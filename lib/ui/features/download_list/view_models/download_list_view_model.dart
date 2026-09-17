import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../domain/models/download_task.dart';
import '../../../../domain/repositories/download_repository.dart';
import '../../../../domain/use_cases/pause_download_use_case.dart';
import '../../../../domain/use_cases/resume_download_use_case.dart';
import '../../../../domain/use_cases/cancel_download_use_case.dart';
import '../../../../domain/use_cases/refresh_download_url_use_case.dart';

enum StatusFilter {
  all,
  downloading,
  paused,
  completed,
}

class DownloadListViewModel extends ChangeNotifier {
  DownloadListViewModel({
    required this._downloadRepository,
    required PauseDownloadUseCase pauseDownloadUseCase,
    required ResumeDownloadUseCase resumeDownloadUseCase,
    required CancelDownloadUseCase cancelDownloadUseCase,
    required RefreshDownloadUrlUseCase refreshDownloadUrlUseCase,
  })  : _pauseUseCase = pauseDownloadUseCase,
        _resumeUseCase = resumeDownloadUseCase,
        _cancelUseCase = cancelDownloadUseCase,
        _refreshUrlUseCase = refreshDownloadUrlUseCase;

  final DownloadRepository _downloadRepository;
  final PauseDownloadUseCase _pauseUseCase;
  final ResumeDownloadUseCase _resumeUseCase;
  final CancelDownloadUseCase _cancelUseCase;
  final RefreshDownloadUrlUseCase _refreshUrlUseCase;

  StreamSubscription? _tasksSub;
  List<DownloadTask> _tasks = const [];
  String _searchQuery = '';
  TaskCategory? _selectedCategory;
  StatusFilter _selectedStatusFilter = StatusFilter.all;
  final Set<String> _selectedTaskIds = {};
  String? _selectedTaskId;

  List<DownloadTask> get tasks => _filteredTasks();
  List<DownloadTask> get allTasks => _tasks;
  String get searchQuery => _searchQuery;
  TaskCategory? get selectedCategory => _selectedCategory;
  StatusFilter get selectedStatusFilter => _selectedStatusFilter;
  Set<String> get selectedTaskIds => Set.unmodifiable(_selectedTaskIds);
  String? get selectedTaskId => _selectedTaskId;

  DownloadTask? get currentSelectedTask {
    if (_selectedTaskId == null) return null;
    return _tasks.where((t) => t.id == _selectedTaskId).firstOrNull;
  }

  void init() {
    _tasksSub?.cancel();
    _tasksSub = _downloadRepository.watchAllTasks().listen((updatedTasks) {
      _tasks = updatedTasks;
      notifyListeners();
    });
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(TaskCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setStatusFilter(StatusFilter filter) {
    _selectedStatusFilter = filter;
    notifyListeners();
  }

  void selectTask(String taskId, {bool multiSelect = false}) {
    _selectedTaskId = taskId;
    if (!multiSelect) {
      _selectedTaskIds.clear();
      _selectedTaskIds.add(taskId);
    } else {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
      } else {
        _selectedTaskIds.add(taskId);
      }
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedTaskIds.clear();
    for (final t in _filteredTasks()) {
      _selectedTaskIds.add(t.id);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedTaskIds.clear();
    _selectedTaskId = null;
    notifyListeners();
  }

  Future<void> togglePauseSelected() async {
    for (final id in _selectedTaskIds) {
      final task = _tasks.where((t) => t.id == id).firstOrNull;
      if (task == null) continue;
      if (task.status == TaskStatus.downloading) {
        await _pauseUseCase(id);
      } else if (task.status == TaskStatus.paused || task.status == TaskStatus.error) {
        await _resumeUseCase(id);
      }
    }
  }

  Future<void> pauseTask(String taskId) async {
    await _pauseUseCase(taskId);
  }

  Future<void> resumeTask(String taskId) async {
    await _resumeUseCase(taskId);
  }

  Future<void> cancelSelected({bool deleteFile = false}) async {
    for (final id in _selectedTaskIds) {
      await _cancelUseCase(id, deleteFile: deleteFile);
    }
    _selectedTaskIds.clear();
    _selectedTaskId = null;
    notifyListeners();
  }

  Future<void> refreshDownloadAddress(String taskId, String newUrl) async {
    await _refreshUrlUseCase(taskId, newUrl);
  }

  List<DownloadTask> _filteredTasks() {
    return _tasks.where((t) {
      final matchesSearch = _searchQuery.isEmpty ||
          t.filename.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.url.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == null || t.category == _selectedCategory;

      final matchesStatus = switch (_selectedStatusFilter) {
        StatusFilter.all => true,
        StatusFilter.downloading => t.status == TaskStatus.downloading,
        StatusFilter.paused => t.status == TaskStatus.paused,
        StatusFilter.completed => t.status == TaskStatus.completed,
      };

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    super.dispose();
  }
}
