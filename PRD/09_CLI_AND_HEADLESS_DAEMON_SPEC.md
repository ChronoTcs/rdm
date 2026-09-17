# RDM - Command-Line Interface (CLI) & Headless Daemon Specification

> **Document ID**: RDM-PRD-009  
> **Target Subsystem**: `rdm_cli`, `rdm_daemon`  
> **Status**: APPROVED FOR STAGE 1 ARCHITECTURE & IMPLEMENTATION  

---

## 1. CLI Architectural Overview

While RDM delivers a state-of-the-art Flutter desktop user interface, it is architected with complete separation of concerns. The core engine (`rdm_engine`) can be compiled as a standalone CLI executable (`rdm`) or run as a background headless daemon (`rdmd`).

This delivers a decisive competitive advantage over IDM (which cannot run on headless Linux servers or inside Docker containers):
1. **Desktop Companion CLI**: Control running RDM desktop instances directly from PowerShell, Bash, or Zsh.
2. **Headless Daemon**: Deploy RDM on headless home servers, NAS devices (TrueNAS, Synology, Unraid), and cloud VPS instances with JSON-RPC controls.
3. **Shell Script Integration**: Easily script automated batch downloads, night sync jobs, and CI/CD asset retrieval.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             COMMAND LINE INTERFACE                          │
│   $ rdm download https://cdn.kernel.org/v6.x/linux-6.10.tar.xz --start       │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ Local IPC (Named Pipe / Domain Socket)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                   RDM ENGINE DAEMON / ACTIVE DESKTOP APP                    │
│  - JSON-RPC 2.0 Handler                                                     │
│  - Dynamic Segmentation Worker Pool                                         │
│  - SQLite WAL Journal Persistence                                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Command Line Interface (CLI) Syntax & Flags

The CLI uses the `clap` crate (v4.5+, derive API) for fast, memory-safe argument parsing with automatic shell completion generation (Bash, Zsh, Fish, PowerShell).

### 2.1 Core Commands

#### 1. Add / Download (`rdm download` or `rdm add`)
```text
Usage: rdm download [OPTIONS] <URL>

Arguments:
  <URL>  Target download URI (HTTP/1.1, HTTP/2, HTTP/3, FTP, or Magnet URI)

Options:
  -d, --dir <DIR>             Target destination directory [default: user Downloads]
  -f, --filename <NAME>       Override destination filename
  -c, --concurrency <N>       Number of concurrent segment connections (1-64) [default: 16]
  -q, --queue <QUEUE_NAME>    Assign task to specific queue [default: Main Queue]
  -l, --limit <BPS>           Download speed limit in bytes/sec (or e.g. 5M, 500K)
  -s, --start                 Start downloading immediately without queuing
      --header <K:V>          Add custom request header (can be repeated)
      --cookie <NAME=VAL>     Add cookie string (can be repeated)
      --user-agent <UA>       Override User-Agent string
      --quiet                 Suppress interactive progress bar (script mode)
      --json                  Output status and progress in JSON-lines format
  -h, --help                  Print help
```

#### 2. Queue Operations (`rdm queue`)
```text
Usage: rdm queue <COMMAND>

Commands:
  list              List all defined queues and active task counts
  start <QUEUE>     Start processing tasks in specified queue
  pause <QUEUE>     Pause processing of specified queue
  create <NAME>     Create a new queue (--sequential or --concurrent)
  set-limit <NAME>  Set aggregate speed limit for queue
```

#### 3. Task Management (`rdm task`)
```text
Usage: rdm task <COMMAND>

Commands:
  list              List downloads (--all, --downloading, --completed)
  status <ID>       Show detailed status, segments, and speed history
  pause <ID>        Pause specified task
  resume <ID>       Resume specified task
  cancel <ID>       Cancel task (--delete-file to purge downloaded data)
  refresh-url <ID>  Update expired URL for task without losing downloaded segments
```

#### 4. Batch Import (`rdm import`)
```text
Usage: rdm import [OPTIONS] <FILE>

Arguments:
  <FILE>  Path to Metalink XML file (.meta4/.metalink) or text file with URLs

Options:
  -d, --dir <DIR>   Destination directory for all imported tasks
  -q, --queue <Q>   Target queue name
  -s, --start       Start downloading all imported tasks immediately
```

---

## 3. Local IPC & JSON-RPC Protocol Specification

When the RDM desktop application is already running, invoking `rdm download` connects to the running instance via local IPC:
- **Windows**: Local Named Pipe: `\\.\pipe\rdm_ipc_{username}`
- **macOS / Linux**: Unix Domain Socket: `/run/user/{uid}/rdm.sock` or `~/.rdm/rdm.sock`

### 3.1 JSON-RPC 2.0 Framing
Messages are exchanged as newline-delimited JSON (`\n`) following the JSON-RPC 2.0 specification:

#### Request (Add Download Task):
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "download.add",
  "params": {
    "url": "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso",
    "target_dir": "D:/ISOs",
    "filename": "ubuntu-24.04.iso",
    "concurrency": 16,
    "start_immediately": true
  }
}
```

#### Response:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "task_id": "c7a8b9d0-1234-5678-9abc-def012345678",
    "status": "downloading",
    "total_bytes": 6120329216,
    "target_path": "D:/ISOs/ubuntu-24.04.iso.rdm_part"
  }
}
```

---

## 4. Headless Server & Docker Deployment Specification

For continuous server and NAS operations without a desktop display:

### 4.1 Headless Configuration (`rdm.toml`)
```toml
[daemon]
bind_address = "0.0.0.0:8384"
secret_token = "env:RDM_SECRET_TOKEN"
data_dir = "/var/lib/rdm"
download_dir = "/downloads"

[engine]
global_concurrency_limit = 64
default_task_concurrency = 16
global_bandwidth_limit_bps = 0  # Uncapped
io_engine = "io_uring"          # Linux kernel 5.15+ io_uring acceleration

[scheduler]
enable_cron = true
```

### 4.2 Minimal Docker Container (`Dockerfile`)
```dockerfile
FROM alpine:3.20 AS runner
RUN apk add --no-cache ca-certificates ffmpeg sqlite-libs libgcc
COPY --chmod=755 rdm /usr/local/bin/rdm
EXPOSE 8384
VOLUME ["/downloads", "/config"]
ENTRYPOINT ["rdm", "daemon", "--config", "/config/rdm.toml"]
```
