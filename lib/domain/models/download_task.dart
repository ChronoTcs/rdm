enum TaskStatus {
  queued,
  downloading,
  paused,
  completed,
  error,
  expiredLink,
}

enum TaskCategory {
  general,
  compressed,
  video,
  audio,
  documents,
  programs;

  static TaskCategory fromExtension(String input) {
    final dotIndex = input.lastIndexOf('.');
    final clean = (dotIndex != -1 ? input.substring(dotIndex + 1) : input).toLowerCase().trim();
    switch (clean) {
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
      case 'bz2':
      case 'xz':
      case 'iso':
        return TaskCategory.compressed;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
      case 'webm':
      case 'flv':
      case 'ts':
      case 'm3u8':
        return TaskCategory.video;
      case 'mp3':
      case 'flac':
      case 'wav':
      case 'aac':
      case 'ogg':
      case 'm4a':
        return TaskCategory.audio;
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'xls':
      case 'xlsx':
      case 'ppt':
      case 'pptx':
      case 'txt':
        return TaskCategory.documents;
      case 'exe':
      case 'msi':
      case 'dmg':
      case 'pkg':
      case 'deb':
      case 'rpm':
      case 'apk':
        return TaskCategory.programs;
      default:
        return TaskCategory.general;
    }
  }
}

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.url,
    required this.filename,
    required this.destinationPath,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.status,
    required this.speedBps,
    required this.etaSeconds,
    required this.activeConnections,
    required this.indeterminate,
    required this.category,
    this.errorMessage,
    this.sha256Hash,
    required this.createdAt,
  });

  final String id;
  final String url;
  final String filename;
  final String destinationPath;
  final int totalBytes;
  final int downloadedBytes;
  final TaskStatus status;
  final int speedBps;
  final int etaSeconds;
  final int activeConnections;
  final bool indeterminate;
  final TaskCategory category;
  final String? errorMessage;
  final String? sha256Hash;
  final int createdAt;

  double get progressPercentage {
    if (indeterminate || totalBytes <= 0) return 0.0;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  String get formattedSpeed {
    if (speedBps <= 0) return '0 B/s';
    if (speedBps < 1024) return '$speedBps B/s';
    if (speedBps < 1024 * 1024) {
      return '${(speedBps / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speedBps / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  String get formattedTotalSize {
    if (indeterminate) return 'Unknown size';
    return formatBytes(totalBytes);
  }

  String get formattedDownloadedSize {
    return formatBytes(downloadedBytes);
  }

  String get formattedEta {
    if (status == TaskStatus.completed) return 'Done';
    if (status == TaskStatus.paused) return 'Paused';
    if (status == TaskStatus.error) return 'Error';
    if (indeterminate || speedBps <= 0 || etaSeconds <= 0) return '--';

    final minutes = etaSeconds ~/ 60;
    final seconds = etaSeconds % 60;
    if (minutes > 60) {
      final hours = minutes ~/ 60;
      final remMinutes = minutes % 60;
      return '${hours}h ${remMinutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  static String formatBytes(int bytes) {
    if (bytes < 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  DownloadTask copyWith({
    String? id,
    String? url,
    String? filename,
    String? destinationPath,
    int? totalBytes,
    int? downloadedBytes,
    TaskStatus? status,
    int? speedBps,
    int? etaSeconds,
    int? activeConnections,
    bool? indeterminate,
    TaskCategory? category,
    String? errorMessage,
    String? sha256Hash,
    int? createdAt,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      filename: filename ?? this.filename,
      destinationPath: destinationPath ?? this.destinationPath,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      speedBps: speedBps ?? this.speedBps,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      activeConnections: activeConnections ?? this.activeConnections,
      indeterminate: indeterminate ?? this.indeterminate,
      category: category ?? this.category,
      errorMessage: errorMessage ?? this.errorMessage,
      sha256Hash: sha256Hash ?? this.sha256Hash,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
