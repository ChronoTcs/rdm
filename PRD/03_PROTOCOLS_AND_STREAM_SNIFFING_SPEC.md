# RDM - Protocols & Stream Sniffing Specification

> **Document ID**: RDM-PRD-003  
> **Target Subsystems**: `rdm_protocols`, `rdm_media_sniffer`, `rdm_ffmpeg`  
> **Status**: APPROVED FOR STAGE 1 ARCHITECTURE & IMPLEMENTATION  

---

## 1. Multi-Protocol Engine Architecture

RDM provides native protocol drivers capable of multi-threaded segmentation across heterogeneous network sources. All protocol drivers expose a unified `ByteStreamReader` and `RangeStreamRequester` trait to the engine's Segment Manager.

```
                         ┌─────────────────────────────┐
                         │   UNIFIED STREAM TRAIT      │
                         │   - probe_metadata()        │
                         │   - fetch_range(start, end) │
                         │   - stream_chunks()         │
                         └──────────────┬──────────────┘
                                        │
      ┌──────────────────┬──────────────┴─────┬──────────────────┐
      ▼                  ▼                    ▼                  ▼
┌───────────┐      ┌───────────┐        ┌───────────┐      ┌───────────┐
│ HTTP / 3  │      │ FTP/FTPS  │        │BitTorrent │      │ Adaptive  │
│ H2 / H1.1 │      │ Engine    │        │ Engine    │      │ Media     │
│ (`reqwest`│      │ (`suppaftp`│       │ (`rqbit`  │      │ (HLS/DASH)│
│  + `h3`)  │      │  + TLS)   │        │  + DHT)   │      │ + FFmpeg  │
└───────────┘      └───────────┘        └───────────┘      └───────────┘
```

---

## 2. HTTP / HTTPS / HTTP/3 (QUIC) Protocol Driver

### 2.1 Range Verification & Metadata Probing
When a URL is submitted, RDM executes an initial lightweight probe:
1. Sends an HTTP `HEAD` request with standard browser headers (`User-Agent`, `Accept`, `Referer`, and cookies).
2. If `HEAD` returns `405 Method Not Allowed` or drops connection, falls back immediately to `GET` with header `Range: bytes=0-0`.
3. Inspects response headers:
   - `Accept-Ranges: bytes` or `Content-Range: bytes 0-0/total_size`: Confirms multi-threaded segmentability.
   - `Content-Length`: Total size in bytes.
   - `ETag` and `Last-Modified`: Unique identifiers for cache and resume validation.
   - `Content-Disposition`: Extracts canonical server-suggested filename (e.g. `filename="archive_v2.iso"`).
4. If the server does not support byte ranges, RDM warns the user in the Add Download dialog and configures the task for single-connection streaming.

### 2.2 Connection Pooling & Keep-Alive Re-use
- **HTTP/1.1**: Maintains persistent TCP connections (`Connection: keep-alive`). When a worker finishes segment $[s_i, e_i]$, the open socket is not closed; it immediately sends the next segment request header over the same pipeline, avoiding TCP 3-way handshakes and TLS round-trips.
- **HTTP/2**: Multiplexes concurrent segment requests over a single negotiated TLS connection using distinct HTTP/2 stream IDs, reducing socket descriptor consumption.
- **HTTP/3 (QUIC)**: Runs over UDP. Eliminates TCP head-of-line blocking: packet loss on segment A does not delay or stall packets arriving for segment B. Automatically switches to QUIC whenever the server announces `alt-svc: h3=":443"`.

### 2.3 HTTP 401/407 Challenge-Response & Authentication Handshake
When enterprise networks, private CDNs, or premium file lockers require authentication:
1. **Challenge Detection**: If the probe or segment request returns `401 Unauthorized` or `407 Proxy Authentication Required`:
   - Inspects `WWW-Authenticate` / `Proxy-Authenticate` headers for schemes: `Basic realm="..."`, `Digest realm="...", nonce="..."`, or `NTLM` / `Negotiate`.
2. **Vault Lookup**: Queries the domain in the `site_rules` database table and retrieves associated credentials from the OS native vault (Windows Credential Manager / Keychain / Secret Service).
3. **Automated Response Injection**:
   - **Basic**: Formats `Authorization: Basic base64(user:pass)`.
   - **Digest (RFC 7616)**: Calculates MD5/SHA-256 hash response over `realm`, `nonce`, `nc`, `cnonce`, `qop="auth"`, and requested URI.
   - **Bearer Token**: Injects `Authorization: Bearer <token>` captured from the browser extension's session.
4. **Interactive Prompt Fallback**: If no matching vault credentials exist, pauses the task and pops an authentication modal in Flutter, prompting the user for username/password with a `[x] Remember credentials for this domain` checkbox.

---

## 3. FTP / FTPS Protocol Driver

RDM includes a high-performance FTP client engine compliant with RFC 959, RFC 2228 (FTPS), and RFC 3659 (`REST` stream mode):

### 3.1 Capabilities & Architecture
- **Encryption**: FTPS (FTP over explicit TLS) utilizing `rustls`. Negotiates secure control and data channels (`PROT P`).
- **Data Transfer Modes**: Supports Passive Mode (`PASV`) and Extended Passive Mode (`EPSV` for IPv6 compliance) to bypass NAT firewalls.
- **Segmented Range Downloads**: Utilizes the FTP `REST <byte-offset>` command. To download segment $[s_i, e_i]$:
  1. Opens control connection, authenticates credentials.
  2. Sends `TYPE I` (Binary image mode).
  3. Sends `REST <s_i>` to position the file pointer.
  4. Sends `RETR <filename>` and reads $e_i - s_i + 1$ bytes from the opened passive data socket.
  5. Closes data connection cleanly and marks interval complete.
- **Directory Recursion**: Implements `MLSD` / `LIST` parser to allow downloading entire FTP folder trees recursively with automatic local directory generation.

---

## 4. BitTorrent Protocol Driver

RDM integrates an embedded BitTorrent engine based on modern, memory-safe Rust primitives (`rqbit`), turning RDM into a unified download center:

### 4.1 Specification & Standards Compliance
- **Core BitTorrent**: BEP 3 (The BitTorrent Protocol), BEP 10 (Extension Protocol), BEP 20 (Peer ID conventions).
- **Transport**: uTP (Micro Transport Protocol / BEP 29) running over UDP with LEDBAT congestion control, alongside standard TCP peers.
- **Peer Discovery**:
  - Mainline DHT (Kademlia Distributed Hash Table / BEP 5) for trackerless torrents.
  - Peer Exchange (PEX / BEP 11).
  - Tracker Protocols: HTTP, HTTPS, and UDP trackers (BEP 15).
- **Magnet Link Parser**: Parses `magnet:?xt=urn:btih:...` URIs, extracts display names (`dn`), trackers (`tr`), and fetches torrent metadata (.torrent dictionary) directly from the DHT swarm via BEP 9 (Metadata Exchange).

### 4.2 Multi-File Tree Selection & Sequential Mode
- **File Hierarchy Explorer**: Parses the `info.files` dictionary into a reactive tree view in Flutter. Users can check/uncheck individual files and assign priority flags (High, Normal, Skip).
- **Sequential Download Mode**: Prioritizes the earliest pieces of a video or audio file first, allowing users to preview and stream media files directly while the remainder downloads in the background.

---

## 5. Media Sniffing & Adaptive Streaming Grabber

Adaptive bitrate streaming divides video and audio into thousands of small encrypted fragments (1 to 6 seconds each). Traditional download managers fail because standard file download logic cannot parse dynamic playlists or manifests.

RDM features dedicated parsers for **HLS** and **MPEG-DASH**, coupled with an **Embedded FFmpeg Remuxer**.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ADAPTIVE STREAM GRABBER PIPELINE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. Manifest Discovery (Browser Extension Sniffer / Injected Video Grabber)  │
│    - URL: `https://example.com/stream/master.m3u8` or `manifest.mpd`        │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. Manifest Parser & Track Selection                                        │
│    - Extracts Resolutions (4K, 1080p, 720p), Bitrates, Codecs (H.264/HEVC)  │
│    - Extracts Audio Tracks (English AAC, Spanish AC3, etc.)                 │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3. Parallel Fragment Fetcher & Decryptor (Tokio Worker Pool)                │
│    - Concurrently downloads video chunks (`seg-1.ts`, `seg-2.ts`, ...)     │
│    - Concurrently downloads audio chunks (`audio-1.m4s`, ...)              │
│    - AES-128-CBC Decryption on-the-fly (fetches key from #EXT-X-KEY URI)   │
├─────────────────────────────────────────────────────────────────────────────┤
│ 4. Embedded FFmpeg Lossless Remuxing (Zero-Re-encode)                       │
│    `ffmpeg -i video_pipe -i audio_pipe -c copy -movflags faststart out.mp4` │
│    - Generates pristine, container-synced MP4 or MKV in < 5 seconds         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.1 HLS (HTTP Live Streaming - RFC 8216) Engine
- **Master Playlist Parser**: Parses `#EXT-X-STREAM-INF` tags; extracts `BANDWIDTH`, `RESOLUTION`, `FRAME-RATE`, `CODECS`, and audio grouping tags (`#EXT-X-MEDIA:TYPE=AUDIO`).
- **Media Playlist Parser**:
  - Handles `#EXT-X-TARGETDURATION`, `#EXT-X-MEDIA-SEQUENCE`, `#EXTINF`.
  - Supports `#EXT-X-BYTERANGE` sub-segment slicing within unified `.ts` or `.mp4` chunks.
  - Detects stream end tag `#EXT-X-ENDLIST` (identifies VoD vs live streams).
- **AES-128 Decryption Pipeline**:
  - Parses `#EXT-X-KEY:METHOD=AES-128,URI="https://...",IV=0x...`
  - Fetches decryption key with the same session cookies and headers.
  - If initialization vector (`IV`) is omitted, generates the 128-bit IV from the media sequence number formatted as a big-endian 16-byte integer.
  - Decrypts chunk payloads in memory using `aes` / `cbc` Rust crates before writing to the pipe.

### 5.2 MPEG-DASH (ISO/IEC 23009-1) Engine
- **XML MPD Parser**:
  - Parses `<Period>`, `<AdaptationSet>`, and `<Representation>` nodes.
  - Identifies distinct representations for video (e.g. `mimeType="video/mp4"`, `width="1920"`, `height="1080"`) and audio (e.g. `mimeType="audio/mp4"`, `bandwidth="128000"`).
- **Fragment Address Resolver**:
  - **SegmentList**: Explicit array of fragment URLs.
  - **SegmentTemplate**: Dynamically calculates segment URLs replacing variables `$Number$`, `$Time$`, and `$RepresentationID$`.
  - **SegmentTimeline**: Handles variable duration segments (`<S t="..." d="..." r="..."/>`).
  - Downloads initialization chunks (`<Initialization sourceURL="..."/>`) and prepends them to the fragment streams.

### 5.3 Embedded FFmpeg Lossless Remuxing Pipeline (Cross-Platform)
When separate video and audio streams are captured (standard in all 1080p/4K YouTube, Vimeo, and DASH streams), RDM merges them seamlessly without re-encoding:

#### Platform IPC Strategy
On Windows, standard processes do NOT support POSIX numbered pipes (`pipe:3`, `pipe:4`). Attempting to use them causes `No such file or directory` aborts. RDM implements a native multi-platform pipeline:

1. **Windows (Win32 Named Pipes)**:
   - RDM creates two local Windows Named Pipes via Win32 `CreateNamedPipeW`:
     - Video Pipe: `\\.\pipe\rdm_v_{task_id}`
     - Audio Pipe: `\\.\pipe\rdm_a_{task_id}`
   - Workers stream decrypted chunks into the pipe buffer rings asynchronously.
   - FFmpeg is executed with:
     ```powershell
     ffmpeg.exe -y -i "\\.\pipe\rdm_v_{task_id}" -i "\\.\pipe\rdm_a_{task_id}" -c copy -movflags +faststart "output.mp4"
     ```
2. **macOS / Linux (POSIX FIFOs or Anonymous Pipes)**:
   - Utilizes `nix::unistd::pipe()` or named FIFOs in `/tmp/rdm_{task_id}` passed to FFmpeg's standard input descriptors.
3. **Staging File Fallback**:
   - If pipe buffer throughput starves or named pipe creation is restricted by OS group policies, RDM streams segments to two temporary files (`.v.tmp`, `.a.tmp`) and executes single-pass file remuxing at NVMe SSD speeds (typically 1.5–3.0 GB/s, taking ~2 seconds).
4. **`-movflags +faststart`**: Relocates the MP4 `moov` atom (metadata index) from the end of the file to the beginning, allowing instant seeking and streaming in desktop media players.
5. **Audio Extraction Feature**: If the user selects "Audio Only", RDM completely discards video stream chunks and writes the extracted audio stream directly into an `.m4a` (AAC) or `.mp3` container.

### 5.4 DRM & Encrypted Media Extensions (EME) Manifest Sniffing
A frequent source of corrupted downloads in inferior tools is downloading DRM-encrypted content. When encrypted with Widevine, FairPlay, or PlayReady, downloading fragments results in scrambled, unplayable video tracks.

RDM enforces proactive **DRM Manifest Sniffing**:
1. **HLS DRM Signatures**:
   - Detects `#EXT-X-KEY:METHOD=SAMPLE-AES`
   - Detects `KEYFORMAT="com.apple.streamingkeydelivery"` (Apple FairPlay)
   - Detects `KEYFORMAT="urn:uuid:edef8ba9-79d6-4ace-a3c8-27dcd51d21ed"` (Google Widevine)
2. **MPEG-DASH DRM Signatures**:
   - Scans `<AdaptationSet>` and `<ContentProtection>` XML nodes for:
     - `schemeIdUri="urn:uuid:edef8ba9-79d6-4ace-a3c8-27dcd51d21ed"` (Widevine Modular)
     - `schemeIdUri="urn:uuid:9a04f079-9840-4286-ab92-e65be0885f95"` (Microsoft PlayReady)
     - `cenc:default_KID` and `<cenc:pssh>` (Protection System Specific Header) binary payloads.
3. **Engine Action & User Warning**:
   - When DRM tags are encountered, RDM flags the media entry in the browser extension and desktop client with a prominent **`[DRM Protected]`** warning badge.
   - The UI disables automatic multi-segment remuxing and displays a helpful modal:
     > *"This video stream is protected by hardware DRM encryption (Widevine/FairPlay). Due to cryptographic key restrictions, it cannot be downloaded into a standard video container."*
   - This prevents failed tasks, wasted bandwidth, and corrupt local files.

---

## 6. Multi-Source / Mirror Acceleration

For high-demand open-source ISOs and mirrors (e.g., Linux distributions, game patches):
1. RDM allows the user to specify a list of mirror URLs for the same target file.
2. During the download, the dynamic segment manager assigns distinct byte ranges to different mirror servers simultaneously.
3. If Mirror A is throttled at 2 MB/s and Mirror B has 20 MB/s capacity, the work-stealing algorithm naturally routes 90% of the byte ranges to Mirror B while continuing to pull the remaining 10% from Mirror A.
4. All fetched segments are written to the single pre-allocated sparse target file and checksum-validated upon completion.
