# RDM - Flutter-Rust Bridge & State Architecture Specification

> **Document ID**: RDM-PRD-006  
> **Target Subsystems**: `rdm_bridge` (FRB v2), `lib/data/`, `lib/domain/`, `lib/ui/`  
> **Interoperability Standard**: `flutter_rust_bridge` v2.0+ (C-ABI FFI)  
> **Status**: APPROVED FOR STAGE 1 ARCHITECTURE & IMPLEMENTATION  

---

## 1. Interoperability Topology (FRB v2)

The connection between the Flutter Dart frontend and the Rust backend engine is established via **`flutter_rust_bridge` (FRB) v2**. FRB v2 replaces slow serialization bridges (such as JSON over standard channels or Protobuf) with native C-ABI Dart FFI calls and zero-copy byte buffers.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             FLUTTER RUNTIME (Dart 3)                        │
│  Presentation (ViewModels) ──► Repositories ──► RustEngineService (Data)    │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
        ┌──────────────────────────────┴──────────────────────────────┐
        │                 DART FFI FOREIGN FUNCTION INTERFACE         │
        │  - Direct native pointer invocation (sub-microsecond)       │
        │  - Zero-Copy TypedData (`Uint8List`) for binary memory      │
        └──────────────────────────────┬──────────────────────────────┘
                                       │
┌──────────────────────────────────────▼──────────────────────────────────────┐
│                            RUST ENGINE (C-ABI)                              │
│  - Exported FRB v2 API Boundary (`#[frb]` attribute macros)                │
│  - Asynchronous StreamSink emitting high-frequency telemetry events        │
│  - Catch-unwind panic isolation preventing host process crashes             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Rust Bridge API Interface Definition

The Rust engine exposes a typed, asynchronous interface in `crates/rdm_engine/src/api.rs`:

### 2.1 Rust Command API
```rust
use flutter_rust_bridge::frb;
use crate::models::{DownloadTaskModel, TaskConfig, SegmentTelemetry};

#[frb(sync)]
pub fn init_engine(db_path: String, max_concurrency: usize) -> Result<(), String> {
    crate::coordinator::initialize(db_path, max_concurrency)
}

pub async fn add_download(config: TaskConfig) -> Result<String, String> {
    crate::coordinator::get_instance().add_task(config).await
}

pub async fn pause_download(task_id: String) -> Result<(), String> {
    crate::coordinator::get_instance().pause_task(&task_id).await
}

pub async fn resume_download(task_id: String) -> Result<(), String> {
    crate::coordinator::get_instance().resume_task(&task_id).await
}

pub async fn cancel_download(task_id: String, delete_file: bool) -> Result<(), String> {
    crate::coordinator::get_instance().cancel_task(&task_id, delete_file).await
}

pub async fn set_task_bandwidth_limit(task_id: String, limit_bps: u64) -> Result<(), String> {
    crate::coordinator::get_instance().set_task_limit(&task_id, limit_bps).await
}

pub async fn set_global_bandwidth_limit(limit_bps: u64) -> Result<(), String> {
    crate::coordinator::get_instance().set_global_limit(limit_bps).await
}

pub async fn refresh_task_url(
    task_id: String,
    new_url: String,
    headers: std::collections::HashMap<String, String>,
    cookies: Vec<crate::models::CookieDto>,
) -> Result<(), String> {
    crate::coordinator::get_instance()
        .refresh_task_url(&task_id, &new_url, headers, cookies)
        .await
}

pub async fn save_site_credential(
    domain: String,
    auth_type: String,
    username: String,
    password: String,
) -> Result<(), String> {
    crate::coordinator::get_instance()
        .save_credential(&domain, &auth_type, &username, &password)
        .await
}

pub async fn fetch_all_tasks() -> Result<Vec<DownloadTaskModel>, String> {
    crate::coordinator::get_instance().get_all_tasks().await
}
```

### 2.2 Telemetry Event Stream & 60Hz Throttling
To prevent saturating Dart's event loop during multi-gigabit downloads (which can process over 100,000 packets per second), the Rust engine batches telemetry updates into a **60Hz (16.6ms) or 100ms tick stream**:

```rust
use flutter_rust_bridge::frb;
use crate::telemetry::TelemetryEvent;

pub fn create_telemetry_stream(sink: StreamSink<TelemetryEvent>) -> Result<(), String> {
    tokio::spawn(async move {
        let mut rx = crate::coordinator::get_instance().subscribe_telemetry();
        while let Ok(event) = rx.recv().await {
            if sink.add(event).is_err() {
                break; // Flutter listener disposed
            }
        }
    });
    Ok(())
}
```

#### Telemetry Event Data Schema
```rust
#[frb]
pub enum TelemetryEvent {
    Progress {
        task_id: String,
        downloaded_bytes: u64,
        total_bytes: u64,
        indeterminate: bool, // Set true for chunked dynamic streams without Content-Length
        speed_bps: u64,
        eta_seconds: u32,
        active_connections: u32,
        segments: Vec<SegmentProgress>,
    },
    StatusChanged {
        task_id: String,
        old_status: TaskStatus,
        new_status: TaskStatus,
        error_message: Option<String>,
    },
    UrlExpired {
        task_id: String,
        original_url: String,
        http_status: u16,
    },
    TaskCompleted {
        task_id: String,
        file_path: String,
        file_size: u64,
        sha256_hash: String,
    },
}

#[frb]
pub struct SegmentProgress {
    pub connection_id: u32,
    pub start_offset: u64,
    pub current_offset: u64,
    pub end_offset: u64,
    pub speed_bps: u64,
}
```

---

## 3. Flutter Application Architecture (MVVM)

In accordance with architectural standards (`flutter-apply-architecture-best-practices`), RDM strictly separates UI rendering from business logic and data access.

```text
lib/
├── data/
│   ├── models/                 # Generated FRB models and SQLite DTOs
│   ├── repositories/           # Single source of truth repositories
│   │   ├── download_repository_impl.dart
│   │   └── settings_repository_impl.dart
│   └── services/               # Low-level service interfaces
│       ├── rust_engine_service.dart
│       └── system_tray_service.dart
├── domain/
│   ├── models/                 # Immutable domain entities
│   │   ├── download_task.dart
│   │   ├── segment_extent.dart
│   │   └── queue_group.dart
│   ├── repositories/           # Abstract repository contracts
│   └── use_cases/              # Reusable business logic
│       ├── start_download_use_case.dart
│       ├── pause_download_use_case.dart
│       └── verify_file_checksum_use_case.dart
└── ui/
    ├── core/                   # Design system tokens, custom canvas painters
    │   ├── theme/
    │   ├── widgets/
    │   └── canvas/
    │       ├── segment_visualizer_painter.dart
    │       └── speed_graph_painter.dart
    └── features/
        ├── download_list/
        │   ├── view_models/download_list_view_model.dart
        │   └── views/download_list_view.dart
        ├── task_inspector/
        │   ├── view_models/task_inspector_view_model.dart
        │   └── views/task_inspector_view.dart
        └── add_download/
            ├── view_models/add_download_view_model.dart
            └── views/add_download_dialog.dart
```

---

## 4. ViewModel & Reactive State Contracts

### 4.1 DownloadListViewModel
Manages the table state, filtering, and global action commands:
```dart
class DownloadListViewModel extends ChangeNotifier {
  DownloadListViewModel({
    required DownloadRepository downloadRepository,
    required PauseDownloadUseCase pauseDownloadUseCase,
    required ResumeDownloadUseCase resumeDownloadUseCase,
  })  : _downloadRepository = downloadRepository,
        _pauseUseCase = pauseDownloadUseCase,
        _resumeUseCase = resumeDownloadUseCase;

  final DownloadRepository _downloadRepository;
  final PauseDownloadUseCase _pauseUseCase;
  final ResumeDownloadUseCase _resumeUseCase;

  List<DownloadTask> _tasks = const [];
  List<DownloadTask> get tasks => _filteredTasks();

  String _searchQuery = '';
  TaskCategory? _selectedCategory;
  Set<String> _selectedTaskIds = {};

  void init() {
    _downloadRepository.watchAllTasks().listen((updatedTasks) {
      _tasks = updatedTasks;
      notifyListeners();
    });
  }

  Future<void> togglePauseSelected() async {
    for (final id in _selectedTaskIds) {
      final task = _tasks.where((t) => t.id == id).firstOrNull;
      if (task == null) continue;
      if (task.status == TaskStatus.downloading) {
        await _pauseUseCase(id);
      } else if (task.status == TaskStatus.paused || task.status == TaskStatus.error) {
        await _resumeUseCase(id);
      }
    }
  }

  Future<void> refreshDownloadAddress(String taskId) async {
    await _refreshUrlUseCase(taskId);
  }

  List<DownloadTask> _filteredTasks() {
    return _tasks.where((t) {
      final matchesSearch = t.filename.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null || t.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }
}
```

### 4.2 TaskInspectorViewModel (High-Frequency Segment Canvas)
Isolates 60Hz canvas updates so that progress bar repaints DO NOT trigger rebuilds of the full download table:
```dart
class TaskInspectorViewModel extends ChangeNotifier {
  TaskInspectorViewModel({
    required String taskId,
    required DownloadRepository downloadRepository,
  }) : _taskId = taskId,
       _downloadRepository = downloadRepository;

  final String _taskId;
  final DownloadRepository _downloadRepository;
  StreamSubscription? _telemetrySub;

  List<SegmentProgress> _segments = const [];
  List<SegmentProgress> get segments => _segments;

  List<double> _speedHistory = List.filled(60, 0.0);
  List<double> get speedHistory => _speedHistory;

  bool _isIndeterminate = false;
  bool get isIndeterminate => _isIndeterminate;

  void attach() {
    _telemetrySub = _downloadRepository.watchTaskTelemetry(_taskId).listen((telemetry) {
      _segments = telemetry.segments;
      _isIndeterminate = telemetry.indeterminate;
      _updateSpeedHistory(telemetry.speedBps.toDouble());
      notifyListeners(); // Re-renders only the canvas widget subtree
    });
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    super.dispose();
  }
}
```

---

## 5. Dependency Injection Registration (`get_it`)

All services, repositories, and use cases are wired in `lib/di/injection_container.dart`:
```dart
final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // 1. Core Services
  final rustEngineService = RustEngineService();
  await rustEngineService.initialize();
  getIt.registerSingleton<RustEngineService>(rustEngineService);

  // 2. Repositories
  getIt.registerLazySingleton<DownloadRepository>(
    () => DownloadRepositoryImpl(engineService: getIt<RustEngineService>()),
  );
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(engineService: getIt<RustEngineService>()),
  );

  // 3. Use Cases
  getIt.registerFactory(() => StartDownloadUseCase(getIt<DownloadRepository>()));
  getIt.registerFactory(() => PauseDownloadUseCase(getIt<DownloadRepository>()));
  getIt.registerFactory(() => ResumeDownloadUseCase(getIt<DownloadRepository>()));
  getIt.registerFactory(() => RefreshDownloadUrlUseCase(getIt<DownloadRepository>()));
  getIt.registerFactory(() => VerifyFileChecksumUseCase());

  // 4. ViewModels
  getIt.registerFactory(
    () => DownloadListViewModel(
      downloadRepository: getIt<DownloadRepository>(),
      pauseDownloadUseCase: getIt<PauseDownloadUseCase>(),
      resumeDownloadUseCase: getIt<ResumeDownloadUseCase>(),
    ),
  );
  getIt.registerFactoryParam<TaskInspectorViewModel, String, void>(
    (taskId, _) => TaskInspectorViewModel(
      taskId: taskId,
      downloadRepository: getIt<DownloadRepository>(),
    ),
  );
}
```
