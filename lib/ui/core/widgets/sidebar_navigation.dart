import 'package:flutter/material.dart';
import '../../../domain/models/download_task.dart';
import '../../features/download_list/view_models/download_list_view_model.dart';
import '../theme/adaptive_icons.dart';
import '../theme/color_tokens.dart';

class SidebarNavigation extends StatelessWidget {
  const SidebarNavigation({
    super.key,
    required this.selectedStatusFilter,
    required this.selectedCategory,
    required this.onSelectStatus,
    required this.onSelectCategory,
  });

  final StatusFilter selectedStatusFilter;
  final TaskCategory? selectedCategory;
  final ValueChanged<StatusFilter> onSelectStatus;
  final ValueChanged<TaskCategory?> onSelectCategory;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: ColorTokens.darkBgSurface,
        border: Border(
          right: BorderSide(color: ColorTokens.darkBorderSubtle, width: 1),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        children: [
          _buildSectionHeader('TASKS'),
          _buildItem(
            icon: AdaptiveIcons.allInbox,
            title: 'All Downloads',
            isSelected: selectedStatusFilter == StatusFilter.all && selectedCategory == null,
            onTap: () {
              onSelectCategory(null);
              onSelectStatus(StatusFilter.all);
            },
          ),
          _buildItem(
            icon: AdaptiveIcons.downloading,
            title: 'Downloading',
            isSelected: selectedStatusFilter == StatusFilter.downloading,
            onTap: () => onSelectStatus(StatusFilter.downloading),
          ),
          _buildItem(
            icon: AdaptiveIcons.pauseCircle,
            title: 'Paused',
            isSelected: selectedStatusFilter == StatusFilter.paused,
            onTap: () => onSelectStatus(StatusFilter.paused),
          ),
          _buildItem(
            icon: AdaptiveIcons.checkCircle,
            title: 'Completed',
            isSelected: selectedStatusFilter == StatusFilter.completed,
            onTap: () => onSelectStatus(StatusFilter.completed),
          ),
          const SizedBox(height: 16),
          const Divider(color: ColorTokens.darkBorderSubtle, height: 1),
          const SizedBox(height: 16),
          _buildSectionHeader('CATEGORIES'),
          _buildCategoryItem(TaskCategory.compressed, AdaptiveIcons.folderZip, 'Compressed'),
          _buildCategoryItem(TaskCategory.video, AdaptiveIcons.video, 'Video'),
          _buildCategoryItem(TaskCategory.audio, AdaptiveIcons.audio, 'Audio'),
          _buildCategoryItem(TaskCategory.documents, AdaptiveIcons.documents, 'Documents'),
          _buildCategoryItem(TaskCategory.programs, AdaptiveIcons.programs, 'Programs'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ColorTokens.darkTextSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCategoryItem(TaskCategory category, IconData icon, String label) {
    final isSelected = selectedCategory == category;
    return _buildItem(
      icon: icon,
      title: label,
      isSelected: isSelected,
      onTap: () {
        if (isSelected) {
          onSelectCategory(null);
        } else {
          onSelectCategory(category);
        }
      },
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? ColorTokens.accentPrimary.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
          leading: Icon(
            icon,
            size: 16,
            color: isSelected ? ColorTokens.accentPrimary : ColorTokens.darkTextSecondary,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? ColorTokens.darkTextPrimary : ColorTokens.darkTextSecondary,
            ),
          ),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}
