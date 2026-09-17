import 'dart:async';
import '../../domain/models/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../services/rust_engine_service.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({required this._engineService});

  final RustEngineService _engineService;
  final _settingsController = StreamController<AppSettings>.broadcast();
  AppSettings _settings = const AppSettings();

  @override
  Stream<AppSettings> watchSettings() {
    return _settingsController.stream;
  }

  @override
  AppSettings getSettings() {
    return _settings;
  }

  @override
  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    _settingsController.add(settings);
    if (settings.globalBandwidthLimitBps > 0) {
      await _engineService.setGlobalBandwidthLimit(settings.globalBandwidthLimitBps);
    }
  }

  void dispose() {
    _settingsController.close();
  }
}
