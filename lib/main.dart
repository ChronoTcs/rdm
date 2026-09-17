import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'di/injection_container.dart';
import 'domain/models/app_settings.dart';
import 'domain/repositories/settings_repository.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/core/theme/color_tokens.dart';
import 'ui/core/widgets/activity_rail.dart';
import 'ui/core/widgets/app_header_bar.dart';
import 'ui/core/widgets/sidebar_navigation.dart';
import 'ui/core/widgets/drop_basket_target.dart';
import 'ui/features/download_list/view_models/download_list_view_model.dart';
import 'ui/features/download_list/views/download_list_view.dart';
import 'ui/features/task_inspector/view_models/task_inspector_view_model.dart';
import 'ui/features/task_inspector/views/task_inspector_view.dart';
import 'ui/features/add_download/view_models/add_download_view_model.dart';
import 'ui/features/add_download/views/add_download_dialog.dart';
import 'ui/features/settings/views/settings_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const RdmApp());
}

class RdmApp extends StatefulWidget {
  const RdmApp({super.key});

  @override
  State<RdmApp> createState() => _RdmAppState();
}

class _RdmAppState extends State<RdmApp> {
  late final SettingsRepository _settingsRepo;
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    _settingsRepo = getIt<SettingsRepository>();
    _settings = _settingsRepo.getSettings();
    _settingsRepo.watchSettings().listen((s) {
      setState(() => _settings = s);
    });
  }

  void _toggleTheme() {
    final isDark = _settings.themeMode != ThemeModeOption.cleanLight;
    final next = isDark ? ThemeModeOption.cleanLight : ThemeModeOption.modernDark;
    _settingsRepo.updateSettings(_settings.copyWith(themeMode: next));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RDM - Rust Download Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(_settings.themeMode),
      home: MainScreen(
        themeMode: _settings.themeMode,
        onToggleTheme: _toggleTheme,
        showDropBasket: _settings.showDropBasket,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    required this.showDropBasket,
  });

  final ThemeModeOption themeMode;
  final VoidCallback onToggleTheme;
  final bool showDropBasket;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final DownloadListViewModel _downloadListViewModel;
  TaskInspectorViewModel? _inspectorViewModel;
  String? _inspectedTaskId;
  RailViewMode _currentRailView = RailViewMode.downloads;

  @override
  void initState() {
    super.initState();
    _downloadListViewModel = getIt<DownloadListViewModel>();
    _downloadListViewModel.init();
    _downloadListViewModel.addListener(_onListChanged);
  }

  void _onListChanged() {
    setState(() {});
  }

  void _selectTaskForInspection(String taskId) {
    if (_inspectedTaskId == taskId) return;

    _inspectorViewModel?.dispose();
    _inspectedTaskId = taskId;
    _inspectorViewModel = getIt<TaskInspectorViewModel>(param1: taskId);
    _inspectorViewModel!.attach();
    setState(() {});
  }

  void _closeInspector() {
    _inspectorViewModel?.dispose();
    _inspectorViewModel = null;
    _inspectedTaskId = null;
    if (_currentRailView == RailViewMode.analytics) {
      _currentRailView = RailViewMode.downloads;
    }
    setState(() {});
  }

  Future<void> _openAddDownloadDialog([String? initialUrl]) async {
    final addVm = getIt<AddDownloadViewModel>();
    if (initialUrl != null) {
      addVm.setUrl(initialUrl);
    }
    final taskId = await showDialog<String>(
      context: context,
      builder: (ctx) => AddDownloadDialog(viewModel: addVm),
    );
    if (taskId != null) {
      _selectTaskForInspection(taskId);
    }
  }

  Future<void> _openSettingsDialog() async {
    final settingsRepo = getIt<SettingsRepository>();
    await showDialog(
      context: context,
      builder: (ctx) => SettingsDialog(settingsRepository: settingsRepo),
    );
  }

  @override
  void dispose() {
    _downloadListViewModel.removeListener(_onListChanged);
    _downloadListViewModel.dispose();
    _inspectorViewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorTokens.of(context);
    final selectedTask = _downloadListViewModel.currentSelectedTask;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const _AddDownloadIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.comma): const _OpenSettingsIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): const _TogglePauseIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _AddDownloadIntent: CallbackAction<_AddDownloadIntent>(
            onInvoke: (_) => _openAddDownloadDialog(),
          ),
          _OpenSettingsIntent: CallbackAction<_OpenSettingsIntent>(
            onInvoke: (_) => _openSettingsDialog(),
          ),
          _TogglePauseIntent: CallbackAction<_TogglePauseIntent>(
            onInvoke: (_) => _downloadListViewModel.togglePauseSelected(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: colors.canvasBackground,
            body: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Leftmost Activity Rail (Reference Images 1 & 4)
                      ActivityRail(
                        currentView: _currentRailView,
                        onSelectView: (view) {
                          if (view == RailViewMode.settings) {
                            _openSettingsDialog();
                          } else if (view == RailViewMode.analytics) {
                            setState(() => _currentRailView = view);
                            if (_inspectedTaskId == null && _downloadListViewModel.tasks.isNotEmpty) {
                              _selectTaskForInspection(_downloadListViewModel.tasks.first.id);
                            }
                          } else {
                            setState(() => _currentRailView = view);
                          }
                        },
                        isDark: widget.themeMode != ThemeModeOption.cleanLight,
                        onToggleTheme: widget.onToggleTheme,
                      ),
                      const SizedBox(width: 12),

                      // Sidebar Navigation (Reference Images 1 & 2)
                      SidebarNavigation(
                        selectedStatusFilter: _downloadListViewModel.selectedStatusFilter,
                        selectedCategory: _downloadListViewModel.selectedCategory,
                        onSelectStatus: (status) => _downloadListViewModel.setStatusFilter(status),
                        onSelectCategory: (cat) => _downloadListViewModel.setSelectedCategory(cat),
                        countAll: _downloadListViewModel.countAll,
                        countDownloading: _downloadListViewModel.countDownloading,
                        countPaused: _downloadListViewModel.countPaused,
                        countCompleted: _downloadListViewModel.countCompleted,
                        categoryCountProvider: (cat) => _downloadListViewModel.countForCategory(cat),
                      ),
                      const SizedBox(width: 12),

                      // Main Content Area
                      Expanded(
                        child: Column(
                          children: [
                            // Top Header Island Bar
                            AppHeaderBar(
                              onNewDownload: () => _openAddDownloadDialog(),
                              onResumeSelected: () => _downloadListViewModel.togglePauseSelected(),
                              onPauseSelected: () => _downloadListViewModel.togglePauseSelected(),
                              onDeleteSelected: () => _downloadListViewModel.cancelSelected(),
                              onSearchChanged: (q) => _downloadListViewModel.setSearchQuery(q),
                              onOpenSettings: _openSettingsDialog,
                              hasSelection: _downloadListViewModel.selectedTaskIds.isNotEmpty,
                              totalSpeedBps: _downloadListViewModel.totalSpeedBps,
                            ),
                            const SizedBox(height: 12),

                            // Download List Bento Island
                            Expanded(
                              child: DownloadListView(
                                viewModel: _downloadListViewModel,
                                onTaskSelected: (taskId) => _selectTaskForInspection(taskId),
                              ),
                            ),

                            // Floating Inspector Dock (Image 3 & 4 style)
                            if (_inspectorViewModel != null && selectedTask != null) ...[
                              const SizedBox(height: 12),
                              ListenableBuilder(
                                listenable: _inspectorViewModel!,
                                builder: (context, _) {
                                  return TaskInspectorView(
                                    viewModel: _inspectorViewModel!,
                                    task: selectedTask,
                                    onRefreshUrl: () {
                                      _downloadListViewModel.refreshDownloadAddress(
                                        selectedTask.id,
                                        selectedTask.url,
                                      );
                                    },
                                    onClose: _closeInspector,
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating Drop Basket Target
                if (widget.showDropBasket)
                  DropBasketTarget(
                    onUrlDropped: (url) => _openAddDownloadDialog(url),
                    onTap: () => _openAddDownloadDialog(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddDownloadIntent extends Intent {
  const _AddDownloadIntent();
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

class _TogglePauseIntent extends Intent {
  const _TogglePauseIntent();
}
