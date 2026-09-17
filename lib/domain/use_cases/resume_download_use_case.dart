import '../repositories/download_repository.dart';

class ResumeDownloadUseCase {
  const ResumeDownloadUseCase(this._repository);

  final DownloadRepository _repository;

  Future<void> call(String taskId) {
    return _repository.resumeDownload(taskId);
  }
}
