import 'package:flutter/material.dart';
import '../../../domain/models/download_task.dart';
import '../../features/download_list/view_models/download_list_view_model.dart';
import '../theme/adaptive_icons.dart';
import '../theme/color_tokens.dart';
import 'island_card.dart';

class SidebarNavigation extends StatelessWidget {
  const SidebarNavigation({
    super.key,
    required this.selectedStatusFilter,
    required this.selectedCategory,
    required this.onSelectStatus,
    required this.onSelectCategory,
    this.countAll = 0,
    this.countDownloading = 0,
    this.countPaused = 0,
    this.countCompleted = 0,
    this.categoryCountProvider,
  });

  final StatusFilter selectedStatusFilter;
  final TaskCategory? selectedCategory;
  final ValueChanged<StatusFilter> onSelectStatus;
  final ValueChanged<TaskCategory?> onSelectCategory;
  final int countAll;
  final int countDownloading;
  final int countPaused;
  final int countCompleted;
  final int Function(TaskCategory category)? categoryCountProvider;

  @override
  Widget build(BuildContext context) {
    final colors = ColorTokens.of(context);

    return IslandCard(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Tasks Filter
          _buildSectionHeader(context, 'TASKS'),
          const SizedBox(height: 6),
          _buildStatusItem(
            context: context,
            icon: AdaptiveIcons.allInbox,
            title: 'All Downloads',
            count: countAll,
            isSelected: selectedStatusFilter == StatusFilter.all && selectedCategory == null,
            onTap: () {
              onSelectCategory(null);
              onSelectStatus(StatusFilter.all);
            },
          ),
          _buildStatusItem(
            context: context,
            icon: AdaptiveIcons.downloading,
            title: 'Downloading',
            count: countDownloading,
            badgeColor: ColorTokens.accentPrimary,
            isSelected: selectedStatusFilter == StatusFilter.downloading,
            onTap: () => onSelectStatus(StatusFilter.downloading),
          ),
          _buildStatusItem(
            context: context,
            icon: AdaptiveIcons.pauseCircle,
            title: 'Paused',
            count: countPaused,
            badgeColor: ColorTokens.statusPause,
            isSelected: selectedStatusFilter == StatusFilter.paused,
            onTap: () => onSelectStatus(StatusFilter.paused),
          ),
          _buildStatusItem(
            context: context,
            icon: AdaptiveIcons.checkCircle,
            title: 'Completed',
            count: countCompleted,
            badgeColor: ColorTokens.statusDone,
            isSelected: selectedStatusFilter == StatusFilter.completed,
            onTap: () => onSelectStatus(StatusFilter.completed),
          ),

          const SizedBox(height: 18),
          Divider(color: colors.borderSubtle, height: 1),
          const SizedBox(height: 18),

          // Section: Categories
          _buildSectionHeader(context, 'CATEGORIES'),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildCategoryItem(
                  context: context,
                  category: TaskCategory.compressed,
                  color: ColorTokens.categoryCompressed,
                  icon: AdaptiveIcons.folderZip,
                  label: 'Compressed',
                ),
                _buildCategoryItem(
                  context: context,
                  category: TaskCategory.video,
                  color: ColorTokens.categoryVideo,
                  icon: AdaptiveIcons.video,
                  label: 'Video',
                ),
                _buildCategoryItem(
                  context: context,
                  category: TaskCategory.audio,
                  color: ColorTokens.categoryAudio,
                  icon: AdaptiveIcons.audio,
                  label: 'Audio',
                ),
                _buildCategoryItem(
                  context: context,
                  category: TaskCategory.documents,
                  color: ColorTokens.categoryDocuments,
                  icon: AdaptiveIcons.documents,
                  label: 'Documents',
                ),
                _buildCategoryItem(
                  context: context,
                  category: TaskCategory.programs,
                  color: ColorTokens.categoryPrograms,
                  icon: AdaptiveIcons.programs,
                  label: 'Programs',
                ),
              ],
            ),
          ),

          // Storage Space Overview Footer (Reference Image 2 & 4)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.cardElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderSubtle, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: ColorTokens.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    AdaptiveIcons.folder,
                    size: 16,
                    color: ColorTokens.accentPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Fast Storage',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'NVMe SSD Active',
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = ColorTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildStatusItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int count,
    Color? badgeColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = ColorTokens.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? ColorTokens.accentPrimary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: ColorTokens.accentPrimary.withValues(alpha: 0.25), width: 1)
                : Border.all(color: Colors.transparent, width: 1),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? ColorTokens.accentPrimary : colors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? colors.textPrimary : colors.textSecondary,
                  ),
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (badgeColor ?? ColorTokens.accentPrimary).withValues(alpha: 0.2)
                        : colors.cardElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? (badgeColor ?? ColorTokens.accentPrimary)
                          : colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem({
    required BuildContext context,
    required TaskCategory category,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    final colors = ColorTokens.of(context);
    final isSelected = selectedCategory == category;
    final count = categoryCountProvider?.call(category) ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () {
          if (isSelected) {
            onSelectCategory(null);
          } else {
            onSelectCategory(category);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? ColorTokens.accentPrimary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: ColorTokens.accentPrimary.withValues(alpha: 0.25), width: 1)
                : Border.all(color: Colors.transparent, width: 1),
          ),
          child: Row(
            children: [
              // Category Color Dot (Reference Image 2)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? colors.textPrimary : colors.textSecondary,
                  ),
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.cardElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
