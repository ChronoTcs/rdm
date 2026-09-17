# RDM (Rust Download Manager) - Master Product Requirements Document (PRD)

> **Document Version**: 1.1.0-PROD  
> **Classification**: System Architectural & Product Specification  
> **Target Framework**: Flutter 3.24+ / 3.44+ (Desktop: Windows, macOS, Linux)  
> **Core Engine**: Rust 2021/2024 Edition (Tokio, reqwest, hyper, h3, memmap2)  
> **Interoperability**: `flutter_rust_bridge` (FRB) v2.x  
> **Status**: APPROVED FOR STAGE 1 ARCHITECTURE & IMPLEMENTATION  

---

## 1. Executive Summary & Product Charter

### 1.1 The Problem Space
For over two decades, **Internet Download Manager (IDM)** has remained the gold standard for transfer speeds and network utilization due to its proprietary dynamic multi-part segmentation algorithm. However, IDM is plagued by severe architectural and generational shortcomings:
1. **Windows-Only Lock-in**: No support for macOS or Linux.
2. **Archaic Win32 GUI**: Inflexible, pixelated, lacking dark mode, high-DPI scaling issues, and poor accessibility.
3. **The "Reassembly Stall" Bottleneck**: IDM downloads segments to separate temporary chunk files on disk, requiring an intensive, CPU- and disk-saturating reassembly/concatenation step at 100% completion that can take minutes for large (50GB+) files, rapidly wearing out solid-state drives (SSDs).
4. **Protocol Gaps**: Lacks native BitTorrent support, HTTP/3 (QUIC) protocols, modern media stream parsing (modern HLS with DRM awareness, MPEG-DASH audio-video muxing), and cloud storage link resolvers.
5. **Closed & Monolithic**: No modern REST/WebSocket API or headless daemon mode.

Conversely, open-source alternatives like **aria2** are fast and multi-protocol, but lack an official modern GUI, dynamic segment re-splitting, and native browser integration. Electron-based wrappers (e.g., Motrix) suffer from extreme memory footprints (300MB–800MB idle), sluggish UI rendering, and fragile IPC bridges.

### 1.2 The RDM Solution
**RDM (Rust Download Manager)** is an enterprise-grade, modern, cross-platform download accelerator engineered from the ground up to surpass IDM in throughput, efficiency, and user experience. 

RDM couples a **high-concurrency, memory-safe, zero-copy Rust download engine** with a **fluid, native-performance Flutter desktop interface**. 

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            FLUTTER DESKTOP UI                               │
│  (Modern Fluent / macOS HIG Design System, Custom Segment Visualizer Canvas)│
│  ├── Presentation Layer: Views & ViewModels (MVVM with ChangeNotifier)     │
│  ├── Domain Layer: UseCases, Entities, Immutable Models                    │
│  └── Desktop Widgets: Drop Basket Target, Mini Speed Pill, System Tray     │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                      flutter_rust_bridge v2 (Zero-Copy FFI)
               Command Dispatch (Async) │ Telemetry Stream (60Hz / 100ms ticks)
                                       │
┌──────────────────────────────────────▼──────────────────────────────────────┐
│                           RUST DOWNLOAD CORE ENGINE                         │
│  ├── Tokio Async Runtime & Dynamic Work-Stealing Segment Manager            │
│  ├── Zero-Copy Sparse File Allocator (`FSCTL_SET_SPARSE`, `fallocate`)      │
│  ├── Multi-Protocol Stack: HTTP/1.1, HTTP/2, HTTP/3 (QUIC), FTP, BitTorrent │
│  ├── Media Sniffer & HLS/DASH Remux Pipeline (Windows Named Pipe / FFmpeg)  │
│  ├── Expired Link Detection & Dynamic URL Refresh Engine                    │
│  ├── Token Bucket Hierarchical Bandwidth Limiter & Traffic Shaper           │
│  └── Persistence Layer: SQLite (WAL Mode) & Crash Resumption Bitmask        │
└───────────────────────┬───────────────────────────────┬─────────────────────┘
                        │                               │
             Native Messaging Protocol           OS Kernel Sockets
                 (32-bit JSON IPC)                & Direct Storage
                        │                               │
┌───────────────────────▼───────────────┐ ┌─────────────▼─────────────────────┐
│       BROWSER EXTENSION (MV3)         │ │   OPERATING SYSTEM PLATFORM       │
│  - Chromium (Chrome, Edge, Brave)     │ │  - Windows (Mica, Win32, IOCP)    │
│  - Firefox WebExtension               │ │  - macOS (Vibrancy, kqueue)       │
│  - In-Page Video/Audio Grabber Overlay│ │  - Linux (io_uring, SecretService)│
│  - URL Refresh Interception Workflow  │ │  - Headless CLI / JSON-RPC Daemon │
└───────────────────────────────────────┘ └───────────────────────────────────┘
```

### 1.3 Key Architectural Differentiators
- **Dynamic In-Half Work-Stealing Segmentation**: Continuously monitors chunk transfer rates. When a connection finishes or runs ahead, the slowest or largest remaining segment is bisected dynamically on-the-fly, keeping all configured network pipelines saturated.
- **Instant Pre-allocated Single-File Direct Writes (0ms Post-Download Stall)**: Replaces temporary split files with single pre-allocated sparse files via OS kernel primitives (`FSCTL_SET_SPARSE` on Windows, `fallocate` on Linux, `fstore_t` on macOS). Concurrent connections write directly to precise byte offsets via memory-mapped I/O or positional writes. When the last byte arrives, the file is 100% complete instantly—no file merging phase.
- **Dynamic URL Refresh / Expired Link Renewal**: When file host temporary URLs (AWS S3 presigned, Google Drive, Mega, CDN tokens) expire during long downloads (returning 403/410), RDM automatically intercepts or allows one-click link refreshing via the browser extension, swapping the URL while retaining all downloaded segments.
- **Lightweight Footprint**: Uses less than 75MB of RAM during multi-gigabit downloads, compared to 500MB+ in Electron-based solutions.
- **Native Browser Sniffing & Floating Video Grabber**: Manifest V3 extension featuring deep stream sniffing for HLS (`.m3u8`) and MPEG-DASH (`.mpd`), with an in-page floating download widget offering one-click resolution, audio-track extraction, and DRM protection detection.
- **Lossless Remuxing Pipeline**: Merges separated video and audio adaptive streams losslessly on Windows (via Windows Named Pipes) and Unix without intermediate re-encoding.
- **Desktop Drop Target Basket**: Semi-transparent floating drop basket allowing instant drag-and-drop of URLs, images, and text from any desktop application.
- **Headless CLI & Daemon Mode**: Full command-line interface and background JSON-RPC daemon for servers, NAS, and automation scripts.

---

## 2. Competitive Feature Matrix

| Feature / Capability | Internet Download Manager (IDM) | aria2 | Motrix (aria2 + Electron) | **RDM (Rust + Flutter)** |
| :--- | :--- | :--- | :--- | :--- |
| **GUI Framework** | Legacy Win32 MFC (1998) | None (CLI only) | Electron (Chromium/Node) | **Flutter 3.24+ Desktop (C++/DirectX/Metal)** |
| **Engine Language** | C++ (Proprietary) | C++ | C++ (aria2 CLI) | **Rust 2021/2024 Edition (Memory-Safe)** |
| **Supported Platforms** | Windows only | Windows, macOS, Linux | Windows, macOS, Linux | **Windows, macOS, Linux** |
| **Dynamic In-Half Segmentation** | Yes (Proprietary) | No (Static chunks) | No (Static chunks) | **Yes (Dynamic Work-Stealing Bisection)** |
| **Post-Download Concatenation Delay** | **Severe** (Merges split files) | None (Direct write) | None (Direct write) | **None (0ms Zero-Copy Sparse Pre-allocation)** |
| **Dynamic URL Refresh (Expired Links)**| Yes ("Refresh Download Address") | No | No | **Yes (Automated & One-Click URL Refresh)** |
| **HTTP/3 (QUIC) Protocol Support** | No | No | No | **Yes (`reqwest` + `h3` / `quiche`)** |
| **BitTorrent & Magnet Support** | No | Yes | Yes | **Yes (Native Rust BitTorrent Engine)** |
| **Adaptive Streaming (HLS / DASH)** | Basic TS grabber | No | No | **Yes (Full M3U8/MPD Demux & Remux)** |
| **DRM Detection (Widevine / EME)** | Incomplete / Corrupts | No | No | **Yes (Explicit DRM Detection & Warning)** |
| **Lossless Video/Audio Muxing** | External / Basic | No | No | **Yes (Embedded Named Pipe Remuxer)** |
| **Memory Footprint (Idle / Active)**| 25MB / 60MB | 15MB / 40MB | 350MB / 750MB | **35MB / 70MB** |
| **Browser Extension (Manifest V3)** | Yes (Windows Registry) | Third-party only | Third-party only | **Yes (Official Chrome & Firefox MV3)** |
| **In-Page Floating Video Grabber** | Yes | No | No | **Yes (Shadow DOM Injected Overlay)** |
| **Desktop Drop Target Basket** | Yes (Drop Basket) | No | No | **Yes (Floating Draggable Drop Target)** |
| **Custom Canvas Segment Visualization**| Yes (Classic 16-bar) | No | Simple single bar | **Yes (Multi-lane 60FPS Gradient Canvas)** |
| **Credential Vault Integration** | Plaintext / Obfuscated | CLI parameters | Plaintext config | **OS Native (DPAPI, Keychain, SecretService)** |
| **Headless CLI / Daemon Mode** | Limited CLI args | Yes (Full RPC) | No | **Yes (Unified CLI & JSON-RPC Daemon)** |
| **Internationalization (i18n)** | Yes | Yes | Yes | **Yes (Flutter `.arb` Multi-Language)** |

---

## 3. Technology Stack Specification

### 3.1 Frontend / Desktop Application Layer
- **Language**: Dart 3.5+ / 3.12+
- **Framework**: Flutter Desktop (Windows, macOS, Linux)
- **Architecture**: MVVM (Model-View-ViewModel) with strict Separation of Concerns (`flutter-apply-architecture-best-practices`)
- **State Management**: `ChangeNotifier` + `ListenableBuilder` / `ValueNotifier` with immutable ViewModels
- **Dependency Injection**: `get_it` v7.7+
- **Desktop System Integration**:
  - `window_manager` (frameless window, custom titlebars, drag areas)
  - `flutter_acrylic` (Windows Mica, Acrylic, macOS Vibrancy)
  - `tray_manager` / `system_tray` (System tray icon, tray context menu, dock minimize)
  - `local_notifier` (Native desktop notifications with action buttons)
  - `screen_retriever` (Multi-monitor awareness for floating widget placement)
- **Design Tokens & UI**:
  - Typography: `Inter` and `Segoe UI Variable` with tabular figures (`FontFeature.tabularFigures()`)
  - Icons: Phosphor Icons / Fluent UI System Icons
  - Rendering: Impeller (macOS/iOS) / Skia with DirectWrite & DirectX 11/12 (Windows)
- **Internationalization**: `flutter_localizations` with `.arb` translation catalogs.

### 3.2 Interoperability Layer (Bridge)
- **Framework**: `flutter_rust_bridge` (FRB) v2.x
- **Transport**: Native Dart FFI with zero-copy byte buffers (`Uint8List` directly referencing Rust allocations without memory duplication)
- **Telemetry Frequency**: Throttled 60Hz / 100ms tick streams across the native port to prevent UI thread message saturation
- **Safety**: Safe unwrapping, panic catching via `std::panic::catch_unwind`, structured error propagation across FFI boundaries

### 3.3 Core Download Engine (Rust Backend)
- **Language**: Rust 1.80+ / 1.94+ (Edition 2021/2024)
- **Async Runtime**: `tokio` 1.40+ (Multi-threaded work-stealing scheduler)
- **HTTP Client Stack**:
  - `reqwest` 0.12+ (with HTTP/1.1, HTTP/2, and HTTP/3 QUIC support enabled)
  - `hyper` 1.4+ / `h3` (Low-level HTTP protocol state control)
  - `rustls` 0.23+ with `webpki-roots` (Memory-safe TLS 1.3, avoiding OpenSSL dependency issues)
- **BitTorrent Engine**: `rqbit` / custom bittorrent peer protocol crate (uTP, DHT, PEX, magnet links)
- **File System & Memory I/O**:
  - `memmap2` 0.9+ (Cross-platform memory-mapped file access)
  - `windows-sys` 0.59+ (Win32 `DeviceIoControl` with `FSCTL_SET_SPARSE`, `SetFileInformationByHandle`)
  - `nix` (Kernel sparse file allocation, locking, `posix_fallocate`, `fstore_t`)
- **Media Processing**: `ffmpeg-next` 7.0+ / Bundled statically linked FFmpeg CLI (with Windows Named Pipe support)
- **Local Database & Persistence**:
  - `sqlx` 0.8+ with SQLite (WAL mode, foreign keys enabled)
  - Write-Ahead Log journal with atomic checkpointing and full session header persistence
- **Security & System Integration**:
  - `arboard` 3.4+ (Cross-platform clipboard monitoring)
  - `keyring` 3.2+ (Cross-platform secure credential storage via DPAPI / Keychain / Secret Service)
  - `ed25519-dalek` 2.1+ (Cryptographic release update verification via `VerifyingKey`)
  - `native_messaging` (Standard I/O stream framing for browser extension)

---

## 4. Master Document Index & Navigation

The PRD suite for RDM consists of the following 11 exhaustive specifications located in the `PRD/` directory:

1. **[00_MASTER_INDEX.md](file:///d:/File%20Mata%20Kuliah/Projek/rdm/PRD/00_MASTER_INDEX.md)**: Product charter, competitive matrix, system topology, technology stack, and documentation index.
2. **[01_PRODUCT_VISION_AND_CORE_REQUIREMENTS.md](file:///d:/File%20Mata%20Kuliah/Projek/rdm/PRD/01_PRODUCT_VISION_AND_CORE_REQUIREMENTS.md)**: Product vision, user personas, comprehensive functional requirement matrix (FR-ENG, FR-NET, FR-MED, FR-INT, FR-UI, FR-SCH, FR-SEC, FR-CLI) with MoSCoW prioritization, and non-functional requirements.
3. **[02_RUST_DOWNLOAD_ENGINE_SPECIFICATION.md](file:///d:/File%20Mata%20Kuliah/Projek/rdm/PRD/02_RUST_DOWNLOAD_ENGINE_SPECIFICATION.md)**: Deep architectural specification of the Rust engine, dynamic in-half segmentation algorithm, zero-copy sparse file pre-allocation (`FSCTL_SET_SPARSE`), indeterminate chunked stream mode, dynamic URL refresh engine, token bucket rate limiter, and crash-resilient bitmap journaling.
4. **[03_PROTOCOLS_AND_STREAM_SNIFFING_SPEC.md](file:///d:/File%20Mata%20Kuliah/Projek/rdm/PRD/03_PROTOCOLS_AND_STREAM_SNIFFING_SPEC.md)**: Multi-protocol engine (HTTP/1.1, HTTP/2, HTTP/3, FTP, BitTorrent, multi-source mirrors), HLS/DASH manifest parsing, DRM/EME sniffing & warning flow, AES-128 stream decryption, and cross-platform Windows Named Pipe FFmpeg remuxing.
5. **[04_BROWSER_EXTENSION_AND_INTEGRATION_SPEC.md](file:///d:/File%20Mata%20Kuliah/Projek/rdm/PRD/04_BROWSER_EXTENSION_AND_INTEGRATION_SPEC.md)**: Manifest V3 browser extension, MV3 Service Worker lifecycle & keepalive, Rust Native Messaging Host binary framing, floating video grabber overlay, URL refresh capture workflow, clipboard sniffing daemon, and batch crawler.
6. **[05_FLUTTER_UI_UX_AND_DESIGN_SYSTEM.md](file:///d:/File%20Mata%20Kuliah/Projek/rdm/PRD/05_FLUTTER_UI_UX_AND_DESIGN_SYSTEM.md)**: Complete UI/UX design specifications, color tokens, typography scale, responsive desktop layout, custom canvas segment visualization, floating desktop drop target basket, site logins manager, audio feedback system, and internationalization (i18n).
7. **[06_FLUTTER_RUST_BRIDGE_AND_STATE_ARCHITECTURE.md](file:///d:/File%20Mata%20Kuliah/Projek/rdm/PRD/06_FLUTTER_RUST_BRIDGE_AND_STATE_ARCHITECTURE.md)**: FRB v2 FFI contracts, telemetry stream event schemas (including indeterminate streams), Flutter MVVM architectural patterns, ViewModel state contracts, safe element lookups, and dependency injection container.
8. **[07_SCHEDULER_AUTOMATION_AND_STORAGE_SPEC.md](file:///d:/File%20Mata%20Kuliah/Projek/rdm/PRD/07_SCHEDULER_AUTOMATION_AND_STORAGE_SPEC.md)**: Multi-queue orchestration, time/calendar scheduling, post-completion actions (power management, scripts, dial-up/VPN hangup), SQLite relational schema with full session/header/mirror persistence, dynamic path templating, and archive extraction engine.
9. **[08_SECURITY_COMPLIANCE_AND_DISTRIBUTION.md](file:///d:/File%20Mata%20Kuliah/Projek/rdm/PRD/08_SECURITY_COMPLIANCE_AND_DISTRIBUTION.md)**: STRIDE threat model, native credential vaults, user-configurable antivirus command integration, FAT32 4GB barrier detection, sandboxing, cross-platform packaging (MSIX, DMG, AppImage, Flatpak), and cryptographic auto-updating using `ed25519-dalek` 2.x.
10. **[09_CLI_AND_HEADLESS_DAEMON_SPEC.md](file:///d:/File%20Mata%20Kuliah/Projek/rdm/PRD/09_CLI_AND_HEADLESS_DAEMON_SPEC.md)**: Complete CLI command-line arguments, headless daemon mode, JSON-RPC local socket protocol, headless container / NAS operation, and automation scripts.
11. **[10_TESTING_AND_QUALITY_ASSURANCE_SPEC.md](file:///d:/File%20Mata%20Kuliah/Projek/rdm/PRD/10_TESTING_AND_QUALITY_ASSURANCE_SPEC.md)**: Cross-system testing pyramid, Rust `proptest` segment bisection invariants, network fault injection & WireMock chaos testing, FFI load & panic isolation, Flutter ViewModel/Golden canvas tests, Playwright browser E2E, and GitHub Actions CI/CD matrix.

