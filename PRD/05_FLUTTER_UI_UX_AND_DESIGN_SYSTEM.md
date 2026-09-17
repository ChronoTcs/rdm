# RDM - Flutter UI/UX & Design System Specification

> **Document ID**: RDM-PRD-005  
> **Target Framework**: Flutter 3.24+ Desktop (Windows, macOS, Linux)  
> **Design Language**: Modern Fluent 2 / macOS HIG Hybrid  
> **Accessibility**: WCAG 2.1 AA Compliant  
> **Status**: APPROVED FOR STAGE 1 ARCHITECTURE & IMPLEMENTATION  

---

## 1. Visual Philosophy & Window Frame Architecture

RDM abandons legacy Win32 MFC aesthetics and bloated web views, delivering an ultra-fast, responsive desktop application running natively at up to 120 FPS via Flutter's DirectWrite/DirectX/Metal rendering pipelines.

### 1.1 Window Frame & Platform Translucency
- **Frameless Windowing**: Implemented via `window_manager`, replacing OS titlebars with a bespoke, unified top bar that houses window drag areas, global search, quick action buttons, and platform-native window control buttons.
- **Platform Materials**:
  - **Windows 11**: Integrates Windows **Mica Alt** / **Acrylic** background blur via `flutter_acrylic`, respecting OS personalization settings.
  - **macOS**: Utilizes **NSVisualEffectView** vibrancy materials (behind-window blur) aligned with macOS Sequoia HIG guidelines.
  - **Linux**: Respects system GTK / KDE dark/light palette and client-side decorations (CSD).

```
┌────────────────────────────────────────────────────────────────────────────────────────────┐
│ [≡] RDM  [🔍 Search downloads (Ctrl+F)       ]   [+ New] [▶ Resume] [⏸ Pause]  [─] [□] [✕] │
├───────────────────┬────────────────────────────────────────────────────────────────────────┤
│ 📂 ALL DOWNLOADS  │  Status  Name             Size      Progress      Speed       ETA      │
│   📥 Downloading  │  ────────────────────────────────────────────────────────────────────  │
│   ⏸  Paused       │  [▶]     ubuntu-24.iso    5.4 GB   [██████░░░] 68% 48.2 MB/s   34s     │
│   ✔  Completed    │  [✔]     cuda_toolkit.exe 3.1 GB   [█████████]100%    0 B/s   Done     │
│                   │  [⏸]     game_update.zip  18.2 GB  [██░░░░░░░] 22%    0 B/s  Paused    │
│ 📁 CATEGORIES     │  ────────────────────────────────────────────────────────────────────  │
│   📦 Compressed   │                                                                        │
│   🎬 Video        │                                                                        │
│   🎵 Music        │                                                                        │
│   📄 Documents    ├────────────────────────────────────────────────────────────────────────┤
│   🚀 Programs     │ ▼ TASK INSPECTOR: ubuntu-24.04-desktop-amd64.iso                       │
│                   │ ┌────────────────────────────────────────────────────────────────────┐ │
│ ⏳ QUEUES         │ │ DYNAMIC SEGMENT VISUALIZER (16 Active Connections)                 │ │
│   ⚡ Main Queue   │ │ [██████░░░░████████░░░░████████████░░░░░░████████████████████████] │ │
│   🌙 Night Queue  │ └────────────────────────────────────────────────────────────────────┘ │
│                   │ Speed: 48.2 MB/s (Peak: 72.4 MB/s) | Connections: 16 | ETA: 34s        │
└───────────────────┴────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Color Tokens & Theme Architecture

The design system supports three distinct themes: **Modern Dark** (default), **Clean Light**, and **OLED True Black**, designed to satisfy WCAG 2.1 AAA contrast ratios (> 7:1 for normal text).

### 2.1 Design Token Palette
| Token Name | Modern Dark (Hex) | Clean Light (Hex) | OLED Black (Hex) | Semantic Role |
| :--- | :--- | :--- | :--- | :--- |
| `bg-app` | `#0F172A` (Slate 900) | `#F8FAFC` (Slate 50) | `#000000` | Main application background |
| `bg-surface` | `#1E293B` (Slate 800) | `#FFFFFF` (Pure White) | `#0B0F17` | Card, sidebar, and table surfaces |
| `bg-elevated`| `#334155` (Slate 700) | `#F1F5F9` (Slate 100) | `#161E2E` | Modals, dropdowns, hovered rows |
| `border-subtle`| `#334155` | `#E2E8F0` | `#1E293B` | Table dividers and pane borders |
| `text-primary` | `#F8FAFC` (Slate 50) | `#0F172A` (Slate 900) | `#FFFFFF` | Primary headings, table text |
| `text-secondary`| `#94A3B8` (Slate 400)| `#64748B` (Slate 500)| `#94A3B8` | Subtitles, metadata, file sizes |
| `accent-primary`| `#6366F1` (Indigo 500)| `#4F46E5` (Indigo 600)| `#818CF8` | Primary buttons, active tabs |
| `status-active` | `#38BDF8` (Sky 400)   | `#0284C7` (Sky 600)   | `#38BDF8` | In-progress segment indicators |
| `status-done`   | `#22C55E` (Green 500) | `#16A34A` (Green 600) | `#22C55E` | Completed tasks, verified hashes|
| `status-pause`  | `#F59E0B` (Amber 500) | `#D97706` (Amber 600) | `#F59E0B` | Paused tasks, warnings |
| `status-error`  | `#EF4444` (Red 500)   | `#DC2626` (Red 600)   | `#EF4444` | Network errors, failed tasks |

---

## 3. Typography & Numerical Formatting

Data density and instantaneous readability are critical for a high-performance download manager.

### 3.1 Font Stack & Hierarchy
- **Primary Typeface**: `Inter` (macOS/Linux) and `Segoe UI Variable` (Windows).
- **Tabular Figures (`tnum`)**: All speeds, byte counters, elapsed times, ETAs, and percentage values MUST be rendered with `FontFeature.tabularFigures()`. This prevents visual text jitter as numbers fluctuate rapidly during 100+ MB/s transfers.

```dart
static const TextStyle dataMetricStyle = TextStyle(
  fontFamily: 'Inter',
  fontSize: 13,
  fontWeight: FontWeight.w600,
  fontFeatures: [FontFeature.tabularFigures()],
  letterSpacing: -0.2,
);
```

### 3.2 Type Scale
- **Display Heading (Window Title / Section)**: 18px / Semi-bold (w600) / line-height 24px
- **Table Cell Primary**: 13px / Medium (w500) / line-height 18px
- **Table Cell Secondary / Metadata**: 11px / Regular (w400) / line-height 14px
- **Data Counter / Speed**: 13px / Semi-bold (w600) / Tabular Numbers
- **Tooltip / Microcopy**: 10px / Regular (w400) / line-height 12px

---

## 4. Real-Time Dynamic Segment Visualizer Canvas

The segment visualizer is RDM's flagship visual component, reproducing IDM's legendary segment bar with modern, 60 FPS hardware-accelerated canvas graphics.

```
Visualizer Canvas: File Range [0 Bytes ─────────────────────── Total File Size: 4.0 GB]
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ [████████████░░░░░░░] [██████████████████░░] [██████████░░░░░░] [████████████████████] │
│  Conn 1 (3.2 MB/s)     Conn 2 (8.4 MB/s)      Conn 3 (1.1 MB/s)  Conn 4 (Complete)     │
└────────────────────────────────────────────────────────────────────────────────────────┘
  ▲ Solid Green: Completed Bytes | Animated Cyan Pulse: Active Head | Dark Gray: Unfetched
```

### 4.1 CustomPainter Architecture (`SegmentVisualizerPainter`)
- **Single Canvas Pass**: Renders up to 64 active connections in a single paint call without spawning child widgets.
- **Segment Representation**:
  - **Completed Extents**: Painted with a solid status-done color or linear gradient (`#22C55E` to `#10B981`).
  - **Active In-Flight Head**: Painted with a bright cyan pill (`#38BDF8`) that pulses subtly with an animated shader/opacity cycle.
  - **Unallocated / Remaining Gaps**: Dark background slate (`#1E293B`) with subtle hatched guides.
- **Interactive Tooltip**: Hovering mouse over any region on the canvas uses a binary search on interval bounds to display:
  - Byte Range: `[1,073,741,824 - 1,610,612,736]` (512 MB)
  - Connection ID: `#04 (Worker 4)`
  - Current Speed: `14.2 MB/s`
  - In-flight Status: `Streaming (84% of segment complete)`

---

## 5. Speed History Sparkline & Real-Time Graph

To provide instant feedback on line-rate saturation, RDM features an embedded historical throughput graph:
- **Rolling Window**: Tracks download speeds sampled every 1 second over the preceding 60 seconds.
- **Cubic Bezier Spline**: Evaluates speed points using Catmull-Rom or cubic Bezier smoothing to prevent jagged steps.
- **Area Fill Gradient**: Vertical gradient filling the area beneath the spline with `#6366F1` transitioning to transparent at the baseline.
- **Peak Indicator**: Renders a horizontal dotted guideline marking the all-time peak speed recorded during the current task session.

---

## 6. Key Screen Flows & Modal Dialogs

### 6.1 Add Download Dialog
Triggered by browser interception, clipboard auto-detection, or `Ctrl+N`:
- **URL Field**: Pre-filled from clipboard with instant protocol badge (`HTTP/3`, `HTTPS`, `FTP`, `MAGNET`).
- **File Name & Extension**: Auto-extracted with inline rename capability.
- **Save Location**: Auto-routed based on category; folder browse button (`...`).
- **Category Picker**: Dropdown pre-selected based on extension (Compressed, Video, Music, Documents, Programs, Torrents).
- **Concurrency Slider**: Slider from 1 to 32 connections (default 16).
- **Scheduler Options**: `[x] Download Later` with time/date picker and queue selector.
- **Proxy Override & Auth Credentials**: Collapsible accordion for entering username/password or selecting custom SOCKS5 proxy.
- **Action Buttons**: `[Cancel] (Esc)`, `[Download Later]`, `[Start Download] (Enter)`.

### 6.2 Batch Import Dialog
Triggered by scraping pages or importing URL text/metalink files:
- Multi-row data table listing discovered URLs with checkboxes (`Select All`, `Invert Selection`).
- Live filter toolbar: `Search by keyword`, `Filter by extension: [.mp4, .zip, .pdf]`.
- Batch destination selector.
- Action Buttons: `[Queue All Selected]`, `[Start All Immediately]`.

### 6.3 Floating Desktop Mini-Widget (Speed Pill)
- Ultra-compact, draggable floating pill widget (width: 160px, height: 44px) that stays on top of other desktop windows when minimized.
- Displays aggregate download speed (`▲ 82.4 MB/s`), overall progress arc/bar, and quick pause/resume button.
- Double-clicking the mini-widget restores the main application window instantly.

### 6.4 Floating Desktop Drop Target Basket
Replicating and modernizing IDM's famous "Drop Target", RDM provides a floating, semi-transparent desktop basket:
- **Draggable & Always-on-Top**: Remembers screen coordinates across restarts via `window_manager`.
- **Customizable Appearance**: User can set opacity (20% to 100%), icon skin, and scale.
- **Drag-and-Drop Ingestion**:
  - Dragging a link from any browser or document into the basket triggers the Add Download prompt instantly.
  - Dragging an image or video directly from a webpage grabs the underlying media source.
  - Dragging local `.torrent` or `.metalink` files queues them immediately.
- **Visual Feedback**: Pulses with a glowing cyan accent ring when a dragged object hovers over its drop zone.

### 6.5 Site Logins & Credentials Management UI
Located in Settings -> **Site Logins**:
- Data table listing domain rules: `Domain (e.g. *.mega.nz)`, `Auth Scheme (Basic / Digest / Bearer)`, `Username`, and `Status (Vault Stored)`.
- Action buttons: `[+ Add Login]`, `[Edit]`, `[Delete]`.
- Passwords are encrypted directly into OS Native Vault (Windows Credential Manager / macOS Keychain); never rendered in plaintext in the UI.

### 6.6 Customizable File Types & Extension Mapping
Located in Settings -> **File Types**:
- Lists each category (Compressed, Video, Audio, Documents, Programs) alongside its editable list of comma-separated extensions.
- Allows users to add custom extensions (e.g., adding `.zst`, `.tar.zst` to Compressed).
- User can configure "Do not intercept downloads for following file extensions" (e.g. `.pdf` for in-browser viewing).

---

## 7. Keyboard Navigation & Accessibility (WCAG 2.1 AA)

### 7.1 Global Keyboard Shortcuts
| Key Combination | Action |
| :--- | :--- |
| `Ctrl + N` (`Cmd + N`) | Open Add Download Dialog |
| `Ctrl + O` (`Cmd + O`) | Open File / Import URL List |
| `Spacebar` | Toggle Pause / Resume for selected task(s) |
| `Delete` | Remove selected task(s) from list |
| `Shift + Delete` | Permanently delete selected task and delete file from disk |
| `Ctrl + A` (`Cmd + A`) | Select all downloads in current view |
| `Ctrl + F` (`Cmd + F`) | Focus global search bar |
| `Ctrl + ,` (`Cmd + ,`) | Open Settings Dialog |
| `F5` | Refresh download table and force status sync |
| `Escape` | Close active dialog / Dismiss inspector drawer |

### 7.2 Accessibility & Screen Reader Semantics
- Every interactive icon, button, and table row is wrapped with Flutter's `Semantics` widget.
- Screen readers (Windows Narrator, NVDA, macOS VoiceOver) announce task progress changes at 25% milestones (e.g., `"Ubuntu 24 ISO, 50% completed, 42 megabytes per second"`).
- Keyboard focus indicators feature a high-contrast 2px solid accent ring (`#818CF8`) with 2px optical offset.

---

## 8. Internationalization & Multi-Language Localization (i18n)

RDM is built for a global user base, featuring a comprehensive localization architecture:
- **Flutter Localizations (`intl`)**: Powered by `flutter_localizations` with standardized Application Resource Bundle (`.arb`) files in `lib/l10n/app_{locale}.arb`.
- **Supported Launch Languages**: English (default), Indonesian, Spanish, French, German, Japanese, and Simplified Chinese.
- **RTL Layout Engine**: Automatically mirrors layout, navigation drawer, and progress bars when an RTL locale (Arabic, Hebrew, Persian) is active.
- **Instant Hot-Switching**: Changing language in Settings immediately re-renders all UI strings without requiring application restart.

---

## 9. Audio Event Notifications & Sound Effects

To preserve the satisfying tactile feedback popularized by IDM:
- **Audio Event Triggers**:
  1. `SoundEvent::DownloadComplete`: Crisp, pleasant completion chime when a download reaches 100% verification.
  2. `SoundEvent::QueueComplete`: Multi-tone fanfare when an entire batch/queue finishes.
  3. `SoundEvent::DownloadFailed`: Subtle warning tone on unrecoverable network or disk errors.
- **Custom Sound Packs**: Users can toggle sounds ON/OFF globally, adjust volume, or supply custom `.wav` or `.ogg` audio files.

