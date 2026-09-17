import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rdm/data/repositories/download_repository_impl.dart';
import 'package:rdm/data/services/rust_engine_service.dart';
import 'package:rdm/domain/models/download_task.dart';
import 'package:rdm/domain/use_cases/start_download_use_case.dart';
import 'package:rdm/domain/use_cases/pause_download_use_case.dart';
import 'package:rdm/domain/use_cases/resume_download_use_case.dart';
import 'package:rdm/domain/use_cases/cancel_download_use_case.dart';
import 'package:rdm/domain/use_cases/refresh_download_url_use_case.dart';
import 'package:rdm/domain/use_cases/verify_file_checksum_use_case.dart';

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

  test('Domain use cases full lifecycle test', () async {
    final startUseCase = StartDownloadUseCase(repository);
    final pauseUseCase = PauseDownloadUseCase(repository);
    final resumeUseCase = ResumeDownloadUseCase(repository);
    final cancelUseCase = CancelDownloadUseCase(repository);
    final refreshUseCase = RefreshDownloadUrlUseCase(repository);
    const checksumUseCase = VerifyFileChecksumUseCase();

    // 1. Start download
    final taskId = await startUseCase(
      url: 'https://example.com/test_image.iso',
      destinationPath: 'C:/Downloads',
      filename: 'test_image.iso',
    );
    expect(taskId, isNotEmpty);

    // 2. Pause download
    await pauseUseCase(taskId);
    var tasks = await repository.getAllTasks();
    expect(tasks.firstWhere((t) => t.id == taskId).status, TaskStatus.paused);

    // 3. Resume download
    await resumeUseCase(taskId);
    tasks = await repository.getAllTasks();
    expect(tasks.firstWhere((t) => t.id == taskId).status, TaskStatus.downloading);

    // 4. Refresh URL
    await refreshUseCase(taskId, 'https://example.com/test_image_renewed.iso');
    tasks = await repository.getAllTasks();
    expect(
      tasks.firstWhere((t) => t.id == taskId).url,
      'https://example.com/test_image_renewed.iso',
    );

    // 5. Checksum verification for non-existent file returns false safely
    final valid = await checksumUseCase('non_existent_file.iso', 'dummy_hash');
    expect(valid, isFalse);

    // 6. Cancel download
    await cancelUseCase(taskId);
    tasks = await repository.getAllTasks();
    expect(tasks.any((t) => t.id == taskId), isFalse);
  });

  test('VerifyFileChecksumUseCase correctly validates real SHA-256 hash', () async {
    const checksumUseCase = VerifyFileChecksumUseCase();
    final tempDir = Directory.systemTemp.createTempSync('rdm_test_');
    final tempFile = File('${tempDir.path}/test_payload.txt');
    // "hello world" sha256 is b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9
    await tempFile.writeAsString('hello world');

    final matches = await checksumUseCase(
      tempFile.path,
      'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
    );
    expect(matches, isTrue);

    final wrongHashMatches = await checksumUseCase(
      tempFile.path,
      '0000000000000000000000000000000000000000000000000000000000000000',
    );
    expect(wrongHashMatches, isFalse);

    tempDir.deleteSync(recursive: true);
  });
}
