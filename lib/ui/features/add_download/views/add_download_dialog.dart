import 'package:flutter/material.dart';
import '../../../core/theme/adaptive_icons.dart';
import '../../../core/theme/color_tokens.dart';
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
    final colors = ColorTokens.of(context);

    return Dialog(
      backgroundColor: colors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.borderSubtle),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Bar
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: ColorTokens.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(AdaptiveIcons.download, size: 18, color: ColorTokens.accentPrimary),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Add New Download',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: ColorTokens.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    vm.detectedProtocol,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ColorTokens.accentPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // URL input
            Text(
              'Download Address (URL):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _urlController,
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: TextStyle(color: colors.textMuted),
                filled: true,
                fillColor: colors.cardElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: ColorTokens.accentPrimary),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (val) => vm.setUrl(val),
            ),
            const SizedBox(height: 14),

            // Filename input
            Text(
              'Save As (Filename):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _filenameController,
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'filename.ext',
                hintStyle: TextStyle(color: colors.textMuted),
                filled: true,
                fillColor: colors.cardElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: ColorTokens.accentPrimary),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (val) => vm.setFilename(val),
            ),
            const SizedBox(height: 14),

            // Concurrency Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Max Connections:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
                ),
                Text(
                  '${vm.concurrency} threads',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ColorTokens.accentPrimary,
                  ),
                ),
              ],
            ),
            Slider(
              value: vm.concurrency.toDouble(),
              min: 1,
              max: 32,
              divisions: 31,
              activeColor: ColorTokens.accentPrimary,
              inactiveColor: colors.cardElevated,
              onChanged: (val) => vm.setConcurrency(val.toInt()),
            ),

            if (vm.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                vm.errorMessage!,
                style: const TextStyle(color: ColorTokens.statusError, fontSize: 12),
              ),
            ],

            const SizedBox(height: 18),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: ColorTokens.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: ColorTokens.accentPrimary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        : const Text('Start Download', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
