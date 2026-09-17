import 'package:flutter/material.dart';
import '../../../../domain/models/download_task.dart';
import '../../../core/canvas/segment_visualizer_painter.dart';
import '../../../core/canvas/speed_graph_painter.dart';
import '../../../core/theme/adaptive_icons.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/widgets/island_card.dart';
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
    final colors = ColorTokens.of(context);

    return IslandCard(
      height: 228,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ColorTokens.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    AdaptiveIcons.tune,
                    size: 16,
                    color: ColorTokens.accentPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'INSPECTOR: ${task.filename}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (task.status == TaskStatus.expiredLink) ...[
                TextButton.icon(
                  icon: Icon(AdaptiveIcons.refresh, size: 14, color: ColorTokens.statusPause),
                  label: const Text(
                    'Refresh Address',
                    style: TextStyle(fontSize: 12, color: ColorTokens.statusPause),
                  ),
                  onPressed: onRefreshUrl,
                ),
                const SizedBox(width: 8),
              ],
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.cardElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    AdaptiveIcons.close,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dynamic Segment Visualizer Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DYNAMIC SEGMENTS (${viewModel.segments.length} Parallel Connections)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: colors.textMuted,
                ),
              ),
              Text(
                '${(task.progressPercentage * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 20,
              width: double.infinity,
              child: CustomPaint(
                painter: SegmentVisualizerPainter(
                  segments: viewModel.segments,
                  totalBytes: viewModel.totalBytes > 0 ? viewModel.totalBytes : task.totalBytes,
                  isIndeterminate: viewModel.isIndeterminate || task.indeterminate,
                  backgroundColor: colors.cardElevated,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Lower Section: Metrics + 60s Speed Graph Spline
          Expanded(
            child: Row(
              children: [
                // Metrics Bento Container
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.cardElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.borderSubtle, width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetricRow(
                          colors: colors,
                          label: 'Downloaded:',
                          value: '${DownloadTask.formatBytes(viewModel.downloadedBytes)} / ${task.formattedTotalSize}',
                        ),
                        _buildMetricRow(
                          colors: colors,
                          label: 'Speed:',
                          value: '${DownloadTask.formatBytes(viewModel.currentSpeedBps)}/s',
                          highlightColor: ColorTokens.accentPrimary,
                          subValue: '(Peak: ${DownloadTask.formatBytes(viewModel.peakSpeedBps.toInt())}/s)',
                        ),
                        _buildMetricRow(
                          colors: colors,
                          label: 'Status:',
                          value: task.status.name.toUpperCase(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Speed Spline Graph Bento Container
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.cardElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.borderSubtle, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '60s THROUGHPUT HISTORY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: SpeedGraphPainter(
                                speedHistory: viewModel.speedHistory,
                                peakSpeed: viewModel.peakSpeedBps,
                                lineColor: ColorTokens.accentPrimary,
                                gridColor: colors.borderSubtle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required AppColorScheme colors,
    required String label,
    required String value,
    Color? highlightColor,
    String? subValue,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textMuted,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: highlightColor ?? colors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (subValue != null) ...[
          const SizedBox(width: 6),
          Text(
            subValue,
            style: TextStyle(
              fontSize: 11,
              color: colors.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}
