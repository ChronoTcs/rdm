import 'package:flutter/material.dart';
import '../../../../domain/models/download_task.dart';
import '../../../core/theme/adaptive_icons.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/widgets/island_card.dart';
import '../view_models/download_list_view_model.dart';

class DownloadListView extends StatelessWidget {
  const DownloadListView({
    super.key,
    required this.viewModel,
    required this.onTaskSelected,
  });

  final DownloadListViewModel viewModel;
  final ValueChanged<String> onTaskSelected;

  @override
  Widget build(BuildContext context) {
    final tasks = viewModel.tasks;
    final colors = ColorTokens.of(context);

    if (tasks.isEmpty) {
      return IslandCard(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.cardElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.borderSubtle, width: 1),
                ),
                child: Icon(
                  AdaptiveIcons.downloadDone,
                  size: 28,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No downloads in this view',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add a URL above or drop a link into the basket to start',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return IslandCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Table / Bento Card Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    'TYPE',
                    style: _headerStyle(colors),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: Text(
                    'FILE NAME',
                    style: _headerStyle(colors),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'SIZE',
                    style: _headerStyle(colors),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'PROGRESS',
                    style: _headerStyle(colors),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'SPEED',
                    style: _headerStyle(colors),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ETA',
                    style: _headerStyle(colors),
                  ),
                ),
                const SizedBox(
                  width: 44,
                  child: Text(
                    'ACTION',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: colors.borderSubtle, height: 1),
          const SizedBox(height: 6),

          // Download Items Bento List
          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                final isSelected = viewModel.selectedTaskIds.contains(task.id);
                return _buildTaskRow(context, task, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(BuildContext context, DownloadTask task, bool isSelected) {
    final colors = ColorTokens.of(context);
    final categoryColor = _getCategoryColor(task.category);
    final categoryIcon = _getCategoryIcon(task.category);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isSelected
            ? ColorTokens.accentPrimary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            viewModel.selectTask(task.id);
            onTaskSelected(task.id);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? ColorTokens.accentPrimary.withValues(alpha: 0.35)
                    : colors.borderSubtle.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Category Icon in Tinted Capsule (Reference Image 1 & 3)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Icon(
                      categoryIcon,
                      size: 18,
                      color: categoryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Filename and URL domain
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        task.filename,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatUrl(task.url),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Size
                Expanded(
                  flex: 2,
                  child: Text(
                    task.formattedTotalSize,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),

                // Progress Bar and Percentage
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: task.indeterminate ? null : task.progressPercentage,
                            backgroundColor: colors.cardElevated,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              task.status == TaskStatus.completed
                                  ? ColorTokens.statusDone
                                  : task.status == TaskStatus.paused
                                      ? ColorTokens.statusPause
                                      : task.status == TaskStatus.error
                                          ? ColorTokens.statusError
                                          : ColorTokens.accentPrimary,
                            ),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              task.indeterminate
                                  ? 'Streaming...'
                                  : '${(task.progressPercentage * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              _statusLabel(task.status),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(task.status),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Speed
                Expanded(
                  flex: 2,
                  child: Text(
                    task.formattedSpeed,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: task.speedBps > 0
                          ? ColorTokens.accentPrimary
                          : colors.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),

                // ETA
                Expanded(
                  flex: 2,
                  child: Text(
                    task.formattedEta,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),

                // Quick Action Button
                SizedBox(
                  width: 44,
                  child: IconButton(
                    icon: Icon(
                      task.status == TaskStatus.downloading
                          ? AdaptiveIcons.pause
                          : AdaptiveIcons.play,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                    tooltip: task.status == TaskStatus.downloading ? 'Pause' : 'Resume',
                    onPressed: () {
                      if (task.status == TaskStatus.downloading) {
                        viewModel.pauseTask(task.id);
                      } else {
                        viewModel.resumeTask(task.id);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _headerStyle(AppColorScheme colors) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: colors.textMuted,
      );

  Color _getCategoryColor(TaskCategory cat) => switch (cat) {
        TaskCategory.compressed => ColorTokens.categoryCompressed,
        TaskCategory.video => ColorTokens.categoryVideo,
        TaskCategory.audio => ColorTokens.categoryAudio,
        TaskCategory.documents => ColorTokens.categoryDocuments,
        TaskCategory.programs => ColorTokens.categoryPrograms,
        TaskCategory.general => ColorTokens.accentPrimary,
      };

  IconData _getCategoryIcon(TaskCategory cat) => switch (cat) {
        TaskCategory.compressed => AdaptiveIcons.folderZip,
        TaskCategory.video => AdaptiveIcons.video,
        TaskCategory.audio => AdaptiveIcons.audio,
        TaskCategory.documents => AdaptiveIcons.documents,
        TaskCategory.programs => AdaptiveIcons.programs,
        TaskCategory.general => AdaptiveIcons.folder,
      };

  Color _statusColor(TaskStatus status) => switch (status) {
        TaskStatus.downloading => ColorTokens.statusActive,
        TaskStatus.paused => ColorTokens.statusPause,
        TaskStatus.completed => ColorTokens.statusDone,
        TaskStatus.error => ColorTokens.statusError,
        TaskStatus.expiredLink => ColorTokens.statusPause,
        TaskStatus.queued => ColorTokens.darkTextSecondary,
      };

  String _statusLabel(TaskStatus status) => switch (status) {
        TaskStatus.downloading => 'Active',
        TaskStatus.paused => 'Paused',
        TaskStatus.completed => 'Done',
        TaskStatus.error => 'Failed',
        TaskStatus.expiredLink => 'Expired',
        TaskStatus.queued => 'Queued',
      };

  String _formatUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (_) {
      return url;
    }
  }
}
