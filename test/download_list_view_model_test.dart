import 'package:flutter_test/flutter_test.dart';
import 'package:rdm/domain/models/download_task.dart';
import 'package:rdm/domain/repositories/download_repository.dart';
import 'package:rdm/domain/use_cases/pause_download_use_case.dart';
import 'package:rdm/domain/use_cases/resume_download_use_case.dart';
import 'package:rdm/domain/use_cases/cancel_download_use_case.dart';
import 'package:rdm/domain/use_cases/refresh_download_url_use_case.dart';
import 'package:rdm/data/repositories/download_repository_impl.dart';
import 'package:rdm/data/services/rust_engine_service.dart';
import 'package:rdm/ui/features/download_list/view_models/download_list_view_model.dart';

void main() {
  late RustEngineServiceImpl engineService;
  late DownloadRepository repository;
  late DownloadListViewModel viewModel;

  setUp(() {
    engineService = RustEngineServiceImpl();
    repository = DownloadRepositoryImpl(engineService: engineService);
    viewModel = DownloadListViewModel(
      downloadRepository: repository,
      pauseDownloadUseCase: PauseDownloadUseCase(repository),
      resumeDownloadUseCase: ResumeDownloadUseCase(repository),
      cancelDownloadUseCase: CancelDownloadUseCase(repository),
      refreshDownloadUrlUseCase: RefreshDownloadUrlUseCase(repository),
    );
    viewModel.init();
  });

  tearDown(() {
    viewModel.dispose();
    engineService.dispose();
  });

  test('Initial tasks list is empty', () {
    expect(viewModel.tasks, isEmpty);
    expect(viewModel.selectedTaskIds, isEmpty);
  });

  test('Adding downloads and filtering by status and query', () async {
    final task1Id = await repository.startDownload(
      url: 'https://example.com/archive.zip',
      destinationPath: 'C:/Downloads',
      filename: 'archive.zip',
    );
    final task2Id = await repository.startDownload(
      url: 'https://example.com/video.mp4',
      destinationPath: 'C:/Downloads',
      filename: 'video.mp4',
    );

    // Wait a brief tick for stream update
    await Future.delayed(const Duration(milliseconds: 50));

    expect(viewModel.allTasks.length, 2);

    // Search query filter
    viewModel.setSearchQuery('archive');
    expect(viewModel.tasks.length, 1);
    expect(viewModel.tasks.first.id, task1Id);

    // Clear search query
    viewModel.setSearchQuery('');
    expect(viewModel.tasks.length, 2);

    // Category filter
    viewModel.setSelectedCategory(TaskCategory.video);
    expect(viewModel.tasks.length, 1);
    expect(viewModel.tasks.first.id, task2Id);

    viewModel.setSelectedCategory(null);
    expect(viewModel.tasks.length, 2);
  });

  test('Selection and pause/resume commands', () async {
    final taskId = await repository.startDownload(
      url: 'https://example.com/file.iso',
      destinationPath: 'C:/Downloads',
      filename: 'file.iso',
    );
    await Future.delayed(const Duration(milliseconds: 50));

    viewModel.selectTask(taskId);
    expect(viewModel.selectedTaskIds.contains(taskId), isTrue);
    expect(viewModel.selectedTaskId, taskId);

    await viewModel.togglePauseSelected();
    await Future.delayed(const Duration(milliseconds: 50));

    final pausedTask = viewModel.allTasks.firstWhere((t) => t.id == taskId);
    expect(pausedTask.status, TaskStatus.paused);

    await viewModel.togglePauseSelected();
    await Future.delayed(const Duration(milliseconds: 50));

    final resumedTask = viewModel.allTasks.firstWhere((t) => t.id == taskId);
    expect(resumedTask.status, TaskStatus.downloading);
  });

  test('DownloadListViewModel counts and aggregate speed calculations', () async {
    expect(viewModel.countAll, 0);
    expect(viewModel.countDownloading, 0);
    expect(viewModel.countPaused, 0);
    expect(viewModel.countCompleted, 0);
    expect(viewModel.totalSpeedBps, 0);

    await repository.startDownload(
      url: 'https://example.com/archive.zip',
      destinationPath: 'C:/Downloads',
      filename: 'archive.zip',
    );
    await repository.startDownload(
      url: 'https://example.com/song.mp3',
      destinationPath: 'C:/Downloads',
      filename: 'song.mp3',
    );
    await Future.delayed(const Duration(milliseconds: 50));

    expect(viewModel.countAll, 2);
    expect(viewModel.countDownloading, 2);
    expect(viewModel.countForCategory(TaskCategory.compressed), 1);
    expect(viewModel.countForCategory(TaskCategory.audio), 1);
    expect(viewModel.countForCategory(TaskCategory.video), 0);
  });
}
