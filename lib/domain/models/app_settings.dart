enum ThemeModeOption {
  modernDark,
  cleanLight,
  oledBlack,
}

class AppSettings {
  const AppSettings({
    this.maxConcurrency = 16,
    this.globalBandwidthLimitBps = 0,
    this.defaultDownloadPath = '',
    this.playSoundOnComplete = true,
    this.themeMode = ThemeModeOption.modernDark,
    this.showDropBasket = true,
    this.autoStartDownloads = true,
  });

  final int maxConcurrency;
  final int globalBandwidthLimitBps;
  final String defaultDownloadPath;
  final bool playSoundOnComplete;
  final ThemeModeOption themeMode;
  final bool showDropBasket;
  final bool autoStartDownloads;

  AppSettings copyWith({
    int? maxConcurrency,
    int? globalBandwidthLimitBps,
    String? defaultDownloadPath,
    bool? playSoundOnComplete,
    ThemeModeOption? themeMode,
    bool? showDropBasket,
    bool? autoStartDownloads,
  }) {
    return AppSettings(
      maxConcurrency: maxConcurrency ?? this.maxConcurrency,
      globalBandwidthLimitBps:
          globalBandwidthLimitBps ?? this.globalBandwidthLimitBps,
      defaultDownloadPath: defaultDownloadPath ?? this.defaultDownloadPath,
      playSoundOnComplete: playSoundOnComplete ?? this.playSoundOnComplete,
      themeMode: themeMode ?? this.themeMode,
      showDropBasket: showDropBasket ?? this.showDropBasket,
      autoStartDownloads: autoStartDownloads ?? this.autoStartDownloads,
    );
  }
}
