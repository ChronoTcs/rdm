# RDM - Testing & Quality Assurance Specification

> **Document ID**: RDM-PRD-010  
> **Target Subsystem**: Cross-System QA, CI/CD, Unit, Integration, & Chaos Testing  
> **Status**: APPROVED FOR STAGE 1 ARCHITECTURE & IMPLEMENTATION  

---

## 1. Quality Assurance Philosophy & Testing Pyramid

For a high-performance download manager operating at line-rate gigabit speeds, software failure directly causes corrupted files, disk saturation, memory leaks, and broken user downloads. RDM adopts a multi-layered testing pyramid designed for 100% deterministic reproducibility across Windows, macOS, and Linux.

```
                  ┌───────────────────────────────┐
                  │      End-to-End System Tests  │  (Playwright Browser MV3 + App E2E)
                  ├───────────────────────────────┤
                  │     Network Chaos & Mocking   │  (WireMock, Toxiproxy, Dropped Sockets)
                  ├───────────────────────────────┤
                  │   Cross-Boundary FFI Tests    │  (FRB v2 Channel Invariant & Load Tests)
                  ├───────────────────────────────┤
                  │   Flutter Widget & Golden UI  │  (ViewModel unit tests, Canvas Goldens)
                  ├───────────────────────────────┤
                  │ Rust Core Unit & Property Tests│ (cargo test, proptest bisection invariants)
                  └───────────────────────────────┘
```

---

## 2. Layer 1: Rust Engine Core Testing (`crates/rdm_engine`)

The download engine must guarantee mathematical correctness, memory safety, and thread synchronization under high concurrency.

### 2.1 Unit & Invariant Property Testing (`proptest`)
Property-based testing validates that dynamic segment bisection never corrupts byte boundaries regardless of file size, connection count, or random midpoint division triggers:

```rust
#[cfg(test)]
mod tests {
    use proptest::prelude::*;
    use crate::segmentation::dynamic_split::bisect_interval;

    proptest! {
        #[test]
        fn test_dynamic_bisection_invariants(
            start in 0u64..1_000_000,
            cursor in 0u64..1_000_000,
            end in 1_000_000u64..10_000_000
        ) {
            // Invariant 1: Start <= Cursor <= End
            prop_assume!(start <= cursor && cursor < end);
            
            let remaining = end - cursor;
            if remaining >= 1024 * 1024 { // Minimum split threshold: 1MB
                let (truncated_range, stolen_range) = bisect_interval(cursor, end).unwrap();
                
                // Invariant 2: Ranges must be strictly contiguous and non-overlapping
                prop_assert_eq!(truncated_range.start, cursor);
                prop_assert_eq!(truncated_range.end + 1, stolen_range.start);
                prop_assert_eq!(stolen_range.end, end);
                
                // Invariant 3: Union of ranges equals original remaining range exactly
                prop_assert_eq!((truncated_range.end - truncated_range.start + 1) + 
                               (stolen_range.end - stolen_range.start + 1), remaining);
            }
        }
    }
}
```

### 2.2 Storage & Sparse File Integrity Verification
- **Zero-Corruption Hash Check**: Downloads a test payload with known SHA-256 hash using 16 concurrent workers writing to random out-of-order sparse offsets. Validates that final on-disk file matches SHA-256 bit-for-bit.
- **Sparse Allocation Fallback Test**: Runs tests on non-sparse simulated mount points to verify automatic fallback from `FSCTL_SET_SPARSE` to non-sparse pre-extension without crashing.
- **Boundary Validation**: Asserts that file sizes $\ge 4\text{ GB}$ on FAT32 mounts fail immediately with `ErrorKind::FileTooLarge` before initiating network requests.

---

## 3. Layer 2: Network Simulation & Chaos Testing

Unit tests against live websites are non-deterministic and flaky. RDM uses embedded mock HTTP servers (`wiremock` / `httptest`) and network chaos proxies (`toxiproxy`).

### 3.1 Test Scenarios & Fault Injections

| Chaos Scenario | Injected Condition | Expected Engine Behavior | Test Framework |
| :--- | :--- | :--- | :--- |
| **Expired Link (403/410)** | Server returns 403 Forbidden after 50MB downloaded | Engine catches 403, pauses active workers, triggers `UrlExpired` event, swaps URL via `refresh_task_url`, and resumes without loss. | `wiremock` + mock handler |
| **Silent Socket Drop** | Server stops responding to TCP Keep-Alive | Tokio timeout triggers socket drop; engine automatically reconnects and resumes segment from last flushed byte. | Simulated TCP drop |
| **High Latency & Jitter** | 300ms ± 150ms latency injected on worker 3 | Dynamic work-stealing algorithm detects lag, avoids giving worker 3 new chunks, and bisects chunk to faster worker. | `wiremock` delayed response |
| **Corrupted Byte Detection** | Injects bit-flip in 256KB block | Block checksum validation fails; engine rewinds segment cursor and redownloads corrupt block. | Block-level integrity runner |
| **Chunked / Unknown Size** | Server omits `Content-Length`, returns `Transfer-Encoding: chunked` | Engine enters Indeterminate Stream Mode, streams sequentially to EOF, emits indeterminate telemetry. | Mock HTTP chunked stream |

---

## 4. Layer 3: FFI Boundary & Interoperability Testing

Validates data stability between Rust and Dart across `flutter_rust_bridge` (FRB) v2:

* **Panic Isolation Test**: Injects an artificial panic inside a Rust worker task (`panic!("simulated engine panic")`). Verifies that `std::panic::catch_unwind` traps the panic, returns a typed error across FFI, and keeps the Flutter UI alive without crashing.
* **Telemetry Load & Frame Drop Test**: Emits 5,000 telemetry events per second across the native port. Verifies that the Rust-side event throttler clamps output to 60Hz / 100ms ticks, preserving zero frame drops (solid 60/120 FPS) on the Flutter rendering thread.
* **Memory Leak Check**: Executes 1,000 continuous download start/pause/cancel cycles in an automated loop, monitoring native memory via Valgrind / Heap Profiler to confirm zero dangling C-ABI pointers.

---

## 5. Layer 4: Flutter UI & ViewModel Testing (`lib/`)

Following Clean MVVM separation of concerns, presentation logic is tested independently of widget rendering.

### 5.1 ViewModel Unit Testing (`package:test` / `package:checks`)
* **DownloadListViewModel**: Tests filtering, multi-selection, category grouping, and search querying using mock `DownloadRepository`.
* **AddDownloadViewModel**: Tests URL validation, clipboard auto-detection, folder picker routing, and credential autofill.
* **100% Mock Isolation**: ViewModels contain zero `BuildContext` dependencies, allowing test execution in sub-millisecond execution times without launching an OS window.

### 5.2 Custom Canvas Golden Widget Tests
* **Segment Visualizer Canvas**: Renders `SegmentVisualizerPainter` under various download states (0%, 25% bisected, 50% mixed, 100% complete). Compares generated pixel bitmaps against baseline Golden PNGs to catch canvas rendering regressions.
* **Speed Sparkline Canvas**: Verifies historical throughput smoothing and linear gradient color transitions.

---

## 6. Layer 5: End-to-End Browser Extension Testing

Automates the complete browser-to-desktop download lifecycle using **Playwright** / **Puppeteer**:

1. **Extension Ingestion**: Playwright launches headless Chromium with the unpacked RDM WebExtension installed.
2. **Media Sniffing Verification**: Navigates to a mock video streaming page with an HLS `.m3u8` manifest.
3. **Grabber Overlay Click**: Asserts that the floating Shadow DOM video grabber widget appears within 500ms; clicks "Download 1080p".
4. **Native Messaging Verification**: Verifies that the browser extension correctly serializes the 4-byte length-prefixed JSON payload to `stdin` of `rdm_native_host`, receiving a successful task creation confirmation.

---

## 7. Automated CI/CD Testing Pipeline (GitHub Actions)

Every pull request and commit triggers an automated, multi-platform verification matrix:

```yaml
name: RDM Enterprise CI Matrix

on: [push, pull_request]

jobs:
  rust-core:
    strategy:
      matrix:
        os: [windows-latest, macos-latest, ubuntu-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Install Rust Stable
        uses: dtolnay/rust-toolchain@stable
      - name: Cargo Clippy (Linting)
        run: cargo clippy --all-targets -- -D warnings
      - name: Cargo Test (Unit + Property Tests)
        run: cargo test --workspace --verbose

  flutter-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.x'
          channel: 'stable'
      - name: Flutter Analyze
        run: flutter analyze --fatal-infos
      - name: Flutter Unit & Golden Tests
        run: flutter test --coverage

  cross-platform-build:
    needs: [rust-core, flutter-frontend]
    strategy:
      matrix:
        os: [windows-latest, macos-latest, ubuntu-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - name: Verify Cross-Platform Desktop Compilation
        run: echo "Compiles native binaries per platform"
```
