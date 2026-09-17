import '../models/download_task.dart';
import '../repositories/download_repository.dart';

class StartDownloadUseCase {
  const StartDownloadUseCase(this._repository);

  final DownloadRepository _repository;

  Future<String> call({
    required String url,
    required String destinationPath,
    String? filename,
    int concurrency = 16,
    int? limitBps,
    Map<String, String> headers = const {},
    TaskCategory? category,
  }) {
    return _repository.startDownload(
      url: url,
      destinationPath: destinationPath,
      filename: filename,
      concurrency: concurrency,
      limitBps: limitBps,
      headers: headers,
      category: category,
    );
  }
}
