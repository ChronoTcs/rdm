import 'package:flutter/material.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/repositories/settings_repository.dart';
import '../../../core/theme/adaptive_icons.dart';
import '../../../core/theme/color_tokens.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.settingsRepository});

  final SettingsRepository settingsRepository;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settingsRepository.getSettings();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorTokens.of(context);

    return Dialog(
      backgroundColor: colors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.borderSubtle),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: ColorTokens.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(AdaptiveIcons.settings, size: 18, color: ColorTokens.accentPrimary),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'RDM Preferences',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Theme Mode Selection
            Text(
              'Interface Appearance:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildThemeCard(
                  title: 'Clean Light',
                  icon: Icons.light_mode,
                  isSelected: _settings.themeMode == ThemeModeOption.cleanLight,
                  onTap: () => setState(() => _settings = _settings.copyWith(themeMode: ThemeModeOption.cleanLight)),
                ),
                const SizedBox(width: 10),
                _buildThemeCard(
                  title: 'Modern Dark',
                  icon: Icons.dark_mode,
                  isSelected: _settings.themeMode == ThemeModeOption.modernDark,
                  onTap: () => setState(() => _settings = _settings.copyWith(themeMode: ThemeModeOption.modernDark)),
                ),
                const SizedBox(width: 10),
                _buildThemeCard(
                  title: 'OLED Black',
                  icon: Icons.contrast,
                  isSelected: _settings.themeMode == ThemeModeOption.oledBlack,
                  onTap: () => setState(() => _settings = _settings.copyWith(themeMode: ThemeModeOption.oledBlack)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Max Concurrency
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Default Concurrency:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
                ),
                Text(
                  '${_settings.maxConcurrency} threads',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ColorTokens.accentPrimary,
                  ),
                ),
              ],
            ),
            Slider(
              value: _settings.maxConcurrency.toDouble(),
              min: 1,
              max: 32,
              divisions: 31,
              activeColor: ColorTokens.accentPrimary,
              inactiveColor: colors.cardElevated,
              onChanged: (val) {
                setState(() {
                  _settings = _settings.copyWith(maxConcurrency: val.toInt());
                });
              },
            ),
            const SizedBox(height: 10),

            // Sound on complete
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Play Notification on Complete',
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
              ),
              value: _settings.playSoundOnComplete,
              activeThumbColor: ColorTokens.accentPrimary,
              onChanged: (val) {
                setState(() {
                  _settings = _settings.copyWith(playSoundOnComplete: val);
                });
              },
            ),

            // Drop basket
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Show Floating Drop Target Basket',
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
              ),
              value: _settings.showDropBasket,
              activeThumbColor: ColorTokens.accentPrimary,
              onChanged: (val) {
                setState(() {
                  _settings = _settings.copyWith(showDropBasket: val);
                });
              },
            ),

            const SizedBox(height: 20),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: ColorTokens.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: ColorTokens.accentPrimary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      await widget.settingsRepository.updateSettings(_settings);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Save Preferences', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = ColorTokens.of(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? ColorTokens.accentPrimary.withValues(alpha: 0.12) : colors.cardElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? ColorTokens.accentPrimary : colors.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? ColorTokens.accentPrimary : colors.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? ColorTokens.accentPrimary : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
