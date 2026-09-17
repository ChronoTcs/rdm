import 'package:flutter/material.dart';
import '../theme/adaptive_icons.dart';
import '../theme/color_tokens.dart';

enum RailViewMode {
  downloads,
  analytics,
  settings,
}

/// Minimalist leftmost activity rail (Image 1 & 4)
/// Provides Brand Glyph, top navigation pills, and Sun/Moon theme switcher
class ActivityRail extends StatelessWidget {
  const ActivityRail({
    super.key,
    required this.currentView,
    required this.onSelectView,
    required this.isDark,
    required this.onToggleTheme,
  });

  final RailViewMode currentView;
  final ValueChanged<RailViewMode> onSelectView;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final colors = ColorTokens.of(context);

    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSubtle, width: 1),
        boxShadow: colors.isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          // Brand Logo Glyph (Gradient Box)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: ColorTokens.accentGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: ColorTokens.accentPrimary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                AdaptiveIcons.bolt,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Main View Tabs
          _buildRailItem(
            context: context,
            icon: AdaptiveIcons.download,
            tooltip: 'Downloads',
            isSelected: currentView == RailViewMode.downloads,
            onTap: () => onSelectView(RailViewMode.downloads),
          ),
          const SizedBox(height: 12),

          _buildRailItem(
            context: context,
            icon: AdaptiveIcons.tune,
            tooltip: 'Speed & Analytics',
            isSelected: currentView == RailViewMode.analytics,
            onTap: () => onSelectView(RailViewMode.analytics),
          ),
          const SizedBox(height: 12),

          _buildRailItem(
            context: context,
            icon: AdaptiveIcons.settings,
            tooltip: 'Settings (Ctrl+,)',
            isSelected: currentView == RailViewMode.settings,
            onTap: () => onSelectView(RailViewMode.settings),
          ),

          const Spacer(),

          // Sun / Moon Theme Mode Toggle Capsule (Image 4 pattern)
          Tooltip(
            message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            child: InkWell(
              onTap: onToggleTheme,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.cardElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.borderSubtle, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sun Icon Capsule Slot
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: !isDark ? colors.cardSurface : Colors.transparent,
                        shape: BoxShape.circle,
                        boxShadow: !isDark
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        Icons.light_mode,
                        size: 15,
                        color: !isDark ? ColorTokens.statusPause : colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Moon Icon Capsule Slot
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDark ? colors.cardSurface : Colors.transparent,
                        shape: BoxShape.circle,
                        boxShadow: isDark
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        Icons.dark_mode,
                        size: 15,
                        color: isDark ? ColorTokens.accentSecondary : colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRailItem({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = ColorTokens.of(context);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isSelected ? ColorTokens.accentPrimary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: ColorTokens.accentPrimary.withValues(alpha: 0.3), width: 1)
                : null,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: isSelected ? ColorTokens.accentPrimary : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
