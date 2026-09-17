import 'package:flutter_test/flutter_test.dart';
import 'package:rdm/data/repositories/download_repository_impl.dart';
import 'package:rdm/data/services/rust_engine_service.dart';
import 'package:rdm/domain/models/download_task.dart';
import 'package:rdm/domain/use_cases/start_download_use_case.dart';
import 'package:rdm/ui/features/add_download/view_models/add_download_view_model.dart';

void main() {
  late RustEngineServiceImpl engineService;
  late DownloadRepositoryImpl repository;
  late AddDownloadViewModel viewModel;

  setUp(() {
    engineService = RustEngineServiceImpl();
    repository = DownloadRepositoryImpl(engineService: engineService);
    viewModel = AddDownloadViewModel(
      startDownloadUseCase: StartDownloadUseCase(repository),
    );
  });

  tearDown(() {
    viewModel.dispose();
    engineService.dispose();
  });

  test('URL validation and protocol detection', () {
    expect(viewModel.isValidUrl, isFalse);
    expect(viewModel.detectedProtocol, 'UNKNOWN');

    viewModel.setUrl('https://example.com/movie.mp4');
    expect(viewModel.isValidUrl, isTrue);
    expect(viewModel.detectedProtocol, 'HTTPS');
    expect(viewModel.filename, 'movie.mp4');
    expect(viewModel.category, TaskCategory.video);

    viewModel.setUrl('magnet:?xt=urn:btih:12345');
    expect(viewModel.isValidUrl, isTrue);
    expect(viewModel.detectedProtocol, 'MAGNET');

    viewModel.setUrl('ftp://speedtest.tele2.net/100MB.zip');
    expect(viewModel.isValidUrl, isTrue);
    expect(viewModel.detectedProtocol, 'FTP');
    expect(viewModel.filename, '100MB.zip');
    expect(viewModel.category, TaskCategory.compressed);
  });

  test('Successful task submission', () async {
    viewModel.setUrl('https://download.document.pdf');
    final taskId = await viewModel.submit();

    expect(taskId, isNotNull);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isSubmitting, isFalse);

    final allTasks = await repository.getAllTasks();
    expect(allTasks.any((t) => t.id == taskId), isTrue);
  });

  test('Invalid URL submission fails with error message', () async {
    viewModel.setUrl('invalid-uri-scheme');
    final taskId = await viewModel.submit();

    expect(taskId, isNull);
    expect(viewModel.errorMessage, isNotNull);
  });
}
