import '../repositories/download_repository.dart';

class PauseDownloadUseCase {
  const PauseDownloadUseCase(this._repository);

  final DownloadRepository _repository;

  Future<void> call(String taskId) {
    return _repository.pauseDownload(taskId);
  }
}
