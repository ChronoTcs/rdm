import 'package:flutter/material.dart';
import '../theme/adaptive_icons.dart';
import '../theme/color_tokens.dart';
import 'island_card.dart';

class AppHeaderBar extends StatefulWidget {
  const AppHeaderBar({
    super.key,
    required this.onNewDownload,
    required this.onResumeSelected,
    required this.onPauseSelected,
    required this.onDeleteSelected,
    required this.onSearchChanged,
    required this.onOpenSettings,
    this.hasSelection = false,
    this.totalSpeedBps = 0,
  });

  final VoidCallback onNewDownload;
  final VoidCallback onResumeSelected;
  final VoidCallback onPauseSelected;
  final VoidCallback onDeleteSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenSettings;
  final bool hasSelection;
  final int totalSpeedBps;

  @override
  State<AppHeaderBar> createState() => _AppHeaderBarState();
}

class _AppHeaderBarState extends State<AppHeaderBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorTokens.of(context);

    return IslandCard(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // App Brand & Glyph
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: ColorTokens.accentGradient,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: ColorTokens.accentPrimary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    AdaptiveIcons.bolt,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'RDM',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),

          // Search Field Pill (Image 2 & 3 style)
          Expanded(
            child: Container(
              height: 36,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: colors.cardElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.borderSubtle, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    AdaptiveIcons.search,
                    size: 16,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search downloads (Ctrl+F)...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: widget.onSearchChanged,
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    InkWell(
                      onTap: () {
                        _searchController.clear();
                        widget.onSearchChanged('');
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          AdaptiveIcons.close,
                          size: 14,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Live Network Throughput Pill (when active downloads occur)
          if (widget.totalSpeedBps > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ColorTokens.accentPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: ColorTokens.accentPrimary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AdaptiveIcons.arrowDownward,
                    size: 13,
                    color: ColorTokens.accentPrimary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_formatBytes(widget.totalSpeedBps)}/s',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ColorTokens.accentPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Primary Action: Add URL Button with Gradient
          Container(
            height: 36,
            decoration: BoxDecoration(
              gradient: ColorTokens.accentGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: ColorTokens.accentPrimary.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onNewDownload,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AdaptiveIcons.add, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      const Text(
                        'Add URL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Secondary Actions
          _buildActionButton(
            context: context,
            icon: AdaptiveIcons.play,
            tooltip: 'Resume Selected (Space)',
            isActive: widget.hasSelection,
            activeColor: ColorTokens.statusDone,
            onTap: widget.hasSelection ? widget.onResumeSelected : null,
          ),
          _buildActionButton(
            context: context,
            icon: AdaptiveIcons.pause,
            tooltip: 'Pause Selected (Space)',
            isActive: widget.hasSelection,
            activeColor: ColorTokens.statusPause,
            onTap: widget.hasSelection ? widget.onPauseSelected : null,
          ),
          _buildActionButton(
            context: context,
            icon: AdaptiveIcons.delete,
            tooltip: 'Delete Selected (Del)',
            isActive: widget.hasSelection,
            activeColor: ColorTokens.statusError,
            onTap: widget.hasSelection ? widget.onDeleteSelected : null,
          ),

          const SizedBox(width: 4),
          Container(
            width: 1,
            height: 20,
            color: colors.borderSubtle,
          ),
          const SizedBox(width: 4),

          _buildActionButton(
            context: context,
            icon: AdaptiveIcons.settings,
            tooltip: 'Settings (Ctrl+,)',
            isActive: true,
            activeColor: colors.textSecondary,
            onTap: widget.onOpenSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required Color activeColor,
    required VoidCallback? onTap,
  }) {
    final colors = ColorTokens.of(context);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 17,
            color: isActive ? activeColor : colors.textMuted.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }
    return '${dBytes.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
