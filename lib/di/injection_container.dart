import 'package:get_it/get_it.dart';
import '../data/services/rust_engine_service.dart';
import '../data/repositories/download_repository_impl.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../domain/repositories/download_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/use_cases/start_download_use_case.dart';
import '../domain/use_cases/pause_download_use_case.dart';
import '../domain/use_cases/resume_download_use_case.dart';
import '../domain/use_cases/cancel_download_use_case.dart';
import '../domain/use_cases/refresh_download_url_use_case.dart';
import '../domain/use_cases/verify_file_checksum_use_case.dart';
import '../ui/features/download_list/view_models/download_list_view_model.dart';
import '../ui/features/task_inspector/view_models/task_inspector_view_model.dart';
import '../ui/features/add_download/view_models/add_download_view_model.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  if (getIt.isRegistered<RustEngineService>()) {
    await getIt.reset();
  }

  // 1. Core Native Engine Service
  final rustEngineService = RustEngineServiceImpl();
  await rustEngineService.initialize();
  getIt.registerSingleton<RustEngineService>(rustEngineService);

  // 2. Repositories
  getIt.registerLazySingleton<DownloadRepository>(
    () => DownloadRepositoryImpl(engineService: getIt<RustEngineService>()),
  );
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(engineService: getIt<RustEngineService>()),
  );

  // 3. Domain Use Cases
  getIt.registerFactory(() => StartDownloadUseCase(getIt<DownloadRepository>()));
  getIt.registerFactory(() => PauseDownloadUseCase(getIt<DownloadRepository>()));
  getIt.registerFactory(() => ResumeDownloadUseCase(getIt<DownloadRepository>()));
  getIt.registerFactory(() => CancelDownloadUseCase(getIt<DownloadRepository>()));
  getIt.registerFactory(() => RefreshDownloadUrlUseCase(getIt<DownloadRepository>()));
  getIt.registerFactory(() => const VerifyFileChecksumUseCase());

  // 4. Presentation ViewModels
  getIt.registerFactory(
    () => DownloadListViewModel(
      downloadRepository: getIt<DownloadRepository>(),
      pauseDownloadUseCase: getIt<PauseDownloadUseCase>(),
      resumeDownloadUseCase: getIt<ResumeDownloadUseCase>(),
      cancelDownloadUseCase: getIt<CancelDownloadUseCase>(),
      refreshDownloadUrlUseCase: getIt<RefreshDownloadUrlUseCase>(),
    ),
  );

  getIt.registerFactoryParam<TaskInspectorViewModel, String, void>(
    (taskId, _) => TaskInspectorViewModel(
      taskId: taskId,
      downloadRepository: getIt<DownloadRepository>(),
    ),
  );

  getIt.registerFactory(
    () => AddDownloadViewModel(
      startDownloadUseCase: getIt<StartDownloadUseCase>(),
    ),
  );
}
