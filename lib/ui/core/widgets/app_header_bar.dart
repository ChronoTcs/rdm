import 'package:flutter/material.dart';
import '../theme/adaptive_icons.dart';
import '../theme/color_tokens.dart';
import '../theme/app_typography.dart';

class AppHeaderBar extends StatelessWidget {
  const AppHeaderBar({
    super.key,
    required this.onNewDownload,
    required this.onResumeSelected,
    required this.onPauseSelected,
    required this.onDeleteSelected,
    required this.onSearchChanged,
    required this.onOpenSettings,
    this.hasSelection = false,
  });

  final VoidCallback onNewDownload;
  final VoidCallback onResumeSelected;
  final VoidCallback onPauseSelected;
  final VoidCallback onDeleteSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenSettings;
  final bool hasSelection;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: ColorTokens.darkBgSurface,
        border: Border(
          bottom: BorderSide(color: ColorTokens.darkBorderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          // App Brand & Logo
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ColorTokens.accentPrimary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  AdaptiveIcons.bolt,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'RDM',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: ColorTokens.darkTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),

          // Search Field
          Expanded(
            child: Container(
              height: 32,
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: ColorTokens.darkBgElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    AdaptiveIcons.search,
                    size: 16,
                    color: ColorTokens.darkTextSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: AppTypography.tableCellPrimary.copyWith(
                        color: ColorTokens.darkTextPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search downloads (Ctrl+F)...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: ColorTokens.darkTextSecondary,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: onSearchChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Action Buttons
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorTokens.accentPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            icon: Icon(AdaptiveIcons.add, size: 16),
            label: const Text('Add URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            onPressed: onNewDownload,
          ),
          const SizedBox(width: 8),

          IconButton(
            icon: Icon(AdaptiveIcons.play, size: 18),
            color: hasSelection ? ColorTokens.statusDone : ColorTokens.darkTextSecondary,
            tooltip: 'Resume Selected (Space)',
            onPressed: hasSelection ? onResumeSelected : null,
          ),
          IconButton(
            icon: Icon(AdaptiveIcons.pause, size: 18),
            color: hasSelection ? ColorTokens.statusPause : ColorTokens.darkTextSecondary,
            tooltip: 'Pause Selected (Space)',
            onPressed: hasSelection ? onPauseSelected : null,
          ),
          IconButton(
            icon: Icon(AdaptiveIcons.delete, size: 18),
            color: hasSelection ? ColorTokens.statusError : ColorTokens.darkTextSecondary,
            tooltip: 'Delete Selected (Del)',
            onPressed: hasSelection ? onDeleteSelected : null,
          ),
          const SizedBox(width: 8),
          const VerticalDivider(
            color: ColorTokens.darkBorderSubtle,
            thickness: 1,
            indent: 12,
            endIndent: 12,
          ),
          IconButton(
            icon: Icon(AdaptiveIcons.settings, size: 18),
            color: ColorTokens.darkTextSecondary,
            tooltip: 'Settings (Ctrl+,)',
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}
