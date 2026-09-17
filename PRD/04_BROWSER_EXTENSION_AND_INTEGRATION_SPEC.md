# RDM - Browser Extension & System Integration Specification

> **Document ID**: RDM-PRD-004  
> **Target Subsystems**: `rdm_extension` (Manifest V3), `rdm_native_host`, `rdm_clipboard`  
> **Status**: APPROVED FOR STAGE 1 ARCHITECTURE & IMPLEMENTATION  

---

## 1. Browser Integration Topology

RDM integrates with all major modern web browsers through an official **Manifest V3 WebExtension** communicating with a dedicated **Rust Native Messaging Host**.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       BROWSER RUNTIME (Manifest V3)                         │
│  - Chromium: Google Chrome, Microsoft Edge, Brave, Vivaldi, Opera, Arc     │
│  - Mozilla Firefox (WebExtension API)                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  1. Background Service Worker: Network Interception & Request Listener     │
│  2. Content Script: Floating Video Grabber Overlay (Shadow DOM)             │
│  3. Popup / Options UI: Extension Quick-Settings & Site Whitelists          │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                Native Messaging Protocol (stdin / stdout)
                Framed JSON: [4-Byte Length Header][UTF-8 JSON Payload]
                                       │
┌──────────────────────────────────────▼──────────────────────────────────────┐
│                    RUST NATIVE MESSAGING HOST BINARY                        │
│                           (`rdm_native_host`)                               │
│  - Stdin/Stdout Byte Framing Parser & Serializer                           │
│  - Local Domain Socket / Named Pipe Forwarder to RDM Desktop App            │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                      Local IPC (Named Pipe / Domain Socket)
                                       │
┌──────────────────────────────────────▼──────────────────────────────────────┐
│                           RDM DESKTOP APPLICATION                           │
│  - Prompts Add Download Dialog or Routes to Silent Queue                   │
│  - Ingests Cookies, User-Agent, Referer, and Authorization Headers          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Native Messaging Host Protocol Specification

### 2.1 Wire Format Framing
The Native Messaging protocol uses standard input (`stdin`) and standard output (`stdout`) to exchange messages between the browser extension and the native binary (`rdm_native_host`):
- Each message starts with a **4-byte unsigned 32-bit integer** in native byte order indicating the length of the subsequent payload in bytes.
- The payload is a **UTF-8 encoded JSON string**.
- Maximum message size: 1,048,576 bytes (1 MB).
- **CRITICAL IMPLEMENTATION RULE**: The native host executable MUST NEVER write logging, panic messages, or standard prints to `stdout`. Any byte written to `stdout` that does not conform to the 4-byte length prefix will corrupt the browser's IPC stream and crash the extension host. All logging must be routed to `stderr` or a rotating file logger.

### 2.2 Wire Framing Implementation & Stderr Isolation (Rust)
```rust
use std::io::{self, Read, Write};
use serde_json::Value;

/// Configures process-wide panic hooks and logging to strictly write to stderr.
/// Any unformatted write to stdout instantly kills the browser's Native Messaging port!
pub fn init_native_host_safeguards() {
    std::panic::set_hook(Box::new(|panic_info| {
        eprintln!("[RDM Native Host Fatal Panic]: {:?}", panic_info);
    }));
    tracing_subscriber::fmt()
        .with_writer(io::stderr)
        .init();
}

pub fn read_native_message<R: Read>(reader: &mut R) -> io::Result<Option<Value>> {
    let mut length_buf = [0u8; 4];
    match reader.read_exact(&mut length_buf) {
        Ok(_) => (),
        Err(e) if e.kind() == io::ErrorKind::UnexpectedEof => return Ok(None),
        Err(e) => return Err(e),
    }

    let length = u32::from_ne_bytes(length_buf) as usize;
    if length > 1_048_576 {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "Payload exceeds 1MB limit"));
    }

    let mut payload_buf = vec![0u8; length];
    reader.read_exact(&mut payload_buf)?;
    
    let json_val: Value = serde_json::from_slice(&payload_buf)?;
    Ok(Some(json_val))
}

pub fn write_native_message<W: Write>(writer: &mut W, msg: &Value) -> io::Result<()> {
    let payload = serde_json::to_vec(msg)?;
    let length = payload.len() as u32;
    
    writer.write_all(&length.to_ne_bytes())?;
    writer.write_all(&payload)?;
    writer.flush()?;
    Ok(())
}
```

### 2.3 Manifest V3 Service Worker Lifecycle & Keepalive
Under Chromium Manifest V3, background service workers terminate after 30 seconds of inactivity, which could abruptly sever active Native Messaging ports.

RDM addresses this with a resilient connection lifecycle:
1. **Demand-Driven Port Reconnect**: Rather than holding an idle port open forever, the service worker lazily connects via `chrome.runtime.connectNative('com.antigravity.rdm')` whenever an interception, stream detection, or URL refresh event occurs.
2. **Offscreen Document Keepalive (Chromium 109+)**: For long-duration batch link operations or streaming video grabber scans, the extension launches a minimal `offscreen.html` document with reason `WORKERS` or `CLIPBOARD` that maintains active communication until the batch transfer completes.
3. **Automatic Port Recovery**: If the Native Host process exits or restarts, the extension catches `port.onDisconnect` and queues pending messages in an indexed in-memory queue, retrying connection with exponential backoff.

### 2.4 JSON Message Schemas

#### 1. Download Intercept Request (`intercept_download`)
Sent by browser extension when a file download is triggered:
```json
{
  "action": "intercept_download",
  "data": {
    "url": "https://cdn.example.com/files/release-v2.iso",
    "filename": "release-v2.iso",
    "file_size": 2147483648,
    "mime_type": "application/x-iso9660-image",
    "referrer": "https://example.com/downloads",
    "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ...",
    "cookies": [
      { "name": "session_id", "value": "a9f8b2c4e1...", "domain": ".example.com" }
    ],
    "custom_headers": {
      "Authorization": "Bearer eyJhbGciOi...",
      "Accept-Language": "en-US,en;q=0.9"
    }
  }
}
```

#### 2. Media Stream Detected (`media_detected`)
Sent by content script / network sniffer when video streams are identified:
```json
{
  "action": "media_detected",
  "data": {
    "page_title": "Advanced Distributed Systems Lecture 04",
    "page_url": "https://university.edu/lectures/4",
    "stream_type": "HLS",
    "manifest_url": "https://cdn.university.edu/streams/lec4/master.m3u8",
    "variants": [
      { "resolution": "3840x2160", "bitrate": 18000000, "label": "4K Ultra HD" },
      { "resolution": "1920x1080", "bitrate": 5000000, "label": "1080p FHD" },
      { "resolution": "1280x720", "bitrate": 2500000, "label": "720p HD" }
    ],
    "audio_tracks": [
      { "language": "en", "label": "English Audio (Stereo)", "bitrate": 192000 }
    ],
    "drm_protected": false
  }
}
```

#### 3. Request URL Refresh (`request_url_refresh`)
Sent from Desktop RDM to Browser Extension when link expires (HTTP 403/410):
```json
{
  "action": "request_url_refresh",
  "data": {
    "task_id": "9f8a7b6c-...",
    "original_url": "https://drive.google.com/...",
    "referrer": "https://drive.google.com/file/d/123/view"
  }
}
```

#### 4. URL Refreshed Payload (`url_refreshed`)
Sent from Browser Extension back to Desktop RDM after capturing fresh link:
```json
{
  "action": "url_refreshed",
  "data": {
    "task_id": "9f8a7b6c-...",
    "new_url": "https://doc-0k-08-docs.googleusercontent.com/docs/securesc/...",
    "cookies": [
      { "name": "download_warning", "value": "1", "domain": "googleusercontent.com" }
    ],
    "custom_headers": {
      "User-Agent": "Mozilla/5.0 ...",
      "Referer": "https://drive.google.com/"
    }
  }
}
```

---

## 3. Network Sniffing & Download Interception Rules

### 3.1 Interception Triggers
The extension intercepts downloads through a two-pronged mechanism:
1. **Chrome Downloads API Hook**: Listens to `chrome.downloads.onCreated`. When a download initiates, the extension pauses it immediately, inspects the URL, MIME type, and headers, and queries RDM. If RDM takes over, the browser download is cancelled (`chrome.downloads.cancel`), avoiding duplicate downloads.
2. **declarativeNetRequest & webRequest Listener**: Pre-screens HTTP response headers for:
   - `Content-Disposition: attachment; ...`
   - Target MIME types: `application/zip`, `application/x-rar-compressed`, `application/x-7z-compressed`, `application/octet-stream`, `application/x-iso9660-image`, `video/*`, `audio/*`.
   - Target file extensions: `.zip`, `.rar`, `.7z`, `.tar.gz`, `.iso`, `.exe`, `.msi`, `.dmg`, `.pkg`, `.deb`, `.rpm`, `.bin`, `.apk`, `.mp4`, `.mkv`, `.flac`.

### 3.2 User Exclusion & Hotkey Override
- **Bypass Hotkey (`Alt` key)**: Holding the `Alt` key while clicking a download link forces the browser to handle the download natively, bypassing RDM.
- **Site Whitelist / Blacklist**: Users can configure domains where RDM will never automatically intercept (e.g. internal company intranets or banking portals).
- **Extension Blacklist**: Specific extensions can be excluded from interception (e.g., `.pdf` or `.docx` for direct in-browser viewing).

### 3.3 Browser Context Menu Integration
The extension registers rich right-click context menu options via `chrome.contextMenus`:
1. **Link Context**: `"Download with RDM"` — routes clicked link URL, referer, and page cookies directly to RDM.
2. **Media Context (Video / Audio / Image)**: `"Download Media with RDM"` — downloads the media source file directly.
3. **Selection Context**: If user highlights text containing a URL or Magnet URI: `"Download selection with RDM"`.
4. **Page Background Context**: `"Download All Links on Page with RDM"` — triggers the Batch Link Crawler.

---

## 4. In-Page Floating Video/Audio Grabber Overlay

To replicate and enhance IDM's most popular feature, RDM injects a lightweight, isolated **Shadow DOM overlay** over detected media elements:

```
┌─────────────────────────────────────────────────────────────┐
│  HTML5 <video> Player                                       │
│                                                             │
│   ┌──────────────────────────────────────────────────────┐  │
│   │ [▼ Download this video with RDM]                     │  │
│   ├──────────────────────────────────────────────────────┤  │
│   │  • 4K Ultra HD (3840x2160, 60fps) - MP4 (2.4 GB)     │  │
│   │  • 1080p Full HD (1920x1080) - MP4 (680 MB)         │  │
│   │  • 720p HD (1280x720) - MP4 (320 MB)                │  │
│   │  • Audio Only (MP3 / 320 kbps)                      │  │
│   │  • Subtitles: English (.srt), Spanish (.srt)         │  │
│   └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 4.1 Technical Architecture of the Grabber
- **Shadow DOM Isolation**: The widget is mounted inside an `open` Shadow Root (`#shadow-root`). Web page CSS stylesheets and scripts cannot alter, hide, or corrupt the grabber widget's styling.
- **Dynamic Positioning**: Uses `ResizeObserver` and `IntersectionObserver` attached to all `<video>` and `<audio>` DOM nodes to anchor the button in the top-right corner of the video viewport with optical padding.
- **Sniffing Subsystem**:
  - Monitors `HTMLVideoElement.src` and `<source src="...">`.
  - Intercepts `fetch` and `XMLHttpRequest` calls for `.m3u8` and `.mpd` URLs executed by player scripts (Video.js, Hls.js, Shaka Player, Dash.js).
- **Instant Dispatch**: Clicking any resolution sends the manifest URL, resolution choice, audio track selection, referer, and cookies to the RDM desktop client via the Native Host.

---

## 5. System Clipboard Monitor Daemon

RDM features an independent background clipboard daemon built into the core desktop application using the cross-platform Rust crate `arboard`:

### 5.1 Architecture & Detection Heuristics
- **Polling Loop**: Checks clipboard string updates every 400ms with minimal CPU consumption (< 0.1%).
- **Regex Classification Engine**:
  ```text
  Direct File URL: ^https?:\/\/.*?\.(zip|rar|7z|iso|exe|msi|dmg|mp4|mkv|tar\.gz)(\?.*)?$
  Magnet Link:     ^magnet:\?xt=urn:btih:[a-zA-Z0-9]{32,40}.*$
  Torrent URL:     ^https?:\/\/.*?\.torrent(\?.*)?$
  Streaming URL:   ^https?:\/\/.*?\.(m3u8|mpd)(\?.*)?$
  Checksum Hash:   ^[a-fA-F0-9]{32}$|^[a-fA-F0-9]{64}$
  ```
- **Action Triggers**:
  - **Quick Download Pill**: Displays a compact, semi-transparent floating pill near the mouse cursor: `"Download [filename.iso] (4.2 GB)?"` with `[Start]` and `[Options]` buttons.
  - **Checksum Auto-Match**: If a 32-character (MD5) or 64-character (SHA-256) hash is copied while a download is completing, RDM automatically assigns it to the target task and runs verification immediately upon completion.
  - **Silent Mode Option**: Allows users to configure clipboard sniffing to automatically add links directly to the "Default Queue" without popping up any UI dialogs.

---

## 6. Batch Link Crawler & Site Grabber

### 6.1 Browser Extension Page Link Scraper
Users can right-click any web page and choose **"Download All Links with RDM"**:
1. Content script traverses DOM:
   - Scrapes all `<a href="...">`, `<img src="...">`, `<video src="...">`, and `iframe` media embeds.
   - Extracts link text, anchor descriptions, and file extensions.
2. Deduplicates URLs and resolves relative links to absolute URIs.
3. Opens RDM's **Batch Import Modal**, providing:
   - File type filter checkboxes: `[x] Videos  [x] Archives  [ ] Images  [ ] Documents`.
   - Wildcard / Regex filename filters: (e.g. `*Chapter*.mp4` or `release_*.zip`).
   - Destination directory and queue selection.
   - Batch download queueing with a single click.
