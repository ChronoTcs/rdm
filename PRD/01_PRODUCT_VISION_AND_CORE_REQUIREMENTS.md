# RDM - Product Vision & Core Requirements Specification

> **Document ID**: RDM-PRD-001  
> **Target Release**: RDM v1.0.0-PROD  
> **Status**: STABLE & APPROVED  

---

## 1. Product Vision & Value Proposition

### 1.1 Vision Statement
To deliver the fastest, most reliable, and aesthetically refined download manager in existence—unifying the low-overhead, multi-threaded raw power of Rust with the modern, fluid, cross-platform interface capabilities of Flutter. RDM is built for power users, developers, media archivers, and daily internet users who demand maximum line-rate saturation, seamless browser integration, and complete freedom from legacy platform constraints.

### 1.2 Core Pillars
1. **Unrivaled Throughput & Dynamic Adaptation**: Maximum network saturation via dynamic in-half segment splitting and intelligent connection work-stealing.
2. **Zero-Stall Instant Completion**: Single pre-allocated sparse files with positional writes eliminate post-download disk concatenation stalls.
3. **Pervasive Protocol & Stream Mastery**: Unified handling of HTTP/1.1, HTTP/2, HTTP/3 (QUIC), FTP, BitTorrent, and adaptive media streams (HLS/DASH).
4. **Modern, Native-Class UX**: 120 FPS buttery-smooth desktop UI, custom window acrylic/mica framing, real-time multi-lane segment visualizers, and strict keyboard navigation.
5. **Rock-Solid Crash Resilience**: Byte-level bitmask journaling guarantees 100% crash-proof resumption with zero data corruption.

---

## 2. Target User Personas & Use Case Scenarios

### Persona 1: "The Power Downloader / Media Archiver" (Marcus, 29)
- **Profile**: Downloads 4K/8K video courses, multi-gigabyte ISOs, game mods, FLAC audio libraries, and video streams from educational and streaming sites.
- **Pain Points with IDM/Current Tools**: IDM freezes his system for 5 minutes after a 60GB download while "assembling parts"; IDM cannot download HTTP/3 or modern fragmented MP4/DASH streams; IDM's UI looks like Windows 98.
- **RDM Delight Factor**: Instant file completion with 0ms assembly time, in-page floating video grabber that automatically muxes video and audio streams into single `.mp4` containers, and dark-mode multi-lane segment visualizer.

### Persona 2: "The DevOps / Systems Engineer" (Elena, 34)
- **Profile**: Operates across macOS, Linux, and Windows; frequently pulls multi-gigabyte Docker layers, dataset dumps, and VM images over remote high-latency connections.
- **Pain Points with Current Tools**: IDM does not exist on macOS/Linux. `curl` and `wget` lack dynamic segmentation and connection recovery. Electron tools (Motrix) eat 600MB of RAM and crash on high-concurrency downloads.
- **RDM Delight Factor**: Cross-platform feature parity across macOS, Linux, and Windows; CLI daemon mode; native credential vault support; < 60MB RAM footprint; robust checksum verification (SHA-256) auto-matched from clipboard.

### Persona 3: "The Bandwidth-Constrained Remote User" (Arjun, 24)
- **Profile**: Lives in a region with unstable broadband and expensive metered connections; internet frequently drops or fluctuates.
- **Pain Points with Current Tools**: Downloads fail permanently when connections reset; browser downloads restart from 0%; download managers hog all bandwidth, making work calls impossible.
- **RDM Delight Factor**: Aggressive auto-resume with exponential backoff; granular scheduled speed limits (e.g. throttle to 500 KB/s during work hours, uncapped from 01:00 to 06:00); automated system sleep upon queue completion.

---

## 3. Functional Requirements Matrix

Requirements are categorized by subsystem and prioritized using the **MoSCoW** convention:
- **M (Must Have)**: Non-negotiable for Stage 1 / v1.0.
- **S (Should Have)**: Highly desirable; included in v1.0 unless blocking.
- **C (Could Have)**: Useful enhancements planned for v1.1.
- **W (Won't Have)**: Explicitly deferred to Stage 2+.

### 3.1 Core Engine & Segmentation (ENG)

| ID | Title | Priority | Description | Acceptance Criteria |
| :--- | :--- | :---: | :--- | :--- |
| **FR-ENG-001** | Dynamic In-Half Segmentation | **M** | Bisects the largest active segment in half whenever a connection finishes or an idle connection becomes available. | Idle workers immediately adopt sub-ranges of active segments without resetting existing byte progress. |
| **FR-ENG-002** | Work-Stealing Segment Allocation | **M** | Connection pool dynamically steals remaining bytes from the slowest running connection if variance exceeds 40%. | Slowest segment tail latency is reduced; download completes with all connections active until final bytes. |
| **FR-ENG-003** | Sparse File Pre-Allocation | **M** | Pre-allocates single destination file instantly on disk using OS primitives without zero-filling. | File allocation completes in < 50ms for a 100GB file on NTFS, APFS, and ext4. |
| **FR-ENG-004** | Positional Concurrent Writes | **M** | Concurrently writes byte chunks directly to target file offsets via memory-mapped I/O or positional descriptors. | Concurrent threads write to disparate file offsets without race conditions or file locking bottlenecks. |
| **FR-ENG-005** | Zero Concatenation Completion | **M** | Finalizes download immediately upon receiving last byte without disk-merge phase. | File status changes to `Completed` within 10ms of last byte arrival, regardless of file size. |
| **FR-ENG-006** | Block-Level Resumption Bitmask | **M** | Tracks downloaded blocks (64KB chunks) in a persistent bit vector synced with SQLite WAL. | After power loss / kill -9, engine resumes without re-downloading previously committed blocks. |
| **FR-ENG-007** | Server Range Support Probing | **M** | Issues `HEAD` / `GET` range probe (`bytes=0-0`) to verify `Accept-Ranges: bytes` and `Content-Length`. | If server rejects ranges, falls back automatically to single-stream downloading while alerting the user. |
| **FR-ENG-008** | ETag & Last-Modified Integrity | **M** | Stores `ETag` and `Last-Modified` headers; validates them on resume with `If-Range` or `If-Match`. | If server resource has changed, engine alerts user and requests confirmation before restarting fresh. |
| **FR-ENG-009** | Dynamic Connection Scaling | **S** | User can configure max connections per download (1 to 64; default 16), dynamic adjust while active. | Changing connection slider updates active connection pool within 500ms without restarting download. |
| **FR-ENG-010** | Hierarchical Token Bucket Limiter | **M** | Enforces global, per-queue, and per-download speed throttles via high-precision token bucket algorithm. | Bandwidth stays within ±2% of configured cap across 1s, 5s, and 60s smoothing windows. |
| **FR-ENG-011** | Expired Link Renewal & URL Refresh | **M** | Intercepts HTTP 403/410/expired token errors on file hosts (Google Drive, AWS S3 presigned, Mega); enables one-click or automated URL replacement without discarding downloaded segments. | Replaces task URL and session headers in SQLite; resumes remaining byte extents seamlessly from current bitmask. |
| **FR-ENG-012** | Indeterminate Stream Mode | **M** | Handles dynamic chunked transfer encoding (`Transfer-Encoding: chunked`) where Content-Length is absent. | Operates in single-stream sequential append mode, dynamically growing file with indeterminate UI progress. |
| **FR-ENG-013** | Multi-Filesystem Portability & FAT32 Barrier | **M** | Detects filesystem type (NTFS, APFS, ext4, exFAT, FAT32); issues `FSCTL_SET_SPARSE` on NTFS, falls back gracefully on non-sparse filesystems, and prevents >4GB downloads on FAT32 volumes. | Pre-flight check warns user before starting if target volume cannot support file size. |

### 3.2 Networking & Protocols (NET)

| ID | Title | Priority | Description | Acceptance Criteria |
| :--- | :--- | :---: | :--- | :--- |
| **FR-NET-001** | HTTP/1.1 & HTTP/2 Support | **M** | Full support for keep-alive connection pooling, chunked transfer, and HTTP/2 stream multiplexing. | Reuses existing TLS/TCP connections across consecutive segments to eliminate handshake overhead. |
| **FR-NET-002** | HTTP/3 (QUIC) Protocol Support | **S** | Leverages UDP-based QUIC protocol via `reqwest` + `h3` for servers supporting `alt-svc`. | Automatic migration and head-of-line blocking elimination over lossy wireless connections. |
| **FR-NET-003** | Happy Eyeballs Dual-Stack DNS | **M** | Implements RFC 8305 to race IPv6 and IPv4 address connections with a 250ms head start for IPv6. | Connects via fastest available path; fails over seamlessly if IPv6 is misconfigured. |
| **FR-NET-004** | FTP / FTPS Protocol Support | **M** | Full RFC 959 / RFC 2228 FTP support with TLS encryption, PASV/EPSV modes, and `REST` resume. | Supports authenticated FTP, passive data port negotiation, and multi-threaded segmentation. |
| **FR-NET-005** | BitTorrent & Magnet Integration | **S** | Integrated BitTorrent client parsing `.torrent` and `magnet:` URIs with DHT, PEX, and piece verification. | Downloads torrents with multi-file selection tree, seeder/leecher counts, and sequential download mode. |
| **FR-NET-006** | Multi-Source / Mirror Acceleration| **S** | Downloads distinct segments of the identical file simultaneously from multiple mirror URLs. | Segments fetched from 2+ servers are verified and assembled into the single target file. |
| **FR-NET-007** | Proxy & SOCKS5 Support | **M** | Supports HTTP, HTTPS, and SOCKS5 proxies with authentication; PAC script parsing. | User can configure global proxy or per-download proxy; bypasses local LAN addresses. |
| **FR-NET-008** | Automatic Redirect Handling | **M** | Follows HTTP 301, 302, 303, 307, 308 redirects up to 10 hops while updating target URI and cookies. | Handles redirects across protocol boundaries (HTTP -> HTTPS); maintains authorization headers if configured. |

### 3.3 Media Sniffing & Stream Grabber (MED)

| ID | Title | Priority | Description | Acceptance Criteria |
| :--- | :--- | :---: | :--- | :--- |
| **FR-MED-001** | HLS (.m3u8) Stream Parser | **M** | Parses Master and Media HLS playlists; extracts video/audio variant streams, resolutions, and bitrates. | Lists available streams (e.g. 4K, 1080p, 720p, audio-only) in order of quality. |
| **FR-MED-002** | MPEG-DASH (.mpd) Stream Parser | **M** | Parses XML MPD manifests; handles SegmentTemplate, SegmentTimeline, and init segments. | Downloads matching video and audio representations concurrently. |
| **FR-MED-003** | Parallel TS/Fragment Fetching | **M** | Fetches video segments (.ts, .m4s) using worker pool with pipelined HTTP requests. | Saturates network bandwidth across dozens of short stream segments simultaneously. |
| **FR-MED-004** | AES-128 Stream Decryption | **M** | Automatically fetches decryption key from `#EXT-X-KEY` URI and decrypts segments on-the-fly. | Seamlessly decrypts standard HLS AES-128 protected media segments. |
| **FR-MED-005** | Embedded FFmpeg Lossless Remux | **M** | Bundled FFmpeg pipeline muxes separate audio and video streams into `.mp4` or `.mkv` using Windows Named Pipes without re-encoding. | Muxing completes in seconds using stream copy (`-c copy`), preserving exact original quality. |
| **FR-MED-006** | Audio Extraction Mode | **M** | User can choose to extract audio-only track directly into `.mp3` or `.m4a`. | Download saves audio track immediately upon stream completion. |
| **FR-MED-007** | DRM & EME Manifest Sniffing | **M** | Detects Widevine, FairPlay, and PlayReady DRM manifests (`cenc:pssh`, `SAMPLE-AES`, `urn:uuid:...`). | Informs user with a `[DRM Protected]` badge and explanation why encrypted streams cannot be captured. |

### 3.4 Browser Extension & System Integration (INT)

| ID | Title | Priority | Description | Acceptance Criteria |
| :--- | :--- | :---: | :--- | :--- |
| **FR-INT-001** | Manifest V3 Browser Extension | **M** | Official MV3 extension for Chrome, Edge, Brave, Vivaldi, Opera, Arc, and Firefox. | Intercepts download requests seamlessly without breaking browser security policies; handles SW lifecycles. |
| **FR-INT-002** | Native Messaging Host Protocol | **M** | Inter-process communication via standard I/O (stdin/stdout) using 32-bit JSON framing with Rust host. | Sub-millisecond IPC latency between browser extension and desktop application; panics isolated to stderr. |
| **FR-INT-003** | Floating In-Page Media Grabber | **M** | Floating button appears over HTML5 `<video>` / `<audio>` elements with instant quality dropdown. | Hovering video shows download widget; clicking item opens RDM download prompt with pre-filled details. |
| **FR-INT-004** | Clipboard Sniffing Daemon | **M** | Background listener detects URLs, magnet links, and file hashes copied to system clipboard. | RDM triggers non-intrusive floating quick-download pill or add dialog within 200ms of copy. |
| **FR-INT-005** | Browser Download Interception | **M** | Replaces default browser download manager based on customizable file extension rules. | Clicking `.iso`, `.zip`, `.exe` automatically routes transfer to RDM; bypasses with `Alt` key. |
| **FR-INT-006** | Batch Page Link Crawler | **S** | Browser extension / desktop tool scrapes all links, images, or media files on current web page. | Displays filterable grid of all discovered URLs with batch selection checkboxes. |
| **FR-INT-007** | Site Logins & Auth Manager | **M** | Manages credentials for Basic, Digest (RFC 7616), NTLM, and Bearer token protected sites. | Automatically injects credentials on HTTP 401/407 challenges; passwords stored in OS native vault. |
| **FR-INT-008** | Configurable File Types Mapping | **M** | User can add, modify, or remove file extensions associated with each download category. | Modifying extensions updates extension interception list and auto-categorization routes immediately. |

### 3.5 UI / UX & Visualization (UI)

| ID | Title | Priority | Description | Acceptance Criteria |
| :--- | :--- | :---: | :--- | :--- |
| **FR-UI-001** | Modern Fluent / HIG Desktop Window| **M** | Frameless window with custom titlebar, platform Mica/Acrylic/Vibrancy blur, and native window buttons. | Seamlessly matches Windows 11 Fluent and macOS Sonoma/Sequoia HIG aesthetic guidelines. |
| **FR-UI-002** | Real-Time Dynamic Segment Canvas | **M** | 60 FPS `CustomPainter` displaying active connection heads, downloaded byte ranges, and gaps. | Visualizes up to 64 active connections with smooth animated progress bars and byte markers. |
| **FR-UI-003** | Speed Sparklines & History Chart | **M** | Interactive 60-second historical throughput chart with peak speed, current speed, and ETA calculation. | Updates at 10Hz; displays human-readable units (KB/s, MB/s, GB/s) with tabular numbers. |
| **FR-UI-004** | Responsive Three-Pane Layout | **M** | Collapsible left navigation rail (Categories, Queues), center download table, right/bottom inspector. | Smoothly adapts from 800x600 compact window to multi-monitor 4K desktop layouts. |
| **FR-UI-005** | Categorization & Smart Filtering | **M** | Categorizes downloads into Compressed, Video, Audio, Documents, Programs, Torrents, and Custom. | Auto-filters table instantly upon clicking category node in navigation rail. |
| **FR-UI-006** | Full Keyboard Shortcuts & Focus | **M** | Complete keyboard navigation (`Ctrl+N` new, `Space` pause/resume, `Del` remove, `Ctrl+F` search). | WCAG 2.1 AA accessible with visible focus rings and screen-reader semantics. |
| **FR-UI-007** | System Tray & Floating Speed Pill | **S** | Minimizes to system tray; optional compact floating desktop widget showing aggregate speeds. | Tray menu provides quick pause-all, resume-all, speed throttle toggle, and exit. |
| **FR-UI-008** | Desktop Drop Target Basket | **M** | Semi-transparent floating desktop target allowing drag-and-drop of links, images, text, and torrent files. | Dropping any URL or link adds it immediately to active queue; window position is remembered. |
| **FR-UI-009** | Internationalization & i18n | **M** | Full multi-language localization architecture via Flutter `.arb` files and `flutter_localizations`. | User can switch UI language instantly (English, Indonesian, Spanish, French, German, Chinese, Japanese). |
| **FR-UI-010** | Audio Event Notifications | **S** | Plays customizable audio chimes for download completion, queue finish, and critical network failure. | User can toggle sound effects globally or choose custom sound files (.wav/.ogg). |

### 3.6 Queue, Scheduler & Storage (SCH)

| ID | Title | Priority | Description | Acceptance Criteria |
| :--- | :--- | :---: | :--- | :--- |
| **FR-SCH-001** | Multi-Queue Management | **M** | Create distinct queues (e.g. "Main Queue", "Night Queue") with custom concurrency and order. | Downloads in sequential queues process in exact priority sequence; parallel queues respect concurrency limit. |
| **FR-SCH-002** | Calendar & Recurring Scheduler | **M** | Schedule downloads to start/stop at specific times, daily recurring windows, or off-peak hours. | Downloads launch precisely at configured timestamp; pauses when stop window expires. |
| **FR-SCH-003** | Post-Download System Actions | **M** | Triggers system sleep, shutdown, hibernate, network disconnect, or custom command on completion. | Cleanly executes selected OS action when the entire queue finishes downloading. |
| **FR-SCH-004** | Dynamic Path & Token Renaming | **S** | Auto-saves files into structured folders using tokens: `{category}/{domain}/{YYYY-MM}/{filename}`. | Automatically evaluates tokens and creates necessary parent directories. |
| **FR-SCH-005** | Automated Archive Extraction | **S** | Automatically extracts `.zip`, `.rar`, `.7z` archives upon completion, with password list testing. | Unpacks files without user intervention; handles multi-volume split archives (`.part1.rar`). |
| **FR-SCH-006** | Checksum Verification Engine | **M** | Computes MD5, SHA-1, SHA-256, SHA-512, CRC32 hashes; compares automatically with clipboard. | Green checkmark badge displayed when file hash matches clipboard checksum. |
| **FR-SCH-007** | Network Dial-Up / VPN Auto-Hangup | **S** | Can initiate dial-up/VPN connection before queue start, and hang up/disconnect after queue completes. | Automatically manages WAN/VPN connections for metered or off-peak ISP packages. |

### 3.7 Security & Automation (SEC)

| ID | Title | Priority | Description | Acceptance Criteria |
| :--- | :--- | :---: | :--- | :--- |
| **FR-SEC-001** | OS Native Credential Vault | **M** | Stores site passwords and proxy credentials in Windows Credential Manager, macOS Keychain, Linux SecretService. | Zero plaintext passwords written to configuration files or SQLite databases. |
| **FR-SEC-002** | Automatic Antivirus Scanning | **M** | Automatically submits completed files to Windows Defender (via AMSI/CLI) or custom antivirus binary. | Alerts user and quarantines file if threat detected by system scanner. |
| **FR-SEC-003** | Path Traversal & Injection Defense| **M** | Sanitizes `Content-Disposition` filenames to prevent `../` directory escapes and illegal OS characters. | Strips path traversal sequences; limits filename length to OS MAX_PATH limits. |
| **FR-SEC-004** | User-Configurable Antivirus CLI | **M** | Allows user to customize external antivirus scanner executable and arguments (`"%FILE%"` token). | Executes user-defined antivirus binary and reports exit code before marking file safe. |

### 3.8 Command-Line & Headless Operations (CLI)

| ID | Title | Priority | Description | Acceptance Criteria |
| :--- | :--- | :---: | :--- | :--- |
| **FR-CLI-001** | Full CLI & Headless Daemon | **M** | Complete command-line interface (`rdm download`, `rdm queue`, `rdm daemon`) and JSON-RPC over local socket. | Fully controllable from terminal, automated shell scripts, NAS systems, and headless Linux servers. |

---

## 4. Non-Functional Requirements (NFR)

### 4.1 Performance & Throughput
- **NFR-PERF-001 (Line Rate Saturation)**: Must saturate 10Gbps Ethernet connections on NVMe SSD storage with CPU utilization < 8% across modern 8-core processors.
- **NFR-PERF-002 (CPU Efficiency)**: Average CPU consumption during 1Gbps download must remain < 2.0% on Windows 11 and macOS Apple Silicon.
- **NFR-PERF-003 (Memory Budget)**:
  - Idle state: < 40 MB Resident Set Size (RSS).
  - Active download (16 connections, 100MB/s): < 85 MB RSS.
  - Peak throughput (64 connections, 1GB/s): < 180 MB RSS.
- **NFR-PERF-004 (Disk I/O Latency & Assembly Stall)**: Post-download completion time must be < 10 milliseconds. Zero disk concatenation delay.

### 4.2 Reliability & Fault Tolerance
- **NFR-REL-001 (Crash Resilience)**: Must withstand abrupt process termination (`kill -9`, power outage, blue screen) without file corruption or loss of previously committed byte ranges.
- **NFR-REL-002 (Automatic Exponential Backoff)**: Failed connection attempts must back off exponentially (1s, 2s, 4s, 8s, up to 60s) with 20% randomized jitter to prevent server hammering.
- **NFR-REL-003 (Network Interface Roaming)**: If network interface changes (e.g. switching from Wi-Fi to Ethernet), active sockets must gracefully reconnect within 3 seconds without restarting tasks.

### 4.3 Platform Support & Environment
- **Windows**: Windows 10 (Build 19041+) and Windows 11; architectures: x86_64, ARM64.
- **macOS**: macOS 12 (Monterey) through macOS 15+ (Sequoia); architectures: Apple Silicon (M1/M2/M3/M4) and Intel x86_64.
- **Linux**: Kernel 5.15+ (glibc 2.31+); architectures: x86_64, aarch64; desktop environments: GNOME, KDE Plasma, XFCE.

---

## 5. Scope & Phased Implementation Plan

### Stage 1 (Current Scope)
- Complete technical PRD specifications (Modules 00 through 08).
- Rust download engine architecture with dynamic in-half segmentation, sparse file pre-allocation, positional writes, and token bucket limiter.
- Flutter MVVM architecture with FRB v2 zero-copy FFI bridge.
- Browser extension specification with Native Messaging Host protocol.
- SQLite persistence schema with WAL journal and resume bitmask.

### Stage 2 (Subsequent Scope)
- C++ / Rust FFI compilation and packaging.
- Flutter UI widget tree construction and custom canvas painters.
- Chrome Web Store and Firefox Add-ons store submissions.
- Code signing and platform installer distribution.
