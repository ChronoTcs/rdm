import 'package:flutter/material.dart';
import '../../../core/theme/adaptive_icons.dart';
import '../../../core/theme/color_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../view_models/add_download_view_model.dart';

class AddDownloadDialog extends StatefulWidget {
  const AddDownloadDialog({super.key, required this.viewModel});

  final AddDownloadViewModel viewModel;

  @override
  State<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends State<AddDownloadDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _filenameController;
  late final TextEditingController _destController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.viewModel.url);
    _filenameController = TextEditingController(text: widget.viewModel.filename);
    _destController = TextEditingController(text: widget.viewModel.destinationPath);

    widget.viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (_filenameController.text != widget.viewModel.filename &&
        widget.viewModel.filename.isNotEmpty) {
      _filenameController.text = widget.viewModel.filename;
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    _urlController.dispose();
    _filenameController.dispose();
    _destController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;

    return Dialog(
      backgroundColor: ColorTokens.darkBgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: ColorTokens.darkBorderSubtle),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(AdaptiveIcons.download, size: 20, color: ColorTokens.accentPrimary),
                const SizedBox(width: 8),
                const Text(
                  'Add New Download',
                  style: AppTypography.displayHeading,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ColorTokens.accentPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    vm.detectedProtocol,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ColorTokens.accentSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // URL input
            const Text('Download Address (URL):', style: AppTypography.tableCellSecondary),
            const SizedBox(height: 6),
            TextField(
              controller: _urlController,
              style: AppTypography.tableCellPrimary,
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: const TextStyle(color: ColorTokens.darkTextSecondary),
                filled: true,
                fillColor: ColorTokens.darkBgElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (val) => vm.setUrl(val),
            ),
            const SizedBox(height: 12),

            // Filename input
            const Text('Save As (Filename):', style: AppTypography.tableCellSecondary),
            const SizedBox(height: 6),
            TextField(
              controller: _filenameController,
              style: AppTypography.tableCellPrimary,
              decoration: InputDecoration(
                hintText: 'filename.ext',
                hintStyle: const TextStyle(color: ColorTokens.darkTextSecondary),
                filled: true,
                fillColor: ColorTokens.darkBgElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (val) => vm.setFilename(val),
            ),
            const SizedBox(height: 12),

            // Concurrency Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Max Connections:', style: AppTypography.tableCellSecondary),
                Text('${vm.concurrency} connections', style: AppTypography.dataMetricStyle),
              ],
            ),
            Slider(
              value: vm.concurrency.toDouble(),
              min: 1,
              max: 32,
              divisions: 31,
              activeColor: ColorTokens.accentPrimary,
              inactiveColor: ColorTokens.darkBgElevated,
              onChanged: (val) => vm.setConcurrency(val.toInt()),
            ),

            if (vm.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                vm.errorMessage!,
                style: const TextStyle(color: ColorTokens.statusError, fontSize: 12),
              ),
            ],

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
                  onPressed: vm.isSubmitting
                      ? null
                      : () async {
                          final taskId = await vm.submit();
                          if (taskId != null && context.mounted) {
                            Navigator.of(context).pop(taskId);
                          }
                        },
                  child: vm.isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Start Download'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
