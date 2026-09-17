import 'package:flutter_test/flutter_test.dart';
import 'package:rdm/data/repositories/download_repository_impl.dart';
import 'package:rdm/data/services/rust_engine_service.dart';
import 'package:rdm/ui/features/task_inspector/view_models/task_inspector_view_model.dart';

void main() {
  late RustEngineServiceImpl engineService;
  late DownloadRepositoryImpl repository;

  setUp(() {
    engineService = RustEngineServiceImpl();
    repository = DownloadRepositoryImpl(engineService: engineService);
  });

  tearDown(() {
    engineService.dispose();
  });

  test('TaskInspectorViewModel attaches to telemetry stream and tracks metrics', () async {
    final taskId = await repository.startDownload(
      url: 'https://example.com/test_payload.bin',
      destinationPath: 'C:/Downloads',
      filename: 'test_payload.bin',
      concurrency: 4,
    );

    final inspectorVm = TaskInspectorViewModel(
      taskId: taskId,
      downloadRepository: repository,
    );
    inspectorVm.attach();

    expect(inspectorVm.speedHistory.length, 60);

    // Wait for at least 2 telemetry ticks (200ms)
    await Future.delayed(const Duration(milliseconds: 250));

    expect(inspectorVm.downloadedBytes, greaterThan(0));
    expect(inspectorVm.currentSpeedBps, greaterThan(0));
    expect(inspectorVm.peakSpeedBps, greaterThan(0));
    expect(inspectorVm.segments.length, 4);

    inspectorVm.dispose();
  });
}
