import '../repositories/download_repository.dart';

class CancelDownloadUseCase {
  const CancelDownloadUseCase(this._repository);

  final DownloadRepository _repository;

  Future<void> call(String taskId, {bool deleteFile = false}) {
    return _repository.cancelDownload(taskId, deleteFile: deleteFile);
  }
}
