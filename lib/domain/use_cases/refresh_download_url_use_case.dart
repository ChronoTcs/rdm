import '../repositories/download_repository.dart';

class RefreshDownloadUrlUseCase {
  const RefreshDownloadUrlUseCase(this._repository);

  final DownloadRepository _repository;

  Future<void> call(
    String taskId,
    String newUrl, {
    Map<String, String> headers = const {},
  }) {
    return _repository.refreshDownloadUrl(taskId, newUrl, headers: headers);
  }
}
