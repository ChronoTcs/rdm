import '../models/app_settings.dart';

abstract class SettingsRepository {
  Stream<AppSettings> watchSettings();
  AppSettings getSettings();
  Future<void> updateSettings(AppSettings settings);
}
