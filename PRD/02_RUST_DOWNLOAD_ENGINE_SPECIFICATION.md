# RDM - Rust Download Engine Technical Specification

> **Document ID**: RDM-PRD-002  
> **Target Subsystem**: Core Engine (`rdm_engine` crate)  
> **Language & Toolchain**: Rust 1.80+ (Edition 2021/2024), Tokio 1.40+  
> **Status**: APPROVED FOR STAGE 1 ARCHITECTURE & IMPLEMENTATION  

---

## 1. Engine Architectural Topology

The core download engine is implemented as an autonomous, memory-safe, asynchronous Rust crate (`rdm_engine`). It executes on an independent Tokio multi-threaded runtime, isolated from the Flutter UI thread.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       ENGINE COORDINATOR (Actor Model)                      │
│  - Task Registry & Lifecycle Manager                                        │
│  - Persistent SQLite WAL Journal (Bitmask & Chunk Extents)                  │
│  - Hierarchical Token Bucket (HTB) Bandwidth Limiter                        │
└───────────────┬─────────────────────────────────────────────┬───────────────┘
                │ mpsc commands                               │ broadcast events
                ▼                                             ▼
┌───────────────────────────────┐             ┌───────────────────────────────┐
│     DOWNLOAD TASK CONTROLLER  │             │   TELEMETRY & EVENT STREAM    │
│  - Dynamic Work-Stealing      │             │  - Throttled 60Hz / 100ms     │
│    Segment Manager            │             │  - FRB v2 Zero-Copy Stream    │
│  - Connection Pool (1-64)     │             │  - Byte Progress & Speeds     │
└───────────────┬───────────────┘             └───────────────────────────────┘
                │ Spawns & Rebalances
                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     SEGMENT WORKER POOL (Tokio Tasks)                       │
│  Worker 1: [Range 0..10MB]       Worker 2: [Range 10..20MB] (Bisected)      │
│  Worker 3: [Range 20..35MB]      Worker 4: [Range 35..50MB] (Stealing)      │
│  - Keep-Alive Sockets (HTTP/1.1, HTTP/2, HTTP/3 QUIC, FTP)                 │
│  - In-flight Token Bucket Rate Limiting                                     │
└───────────────┬─────────────────────────────────────────────────────────────┘
                │ 64KB Chunk Buffers (Coalesced into 1MB Flushes)
                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                 ZERO-COPY STORAGE & FILE SYSTEM LAYER                       │
│  - Pre-Allocated Sparse Target File (NTFS / ext4 / APFS)                    │
│  - Concurrent Positional Writes (`write_at` / `seek_write` / `memmap2`)    │
│  - 0ms Post-Download Concatenation Delay (Instant Completion)               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. The Dynamic In-Half Segmentation Algorithm

Traditional download managers pre-calculate static segment ranges before downloading starts. If one connection hits a throttled network pipe or a congested server route, the entire download stalls waiting for the slowest segment ("tail latency problem").

RDM implements a **dynamic, recursive in-half work-stealing segmentation algorithm** that adapts in real-time.

### 2.1 Mathematical Model & In-Half Division Rule
Let a download task have total size $S$ bytes. At any given timestamp $t$, the file is partitioned into a set of disjoint byte intervals:
$$\mathcal{I}(t) = \{ [s_i, e_i] \mid 0 \le s_i \le e_i < S \}$$

Each interval $i$ has an active download cursor $c_i(t) \in [s_i, e_i]$.
- **Completed Bytes**: $[s_i, c_i(t))$
- **Remaining Bytes**: $R_i(t) = e_i - c_i(t)$

#### Dynamic Bisection Trigger
A bisection event is triggered under two conditions:
1. **Worker Completion**: A worker finishes its assigned interval ($c_i(t) = e_i$) while the active connection count $N < N_{\text{max}}$.
2. **Work-Stealing Rebalance**: A worker is idle, or variance between the fastest connection speed $v_{\text{fast}}$ and slowest connection speed $v_{\text{slow}}$ satisfies:
$$\frac{v_{\text{fast}} - v_{\text{slow}}}{v_{\text{fast}}} > \theta_{\text{variance}} \quad (\text{where } \theta_{\text{variance}} = 0.40)$$
and the largest remaining chunk satisfies $R_{\text{max}}(t) \ge 2 \times \text{MIN\_SPLIT\_SIZE}$.

#### In-Half Splitting Formula
Given the candidate interval with maximum remaining bytes $R_{\text{max}}(t) = e_k - c_k(t)$:
1. Calculate the bisecting midpoint:
$$M = c_k(t) + \left\lfloor \frac{e_k - c_k(t)}{2} \right\rfloor$$
2. The original worker $k$ is dynamically reassigned the updated truncated range:
$$I_k^{\text{new}} = [c_k(t), M]$$
3. The new or idle worker $k'$ is immediately assigned the stolen upper range:
$$I_{k'} = [M + 1, e_k]$$
4. Minimum split threshold $\text{MIN\_SPLIT\_SIZE} = 512\text{ KB}$. No segment smaller than 1 MB is ever split, preventing HTTP header and connection handshake overhead from exceeding download throughput gains.

### 2.2 Connection State Machine
Each connection worker runs as an independent Tokio task managed by the Segment Manager actor.

```
       ┌──────────────────────┐
       │     DISCONNECTED     │
       └──────────┬───────────┘
                  │ Connect / Acquire Socket from Pool
                  ▼
       ┌──────────────────────┐
       │  RESOLVING / TLS     │ (Happy Eyeballs RFC 8305 + TLS 1.3)
       └──────────┬───────────┘
                  │ TCP/TLS Established
                  ▼
       ┌──────────────────────┐
       │ RANGE_NEGOTIATION    │ (Sends HTTP `Range: bytes=s-e`)
       └──────────┬───────────┘
                  │ 206 Partial Content OK
                  ▼
       ┌──────────────────────┐
┌─────►│  STREAMING_CHUNKS    │◄─────────────────┐
│      └──────────┬───────────┘                  │
│                 │ Chunk Arrived                │ Dynamic Split Event:
│                 ▼                              │ Truncates upper bound
│      ┌──────────────────────┐                  │ to midpoint $M$
│      │ COALESCE_WRITE_CACHE │                  │
│      └──────────┬───────────┘                  │
│                 │ Remaining > 0                │
│                 └──────────────────────────────┘
│
│ Worker Reaches Upper Bound ($c_k = e_k$)
▼
┌─────────────────────────────┐
│       WORKER_IDLE           │
└─────────────┬───────────────┘
              │ Steal largest remaining segment from pool
              ▼
┌─────────────────────────────┐
│    ADOPT_STEAL_RANGE        │───► Re-enters RANGE_NEGOTIATION
└─────────────────────────────┘
```

### 2.3 Indeterminate Stream Mode (Chunked / Unknown Content-Length)
When the target server responds with `Transfer-Encoding: chunked` and omits `Content-Length` (e.g. dynamically generated zip archives, live streams, API telemetry exports), dynamic in-half bisection cannot divide an unknown interval.

In this scenario, RDM smoothly transitions into **Indeterminate Stream Mode**:
1. **Single-Stream Append Engine**: Bypasses sparse pre-allocation and multi-connection splitting. A single high-throughput Tokio worker streams data sequentially.
2. **Dynamic Page Growth**: Chunks are buffered through the 1MB Write Coalescing Ring and written sequentially to disk via append mode.
3. **Rolling Checksum & Size Tracking**: Tracks total downloaded bytes continuously without an upper ceiling.
4. **Completion on EOF**: When the HTTP chunked stream signals terminal chunk `0\r\n\r\n` or TCP socket closes on EOF, the file handle is flushed, fsync'd, and atomic rename occurs.
5. **UI Telemetry Adaptation**: Emits `TelemetryEvent::Progress` with `total_bytes: 0` and `indeterminate: true`. The Flutter UI displays an animated marquee progress bar, showing active speed and downloaded size without percentage or ETA calculations.

---

## 3. Zero-Copy Disk I/O & Sparse File Pre-Allocation

### 3.1 The 0ms Assembly Architecture
Legacy download managers create separate chunk files (e.g. `file.bin.001`, `file.bin.002`). Upon reaching 100%, they sequentially read every chunk from disk and append them into a final output file. For a 50GB file on an SSD running at 500MB/s, this forces 50GB of reads and 50GB of writes, causing a **100+ second lockup** and 100GB of premature SSD flash cell wear.

**RDM completely eliminates the concatenation phase**:
1. **Immediate Sparse Pre-Allocation**: Before the first byte is downloaded, RDM creates the single final file (`filename.ext.rdm_part`) and reserves its full size in the filesystem metadata without writing zeros to disk.
2. **Concurrent Positional Writes**: Each worker writes its incoming chunks directly to the exact target byte offset in the single file.
3. **Atomic Completion Rename**: When the last byte is verified, the file is renamed from `.rdm_part` to `.ext`. Assembly time is **0 milliseconds**.

### 3.2 Platform-Specific Pre-Allocation Primitives & Filesystem Fallbacks

RDM ensures instant zero-copy allocation across diverse storage mediums and filesystems (NTFS, APFS, ext4, exFAT, FAT32):

```rust
pub fn preallocate_sparse_file(file: &std::fs::File, total_bytes: u64, target_path: &std::path::Path) -> Result<(), std::io::Error> {
    // 1. FAT32 File Size Boundary Check (Max 4GB - 1 byte)
    if total_bytes >= 0xFFFF_FFFF {
        if is_fat32_volume(target_path) {
            return Err(std::io::Error::new(
                std::io::ErrorKind::FileTooLarge,
                "Target filesystem is FAT32 which cannot support files >= 4 GB. Choose an NTFS/exFAT/ext4 volume."
            ));
        }
    }

    #[cfg(target_os = "windows")]
    {
        use std::os::windows::io::AsRawHandle;
        use windows_sys::Win32::Storage::FileSystem::{
            SetFileInformationByHandle, FileAllocationInfo, FILE_ALLOCATION_INFO,
            SetFilePointerEx, SetEndOfFile, FILE_BEGIN,
        };
        use windows_sys::Win32::System::Ioctl::FSCTL_SET_SPARSE;
        use windows_sys::Win32::System::IO::DeviceIoControl;
        use std::ptr::null_mut;

        let handle = file.as_raw_handle() as isize;

        // Step A: Explicitly mark file as Sparse on NTFS/ReFS via DeviceIoControl
        // Crucial: Without FSCTL_SET_SPARSE, seeking to high offsets forces NTFS to synchronously
        // write physical zeroes across intermediate ranges, freezing disk I/O!
        let mut bytes_returned: u32 = 0;
        let sparse_res = unsafe {
            DeviceIoControl(
                handle,
                FSCTL_SET_SPARSE,
                null_mut(),
                0,
                null_mut(),
                0,
                &mut bytes_returned,
                null_mut(),
            )
        };

        if sparse_res != 0 {
            // NTFS Sparse mode succeeded: set logical allocation size instantly
            let mut alloc_info = FILE_ALLOCATION_INFO {
                AllocationSize: total_bytes as i64,
            };
            unsafe {
                SetFileInformationByHandle(
                    handle,
                    FileAllocationInfo,
                    &mut alloc_info as *mut _ as *mut std::ffi::c_void,
                    std::mem::size_of::<FILE_ALLOCATION_INFO>() as u32,
                );
            }
        } else {
            // Fallback for non-sparse filesystems (exFAT, FAT32, or SMB network drives):
            // Extend file logically using SetEndOfFile without zero-fill stall
            let mut new_pos: i64 = 0;
            unsafe {
                SetFilePointerEx(handle, total_bytes as i64, &mut new_pos, FILE_BEGIN);
                SetEndOfFile(handle);
                // Rewind file pointer to beginning for subsequent positional writes
                SetFilePointerEx(handle, 0, null_mut(), FILE_BEGIN);
            }
        }
    }

    #[cfg(target_os = "linux")]
    {
        use std::os::unix::io::AsRawFd;
        let fd = file.as_raw_fd();
        // Uses FALLOC_FL_KEEP_SIZE for instant non-zeroed allocation on ext4/XFS/Btrfs
        let ret = unsafe { nix::libc::fallocate(fd, 0, 0, total_bytes as nix::libc::off_t) };
        if ret != 0 {
            // Fallback to ftruncate if fallocate is unsupported (e.g. NFS/FUSE)
            unsafe { nix::libc::ftruncate(fd, total_bytes as nix::libc::off_t) };
        }
    }

    #[cfg(target_os = "macos")]
    {
        use std::os::unix::io::AsRawFd;
        let fd = file.as_raw_fd();
        let mut fst = nix::libc::fstore_t {
            fst_flags: nix::libc::F_ALLOCATECONTIG,
            fst_posmode: nix::libc::F_PEOFPOSMODE,
            fst_offset: 0,
            fst_length: total_bytes as nix::libc::off_t,
            fst_bytesalloc: 0,
        };
        let mut ret = unsafe { nix::libc::fcntl(fd, nix::libc::F_PREALLOCATE, &mut fst) };
        if ret == -1 {
            // Fallback to non-contiguous if disk is fragmented
            fst.fst_flags = nix::libc::F_ALLOCATEALL;
            ret = unsafe { nix::libc::fcntl(fd, nix::libc::F_PREALLOCATE, &mut fst) };
        }
        if ret == 0 {
            unsafe { nix::libc::ftruncate(fd, total_bytes as nix::libc::off_t) };
        } else {
            // APFS sparse fallback: ftruncate creates a sparse file without physical preallocation
            unsafe { nix::libc::ftruncate(fd, total_bytes as nix::libc::off_t) };
        }
    }

    Ok(())
}
```

### 3.3 Positional Concurrent Writes & Write Coalescing
Writing small 64KB network frames directly to disk generates random write I/O patterns that degrade NVMe/SSD drive controllers.

RDM implements a **Write Coalescing Buffer Ring**:
- Each worker streams network packets into a thread-local 1MB circular memory buffer.
- When the buffer reaches 1MB, or when a 250ms timer expires, the contiguous slice is written to disk in a single system call:
  - Windows: `std::os::windows::fs::FileExt::seek_write(&file, &buffer, offset)`
  - Unix: `std::os::unix::fs::FileExt::write_all_at(&file, &buffer, offset)`
- Memory-Mapped Alternative: For 64-bit systems with files under 16GB, RDM supports a zero-copy `memmap2::MmapMut` mode that maps the pre-allocated sparse file directly into virtual memory, allowing network sockets to write directly to user-space memory pages without kernel context switching.

---

## 4. Resumption State Machine & Persistence Journal

To guarantee 100% crash-proof resumption, RDM uses a dual-layer persistence model:

### 4.1 Block-Level Bitmap (The Resume Bitmask)
- The entire target file is divided into uniform blocks of size $B = 256\text{ KB}$.
- For a file of size $S$, a bit vector of length $K = \lceil S / B \rceil$ bits is maintained in memory:
$$\text{Bit } j = 1 \iff \text{Block } j \text{ is fully downloaded, written to disk, and fsync'd.}$$
- A 100GB file requires only $\approx 50\text{ KB}$ of memory to represent its complete download state bitmask.

### 4.2 SQLite Write-Ahead Logging (WAL) Journal
When a worker flushes a contiguous extent of blocks to disk:
1. An atomic SQL transaction updates the task's range allocation table:
```sql
UPDATE download_tasks 
SET downloaded_bytes = downloaded_bytes + ?1,
    last_modified = CURRENT_TIMESTAMP
WHERE id = ?2;

INSERT OR REPLACE INTO task_segments (task_id, start_offset, end_offset, current_offset, status)
VALUES (?1, ?2, ?3, ?4, ?5);
```
2. The SQLite database runs in `PRAGMA journal_mode=WAL;` with `PRAGMA synchronous=NORMAL;`.
3. In the event of sudden OS crash or power termination, on subsequent startup RDM reads the range table, scans the partial file boundaries, validates the last dirty blocks, and resumes all incomplete intervals without re-downloading a single verified byte.

### 4.3 Dynamic URL Refresh & Expired Link Recovery Engine
A notorious failure mode on file-hosting platforms (Google Drive, AWS S3 presigned URLs, Mega, 1fichier, Rapidgator, YouTube CDN streams) is **token expiration**. Large downloads running over several hours frequently fail midway when signed access tokens expire, causing servers to return `403 Forbidden` or `410 Gone`.

In legacy tools without link refreshing, the entire transfer is lost, forcing a restart from 0%. RDM implements a native **Dynamic URL Refresh Architecture**:

1. **Error Interception**: When connection workers encounter consecutive `403 Forbidden` or `410 Gone` errors on existing active segments, the engine suspends active socket retries and transitions the task into `TaskStatus::ExpiredLink`.
2. **Event Notification**: Emits `TelemetryEvent::UrlExpired { task_id, original_url, http_status }` across FFI to the Flutter UI and browser extension.
3. **Capture Workflow**:
   - User clicks **"Refresh Download Address"** in the UI (or the browser extension auto-prompts on interception).
   - The browser extension opens the original referrer page, intercepts the fresh download trigger, and extracts the new temporary signed URL along with refreshed session cookies and headers.
   - The extension forwards this payload to RDM via the Native Messaging Host (`action: "update_task_url"`).
4. **Zero-Byte Loss Atomic Swap**:
   ```rust
   pub async fn refresh_task_url(
       &self,
       task_id: &str,
       new_url: &str,
       new_headers: HeaderMap,
       new_cookies: Vec<Cookie>,
   ) -> Result<(), EngineError> {
       let mut task = self.get_task_mut(task_id).await?;
       
       // Step 1: Probe new URL with Range: bytes=0-0 to verify entity compatibility
       let probe = self.probe_metadata(new_url, &new_headers, &new_cookies).await?;
       if probe.content_length != task.total_bytes {
           return Err(EngineError::IncompatibleResourceLength);
       }

       // Step 2: Atomically persist updated URL and authentication in SQLite WAL
       self.db.update_task_url_and_auth(task_id, new_url, &new_headers, &new_cookies).await?;

       // Step 3: Retain existing .rdm_part sparse file, extents, and bitmask
       // Unfinished intervals are seamlessly re-issued to connection workers
       task.url = new_url.to_string();
       task.headers = new_headers;
       task.cookies = new_cookies;
       task.status = TaskStatus::Downloading;
       task.relaunch_pending_segments().await?;
       Ok(())
   }
   ```
5. **Seamless Continuation**: The existing `.rdm_part` file and verified 256KB block bitmasks remain completely untouched. Only the uncompleted byte ranges are requested from the new URL.

---

## 5. Hierarchical Token Bucket (HTB) Bandwidth Limiter

RDM features an exact microsecond-precision rate limiter that prevents network congestion and enables granular bandwidth allocation across downloads.

### 5.1 HTB Algorithm Specification
The bandwidth limiter operates at three hierarchical tiers:
1. **Tier 1 (Global Rate Limiter)**: Constrains aggregate traffic across all running downloads.
2. **Tier 2 (Queue Rate Limiter)**: Constrains traffic for specific queues (e.g. background queue vs foreground queue).
3. **Tier 3 (Per-Download Rate Limiter)**: User-configured limit on a specific task.

```
                    ┌─────────────────────────┐
                    │   GLOBAL TOKEN BUCKET   │ (Max Rate: e.g. 50 MB/s)
                    └────────────┬────────────┘
                                 │
                 ┌───────────────┴───────────────┐
                 ▼                               ▼
     ┌──────────────────────┐        ┌──────────────────────┐
     │  QUEUE A (Priority)  │        │  QUEUE B (Background)│
     │  Capacity: 40 MB/s   │        │  Capacity: 10 MB/s   │
     └───────────┬──────────┘        └───────────┬──────────┘
                 │                               │
         ┌───────┴───────┐                       ▼
         ▼               ▼               ┌──────────────┐
     Task 1 (30MB/s)  Task 2 (10MB/s)    │ Task 3 (10MB)│
```

### 5.2 Token Bucket Implementation (Async Rust)
- Tokens represent authorized bytes ($1\text{ token} = 1\text{ byte}$).
- Tokens are replenished at interval $\Delta t = 10\text{ ms}$ according to the configured bytes-per-second rate:
$$\text{Tokens}_{\text{added}} = \text{Rate}_{\text{bps}} \times \Delta t$$
- Before an active segment worker reads $N$ bytes from a socket, it acquires $N$ tokens from its task, queue, and global buckets:
```rust
pub async fn acquire_bandwidth_tokens(&self, requested_bytes: usize) -> usize {
    let mut available = self.task_bucket.acquire(requested_bytes).await;
    available = self.queue_bucket.acquire(available).await;
    available = self.global_bucket.acquire(available).await;
    available
}
```
- If tokens are depleted, the worker yields execution via Tokio's asynchronous timer (`tokio::time::sleep`), avoiding thread-blocking spin-locks and consuming 0% CPU while throttled.

---

## 6. Network Stack & Protocol Optimizations

### 6.1 Happy Eyeballs Dual-Stack Resolution (RFC 8305)
To prevent stalling on broken IPv6 configurations:
1. Issues concurrent DNS queries for `AAAA` (IPv6) and `A` (IPv4) records.
2. Prioritizes IPv6 by initiating an IPv6 TCP connection attempt first.
3. If IPv6 does not complete handshake within 250 milliseconds, launches a parallel IPv4 TCP connection attempt.
4. The first connection to complete the full TCP/TLS handshake wins; the slower connection is immediately aborted.

### 6.2 Modern HTTP/3 (QUIC) and HTTP/2 Multiplexing
- **HTTP/3 Support**: Handled via `reqwest` backed by `quiche` / `h3`. QUIC runs over UDP, eliminating head-of-line blocking across packet losses. Ideal for volatile Wi-Fi or mobile hotspots.
- **HTTP/2 Stream Re-use**: For servers supporting HTTP/2, multiple download segments can be multiplexed over a single TCP connection, drastically reducing connection negotiation round-trips.
- **TLS 1.3 Zero-RTT Resumption**: Uses `rustls` with pre-shared keys (PSK) to resume secure sessions without incurring 2-RTT handshake penalties.

---

## 7. Crate Architecture & Module Directory Structure

```text
crates/rdm_engine/
├── Cargo.toml
├── src/
│   ├── lib.rs                  # Public FFI / Bridge API exports
│   ├── coordinator.rs          # Central actor coordinating all download tasks
│   ├── config.rs               # Engine configurations and thresholds
│   ├── segmentation/
│   │   ├── mod.rs
│   │   ├── dynamic_split.rs    # In-half work-stealing bisection logic
│   │   ├── segment_manager.rs  # Worker lifecycle and rebalance coordinator
│   │   └── bitmask.rs          # 256KB block-level resume bit vector
│   ├── storage/
│   │   ├── mod.rs
│   │   ├── sparse_file.rs      # OS-specific sparse file pre-allocation
│   │   ├── positional_io.rs    # Concurrent seek_write & write_at handlers
│   │   ├── mmap_writer.rs      # Memory-mapped zero-copy file writer
│   │   └── write_coalescer.rs  # 1MB buffer ring flushing system
│   ├── network/
│   │   ├── mod.rs
│   │   ├── http_client.rs      # reqwest / hyper / h3 client wrapper
│   │   ├── happy_eyeballs.rs   # RFC 8305 IPv6/IPv4 racing resolver
│   │   ├── proxy.rs            # SOCKS5 / HTTP / PAC proxy router
│   │   └── token_bucket.rs     # Hierarchical token bucket rate limiter
│   ├── persistence/
│   │   ├── mod.rs
│   │   ├── sqlite_journal.rs   # WAL mode SQLite task and extent repository
│   │   └── schema.rs           # Embedded database migrations
│   └── telemetry/
│       ├── mod.rs
│       ├── speed_calculator.rs # Moving average throughput estimator
│       └── event_stream.rs     # 60Hz throttled progress events to Dart FFI
```
