import 'package:flutter/material.dart';
import '../../../../domain/models/download_task.dart';
import '../../../core/theme/adaptive_icons.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/theme/app_typography.dart';
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

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AdaptiveIcons.downloadDone,
              size: 48,
              color: ColorTokens.darkTextSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'No downloads in this view',
              style: TextStyle(
                fontSize: 14,
                color: ColorTokens.darkTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Table Header
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: ColorTokens.darkBgSurface,
            border: Border(
              bottom: BorderSide(color: ColorTokens.darkBorderSubtle, width: 1),
            ),
          ),
          child: const Row(
            children: [
              SizedBox(width: 32, child: Text('#', style: _headerStyle)),
              Expanded(flex: 4, child: Text('Name', style: _headerStyle)),
              Expanded(flex: 2, child: Text('Size', style: _headerStyle)),
              Expanded(flex: 3, child: Text('Progress', style: _headerStyle)),
              Expanded(flex: 2, child: Text('Speed', style: _headerStyle)),
              Expanded(flex: 2, child: Text('ETA', style: _headerStyle)),
              SizedBox(width: 48, child: Text('Action', style: _headerStyle)),
            ],
          ),
        ),

        // Table Rows
        Expanded(
          child: ListView.separated(
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const Divider(
              color: ColorTokens.darkBorderSubtle,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isSelected = viewModel.selectedTaskIds.contains(task.id);

              return InkWell(
                onTap: () {
                  viewModel.selectTask(task.id);
                  onTaskSelected(task.id);
                },
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: isSelected
                      ? ColorTokens.accentPrimary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      // Status Icon
                      SizedBox(
                        width: 32,
                        child: _buildStatusIcon(task.status),
                      ),

                      // Filename
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.filename,
                              style: AppTypography.tableCellPrimary.copyWith(
                                color: ColorTokens.darkTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              task.url,
                              style: AppTypography.tableCellSecondary.copyWith(
                                color: ColorTokens.darkTextSecondary,
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
                          style: AppTypography.dataMetricStyle.copyWith(
                            color: ColorTokens.darkTextSecondary,
                          ),
                        ),
                      ),

                      // Progress Bar & Percentage
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: task.indeterminate ? null : task.progressPercentage,
                                  backgroundColor: ColorTokens.darkBgElevated,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    task.status == TaskStatus.completed
                                        ? ColorTokens.statusDone
                                        : ColorTokens.statusActive,
                                  ),
                                  minHeight: 4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                task.indeterminate
                                    ? 'Streaming...'
                                    : '${(task.progressPercentage * 100).toStringAsFixed(1)}%',
                                style: AppTypography.tooltip.copyWith(
                                  color: ColorTokens.darkTextSecondary,
                                ),
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
                          style: AppTypography.dataMetricStyle.copyWith(
                            color: task.speedBps > 0
                                ? ColorTokens.statusActive
                                : ColorTokens.darkTextSecondary,
                          ),
                        ),
                      ),

                      // ETA
                      Expanded(
                        flex: 2,
                        child: Text(
                          task.formattedEta,
                          style: AppTypography.dataMetricStyle.copyWith(
                            color: ColorTokens.darkTextSecondary,
                          ),
                        ),
                      ),

                      // Pause / Resume Toggle Action
                      SizedBox(
                        width: 48,
                        child: IconButton(
                          icon: Icon(
                            task.status == TaskStatus.downloading
                                ? AdaptiveIcons.pause
                                : AdaptiveIcons.play,
                            size: 16,
                            color: ColorTokens.darkTextSecondary,
                          ),
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(TaskStatus status) {
    return switch (status) {
      TaskStatus.downloading => Icon(AdaptiveIcons.arrowDownward, size: 16, color: ColorTokens.statusActive),
      TaskStatus.paused => Icon(AdaptiveIcons.pause, size: 16, color: ColorTokens.statusPause),
      TaskStatus.completed => Icon(AdaptiveIcons.check, size: 16, color: ColorTokens.statusDone),
      TaskStatus.error => Icon(AdaptiveIcons.error, size: 16, color: ColorTokens.statusError),
      TaskStatus.expiredLink => Icon(AdaptiveIcons.linkOff, size: 16, color: ColorTokens.statusPause),
      TaskStatus.queued => Icon(AdaptiveIcons.schedule, size: 16, color: ColorTokens.darkTextSecondary),
    };
  }

  static const _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: ColorTokens.darkTextSecondary,
  );
}
