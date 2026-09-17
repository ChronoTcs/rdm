import 'package:flutter/material.dart';
import '../../../../domain/models/download_task.dart';
import '../../../core/canvas/segment_visualizer_painter.dart';
import '../../../core/canvas/speed_graph_painter.dart';
import '../../../core/theme/adaptive_icons.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../view_models/task_inspector_view_model.dart';

class TaskInspectorView extends StatelessWidget {
  const TaskInspectorView({
    super.key,
    required this.viewModel,
    required this.task,
    required this.onRefreshUrl,
    required this.onClose,
  });

  final TaskInspectorViewModel viewModel;
  final DownloadTask task;
  final VoidCallback onRefreshUrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: const BoxDecoration(
        color: ColorTokens.darkBgSurface,
        border: Border(
          top: BorderSide(color: ColorTokens.darkBorderSubtle, width: 1),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Icon(AdaptiveIcons.tune, size: 16, color: ColorTokens.accentSecondary),
              const SizedBox(width: 8),
              Text(
                'TASK INSPECTOR: ${task.filename}',
                style: AppTypography.sectionHeading.copyWith(
                  fontSize: 13,
                  color: ColorTokens.darkTextPrimary,
                ),
              ),
              const Spacer(),
              if (task.status == TaskStatus.expiredLink)
                TextButton.icon(
                  icon: Icon(AdaptiveIcons.refresh, size: 14, color: ColorTokens.statusPause),
                  label: const Text(
                    'Refresh Address',
                    style: TextStyle(fontSize: 12, color: ColorTokens.statusPause),
                  ),
                  onPressed: onRefreshUrl,
                ),
              IconButton(
                icon: Icon(AdaptiveIcons.close, size: 16),
                color: ColorTokens.darkTextSecondary,
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dynamic Segment Visualizer Canvas (PRD Section 4)
          Row(
            children: [
              Text(
                'DYNAMIC SEGMENT VISUALIZER (${viewModel.segments.length} Active Connections)',
                style: AppTypography.tooltip.copyWith(
                  color: ColorTokens.darkTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 24,
            width: double.infinity,
            child: CustomPaint(
              painter: SegmentVisualizerPainter(
                segments: viewModel.segments,
                totalBytes: viewModel.totalBytes > 0 ? viewModel.totalBytes : task.totalBytes,
                isIndeterminate: viewModel.isIndeterminate || task.indeterminate,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Lower Section: Metrics + Speed Graph Spline
          Expanded(
            child: Row(
              children: [
                // Metrics
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetricRow(
                        'Downloaded:',
                        '${DownloadTask.formatBytes(viewModel.downloadedBytes)} / ${task.formattedTotalSize}',
                      ),
                      const SizedBox(height: 4),
                      _buildMetricRow(
                        'Speed:',
                        '${DownloadTask.formatBytes(viewModel.currentSpeedBps)}/s (Peak: ${DownloadTask.formatBytes(viewModel.peakSpeedBps.toInt())}/s)',
                      ),
                      const SizedBox(height: 4),
                      _buildMetricRow(
                        'Status:',
                        task.status.name.toUpperCase(),
                      ),
                    ],
                  ),
                ),

                // Speed Spline Graph
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '60s THROUGHPUT HISTORY',
                        style: AppTypography.tooltip.copyWith(
                          color: ColorTokens.darkTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: SpeedGraphPainter(
                            speedHistory: viewModel.speedHistory,
                            peakSpeed: viewModel.peakSpeedBps,
                          ),
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

  Widget _buildMetricRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: AppTypography.tableCellSecondary.copyWith(
              color: ColorTokens.darkTextSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTypography.dataMetricStyle.copyWith(
            color: ColorTokens.darkTextPrimary,
          ),
        ),
      ],
    );
  }
}
