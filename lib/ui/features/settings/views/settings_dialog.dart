import 'package:flutter/material.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/repositories/settings_repository.dart';
import '../../../core/theme/adaptive_icons.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/theme/app_typography.dart';

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
    return Dialog(
      backgroundColor: ColorTokens.darkBgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: ColorTokens.darkBorderSubtle),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(AdaptiveIcons.settings, size: 20, color: ColorTokens.accentPrimary),
                const SizedBox(width: 8),
                const Text('RDM Settings', style: AppTypography.displayHeading),
              ],
            ),
            const SizedBox(height: 20),

            // Max Concurrency
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Default Concurrency:', style: AppTypography.tableCellPrimary),
                Text('${_settings.maxConcurrency} connections', style: AppTypography.dataMetricStyle),
              ],
            ),
            Slider(
              value: _settings.maxConcurrency.toDouble(),
              min: 1,
              max: 32,
              divisions: 31,
              activeColor: ColorTokens.accentPrimary,
              inactiveColor: ColorTokens.darkBgElevated,
              onChanged: (val) {
                setState(() {
                  _settings = _settings.copyWith(maxConcurrency: val.toInt());
                });
              },
            ),
            const SizedBox(height: 12),

            // Sound on complete
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Play Sound on Completion', style: AppTypography.tableCellPrimary),
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
              title: const Text('Show Floating Drop Target Basket', style: AppTypography.tableCellPrimary),
              value: _settings.showDropBasket,
              activeThumbColor: ColorTokens.accentPrimary,
              onChanged: (val) {
                setState(() {
                  _settings = _settings.copyWith(showDropBasket: val);
                });
              },
            ),

            const SizedBox(height: 16),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: ColorTokens.darkTextSecondary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorTokens.accentPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () async {
                    await widget.settingsRepository.updateSettings(_settings);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Save Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
