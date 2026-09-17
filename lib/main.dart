import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'di/injection_container.dart';
import 'domain/models/app_settings.dart';
import 'domain/repositories/settings_repository.dart';
import 'ui/core/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RDM - Rust Download Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(_settings.themeMode),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final DownloadListViewModel _downloadListViewModel;
  TaskInspectorViewModel? _inspectorViewModel;
  String? _inspectedTaskId;

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
            body: Stack(
              children: [
                Column(
                  children: [
                    // Header Bar
                    AppHeaderBar(
                      onNewDownload: () => _openAddDownloadDialog(),
                      onResumeSelected: () => _downloadListViewModel.togglePauseSelected(),
                      onPauseSelected: () => _downloadListViewModel.togglePauseSelected(),
                      onDeleteSelected: () => _downloadListViewModel.cancelSelected(),
                      onSearchChanged: (q) => _downloadListViewModel.setSearchQuery(q),
                      onOpenSettings: _openSettingsDialog,
                      hasSelection: _downloadListViewModel.selectedTaskIds.isNotEmpty,
                    ),

                    // Main Body: Sidebar + Table + Inspector Drawer
                    Expanded(
                      child: Row(
                        children: [
                          // Left Sidebar
                          SidebarNavigation(
                            selectedStatusFilter: _downloadListViewModel.selectedStatusFilter,
                            selectedCategory: _downloadListViewModel.selectedCategory,
                            onSelectStatus: (status) => _downloadListViewModel.setStatusFilter(status),
                            onSelectCategory: (cat) => _downloadListViewModel.setSelectedCategory(cat),
                          ),

                          // Center & Right Pane
                          Expanded(
                            child: Column(
                              children: [
                                // Download Table
                                Expanded(
                                  child: DownloadListView(
                                    viewModel: _downloadListViewModel,
                                    onTaskSelected: (taskId) => _selectTaskForInspection(taskId),
                                  ),
                                ),

                                // Bottom Inspector Drawer (if selected)
                                if (_inspectorViewModel != null && selectedTask != null)
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Floating Drop Target Basket (PRD 05 Section 6.4)
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
