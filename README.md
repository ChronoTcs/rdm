# RDM (Rust Download Manager)

A modern, high-performance desktop download manager engineered with a high-throughput **Rust** engine and an adaptive **Flutter** desktop presentation interface.

## Highlights
- **High-Throughput Rust Core**: Built on Tokio async runtime with dynamic in-half work-stealing bisection worker spawning and token bucket rate accumulation.
- **Resilient Chunked Resume**: 256KB block resume bitmask (`get_missing_ranges`) and sparse file preallocation with Win32 `FSCTL_SET_SPARSE`.
- **Platform-Adaptive Design**: Modern desktop UI with clean MVVM architecture, dynamic segment canvas visualizer, speed graphing, and platform-adaptive iconography (Google Material on Windows/Linux, Apple Cupertino on iOS/macOS).
- **Manifest V3 Browser Integration**: Native Messaging host using length-prefixed standard I/O for Chrome and Firefox extensions.
- **End-to-End Cryptography**: Streaming SHA-256 validation via Dart's `crypto` package.

## Architecture & Crates
- `crates/rdm_engine`: Core multi-segment download engine and coordinator.
- `crates/rdm_bridge`: C-ABI and FRB v2 FFI exports.
- `crates/rdm_cli`: CLI tool for direct downloads and task inspection.
- `crates/rdm_daemon`: Headless background daemon with JSON-RPC 2.0 API.
- `crates/rdm_native_host`: Browser extension Native Messaging host.
- `lib/`: Flutter desktop application (Presentation, ViewModels, Use Cases, Repositories).

## Getting Started

### Prerequisites
- **Rust** 1.94+ (`cargo`)
- **Flutter** 3.44+ / **Dart** 3.12+

### Running Tests
```bash
# Rust Workspace
cargo test --workspace
cargo clippy --workspace -- -D warnings

# Flutter Workspace
flutter test
flutter analyze
```

### Building
```bash
# Rust engine
cargo build --release --workspace

# Flutter desktop app
flutter build windows
```

## License
MIT OR Apache-2.0
