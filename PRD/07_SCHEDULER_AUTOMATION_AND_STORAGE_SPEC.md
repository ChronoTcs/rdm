# RDM - Scheduler, Automation & Storage Specification

> **Document ID**: RDM-PRD-007  
> **Target Subsystems**: `rdm_scheduler`, `rdm_storage`, `rdm_extractor`  
> **Status**: APPROVED FOR STAGE 1 ARCHITECTURE & IMPLEMENTATION  

---

## 1. Multi-Queue Management Engine

RDM provides an enterprise-grade multi-queue scheduler capable of managing hundreds of downloads across concurrent and sequential execution queues.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       SCHEDULER ORCHESTRATOR (Rust)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│  Queue 1: "Main Queue"        │ Mode: Concurrent (Max 4 active tasks)       │
│  Queue 2: "Night Shift"       │ Mode: Sequential (1 active task at a time)  │
│  Queue 3: "Torrents Swarm"    │ Mode: Concurrent (Max 2 active torrents)    │
└──────────────────────┬──────────────────────────────────────────────────────┘
                       │ Checks triggers: Time of Day, Cron, Completion Event
                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         POST-COMPLETION AUTOMATION                          │
│  - System Power: Sleep / Shutdown / Hibernate                               │
│  - Archive Extractor: Auto-unrar / 7z with password vault                   │
│  - Notification / Webhook: Discord, Telegram, or Shell Script               │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Queue Execution Modes
- **Sequential Queue**: Downloads tasks strictly one-by-one in explicit priority order. When Task 1 reaches 100%, Task 2 launches automatically. Ideal for limited bandwidth connections or rapid sequential viewing.
- **Concurrent Queue**: Executes up to $K$ tasks simultaneously (where $K \in [1, 16]$ is user-configured). When one task finishes, the next queued item takes its slot immediately.
- **Dynamic Queue Reordering**: Users can drag-and-drop rows in the Flutter UI or use keyboard shortcuts (`Alt+Up`, `Alt+Down`) to reorder tasks in real-time.

---

## 2. Advanced Time & Event-Based Scheduler

### 2.1 Scheduler Triggers & Cron Rules
- **Time Window Scheduler**: Start downloads at a designated time (e.g. 01:00 AM) and stop downloads at another designated time (e.g. 06:30 AM).
- **Periodic / Recurring Schedules**: Daily, weekdays only, weekends only, or custom days of the week.
- **Scheduled Bandwidth Throttling**:
  - Automatically throttle total speeds to 2 MB/s during work hours (08:00 to 18:00).
  - Uncap download speeds to 100% line rate during off-peak night hours (18:00 to 08:00).

### 2.2 Post-Completion System Actions
When an entire queue finishes all pending downloads, RDM can execute one or more configured post-actions:

```rust
pub enum PostCompletionAction {
    DoNothing,
    SleepSystem,
    ShutdownSystem { force: bool },
    HibernateSystem,
    DisconnectNetwork,
    HangUpDialUpOrVpn { connection_name: Option<String> },
    ExecuteScript { script_path: String, args: Vec<String> },
    TriggerWebhook { endpoint: String, auth_token: Option<String> },
}
```

#### Platform Power & Network Primitives
- **Windows**:
  - Sleep: `SetSuspendState(FALSE, FALSE, FALSE)`
  - Shutdown: `InitiateSystemShutdownExW(..., SHTDN_REASON_MAJOR_APPLICATION, ...)`
  - VPN/Dial-up Hangup: `rasapi32::RasHangUpW` or `rasdial "Connection" /DISCONNECT`
- **macOS**:
  - Sleep: Executes `pmset sleepnow` via secure process invocation.
  - Shutdown: Uses AppleScript via `osascript -e 'tell application "System Events" to shut down'` to permit graceful application closure.
  - VPN Hangup: `scutil --nc stop "VPN Name"`
- **Linux**:
  - Sleep: DBus call to `org.freedesktop.login1.Manager.Suspend`.
  - Shutdown: DBus call to `org.freedesktop.login1.Manager.PowerOff`.
  - VPN Hangup: `nmcli connection down id "VPN Name"`

---

## 3. Local Persistence & SQLite Database Schema

All task states, downloaded extents, credentials, and configurations are persisted in an embedded SQLite database using **Write-Ahead Logging (WAL)**.

### 3.1 SQLite Performance Configuration
```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;
PRAGMA cache_size = -64000; -- 64MB memory cache
```

### 3.2 Relational Schema Definitions

```sql
-- 1. Download Queues
CREATE TABLE IF NOT EXISTS download_queues (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    execution_mode TEXT CHECK(execution_mode IN ('sequential', 'concurrent')) NOT NULL DEFAULT 'concurrent',
    max_concurrent_tasks INTEGER NOT NULL DEFAULT 3,
    bandwidth_limit_bps INTEGER NOT NULL DEFAULT 0,
    schedule_start_time TEXT, -- HH:MM:SS
    schedule_stop_time TEXT,  -- HH:MM:SS
    recurring_days INTEGER NOT NULL DEFAULT 127, -- 7-bit bitmask (Mon-Sun)
    post_action TEXT NOT NULL DEFAULT 'DoNothing',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Download Tasks (Full Session & Header Persistence for 100% Resume Fidelity)
CREATE TABLE IF NOT EXISTS download_tasks (
    id TEXT PRIMARY KEY,
    queue_id TEXT NOT NULL REFERENCES download_queues(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    http_method TEXT NOT NULL DEFAULT 'GET',
    post_data BLOB,
    canonical_filename TEXT NOT NULL,
    target_directory TEXT NOT NULL,
    total_bytes INTEGER NOT NULL DEFAULT 0, -- -1 indicates indeterminate / chunked stream
    downloaded_bytes INTEGER NOT NULL DEFAULT 0,
    status TEXT CHECK(status IN ('queued', 'downloading', 'paused', 'completed', 'error', 'expired_link')) NOT NULL DEFAULT 'queued',
    category TEXT NOT NULL DEFAULT 'general',
    etag TEXT,
    last_modified TEXT,
    user_agent TEXT,
    referer TEXT,
    cookies_json TEXT, -- JSON array of cookies [{name, value, domain, path}]
    custom_headers_json TEXT, -- JSON map of extra request headers
    sha256_hash TEXT,
    concurrency_limit INTEGER NOT NULL DEFAULT 16,
    priority INTEGER NOT NULL DEFAULT 0,
    is_chunked INTEGER NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME
);

-- 3. Segment Byte Extents (for Resumption & Visualizer)
CREATE TABLE IF NOT EXISTS task_segments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL REFERENCES download_tasks(id) ON DELETE CASCADE,
    segment_index INTEGER NOT NULL,
    start_offset INTEGER NOT NULL,
    current_offset INTEGER NOT NULL,
    end_offset INTEGER NOT NULL,
    status TEXT CHECK(status IN ('allocated', 'active', 'finished')) NOT NULL DEFAULT 'allocated',
    UNIQUE(task_id, segment_index)
);

-- 4. Multi-Source Mirrors
CREATE TABLE IF NOT EXISTS task_mirrors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL REFERENCES download_tasks(id) ON DELETE CASCADE,
    mirror_url TEXT NOT NULL,
    status TEXT CHECK(status IN ('active', 'throttled', 'offline')) NOT NULL DEFAULT 'active',
    speed_bps INTEGER NOT NULL DEFAULT 0,
    error_count INTEGER NOT NULL DEFAULT 0,
    UNIQUE(task_id, mirror_url)
);

-- 5. Site Credentials & Per-Domain Rules
CREATE TABLE IF NOT EXISTS site_rules (
    domain TEXT PRIMARY KEY,
    auth_scheme TEXT NOT NULL DEFAULT 'Basic', -- Basic, Digest, Bearer, NTLM
    username TEXT,
    credential_vault_key TEXT, -- Reference ID to OS Native Vault (DPAPI/Keychain)
    max_connections INTEGER NOT NULL DEFAULT 8,
    custom_user_agent TEXT,
    proxy_url TEXT
);

-- 6. Category Extensions Configuration
CREATE TABLE IF NOT EXISTS category_extensions (
    category TEXT NOT NULL,
    extension TEXT NOT NULL,
    PRIMARY KEY(category, extension)
);
```

---

## 4. File Organization & Dynamic Path Templating

### 4.1 Automatic Categorization Engine
Incoming downloads are mapped to destination directories based on extension and MIME type rules:

| Category | File Extensions | Default Destination |
| :--- | :--- | :--- |
| **Compressed** | `.zip`, `.rar`, `.7z`, `.tar`, `.gz`, `.bz2`, `.xz`, `.iso`, `.dmg` | `~/Downloads/RDM/Compressed` |
| **Video** | `.mp4`, `.mkv`, `.avi`, `.mov`, `.webm`, `.flv`, `.ts`, `.m4v` | `~/Downloads/RDM/Video` |
| **Music / Audio** | `.mp3`, `.flac`, `.aac`, `.wav`, `.m4a`, `.ogg`, `.opus` | `~/Downloads/RDM/Music` |
| **Documents** | `.pdf`, `.epub`, `.mobi`, `.docx`, `.xlsx`, `.pptx`, `.txt` | `~/Downloads/RDM/Documents` |
| **Programs** | `.exe`, `.msi`, `.apk`, `.deb`, `.rpm`, `.appimage`, `.pkg` | `~/Downloads/RDM/Programs` |
| **Torrents** | `.torrent` (and completed torrent payload directories) | `~/Downloads/RDM/Torrents` |

### 4.2 Dynamic Token Path Templating
Users can define custom path templates in Settings:
```text
Default Template: {downloads}/RDM/{category}/{domain}/{YYYY-MM}/{filename}
Example Evaluation:
  URL: https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.10.tar.xz
  Output: C:/Users/User/Downloads/RDM/Compressed/kernel.org/2026-09/linux-6.10.tar.xz
```
Tokens available:
- `{downloads}`: OS user downloads folder.
- `{category}`: Resolved file category.
- `{domain}`: Host domain of download URL.
- `{YYYY}`, `{MM}`, `{DD}`: Current year, month, day.
- `{filename}`: Sanitized file name.
- `{resolution}`: Video resolution (e.g. `1080p`) for captured streams.

---

## 5. Automated Archive Extraction Engine

Upon completion of any compressed archive, RDM can automatically unpack its contents in the background:

### 5.1 Extraction Capabilities
- **Supported Formats**: `.zip`, `.rar` (including RAR5), `.7z`, `.tar.gz`, `.tar.xz`.
- **Multi-Part Archives**: Automatically detects split volumes (`.part01.rar`, `.z01`, `.7z.001`) and initiates extraction only after all constituent parts have completed downloading.
- **Smart Password Vault**:
  - Maintains a local encrypted list of user-provided archive passwords.
  - When an encrypted archive is encountered, RDM attempts passwords in order of frequency until the archive header validates, extracting the payload without prompting the user.
- **Integrity Verification**: Extracts to a `.staging_extract` folder first; renames upon 100% successful extraction to prevent incomplete folders on disk.
