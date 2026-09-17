# RDM - Security, Compliance & Distribution Specification

> **Document ID**: RDM-PRD-008  
> **Target Subsystems**: `rdm_security`, `rdm_antivirus`, Build & Packaging Pipelines  
> **Status**: APPROVED FOR STAGE 1 ARCHITECTURE & IMPLEMENTATION  

---

## 1. Security Architecture & Threat Modeling (STRIDE)

As a high-privilege networking utility that downloads arbitrary binaries and interacts with web browsers, RDM implements a rigorous defense-in-depth security architecture.

### 1.1 Threat Model Analysis
| Threat Class (STRIDE) | Attack Vector | Mitigation in RDM |
| :--- | :--- | :--- |
| **Spoofing** | Attacker impersonates download server or mirror. | Strict TLS 1.3 verification with `webpki-roots`; pre-shared hash verification before execution. |
| **Tampering** | Man-in-the-middle alters downloaded bytes or segments. | Per-block SHA-256 verification; automatic segment rejection and re-fetch upon hash mismatch. |
| **Repudiation** | Malicious site triggers arbitrary local file overwrites. | Strict path traversal sanitization; mandatory prompt on destructive overwrites. |
| **Information Disclosure**| Site credentials / proxy passwords leaked from disk. | Zero plaintext passwords in SQLite; credentials stored in OS Native Credential Vaults. |
| **Denial of Service** | Malicious HTTP server sends infinite chunked stream or zip bomb. | Hard storage quota checks; automatic abort if byte count exceeds declared Content-Length by > 5%. |
| **Elevation of Privilege**| Native messaging host executes shell commands. | Native Host strictly sanitizes JSON inputs; runs under unprivileged standard user context (no admin rights). |

### 1.2 Path Traversal & Filename Sanitization
Malicious servers can attempt directory escape attacks via crafted `Content-Disposition` headers (e.g. `filename="../../../Windows/System32/evil.dll"`).

RDM enforces a 4-step canonicalization pipeline:
1. Strips all relative directory navigation tokens (`..`, `/`, `\`).
2. Replaces illegal OS characters (`:`, `*`, `?`, `"`, `<`, `>`, `|`, `\0`) with clean underscores (`_`).
3. Strips reserved Windows device names (`CON`, `PRN`, `AUX`, `NUL`, `COM1-COM9`, `LPT1-LPT9`).
4. Enforces a 255-character filename cap; if longer, truncates the stem while strictly preserving the file extension.

---

## 2. OS Native Credential Vault

RDM never stores sensitive authentication passwords, FTP credentials, or proxy tokens in plaintext configuration files or local SQLite databases.

### 2.1 Platform Vault Implementations
Utilizes the `keyring` Rust crate to bind directly into platform security subsystems:
- **Windows**: **Windows Credential Manager** via Win32 DPAPI (`CredWriteW` / `CredReadW`) with user-bound encryption.
- **macOS**: **Apple Keychain Services** (`SecKeychainAddGenericPassword`) backed by the Secure Enclave.
- **Linux**: **Secret Service API** via D-Bus (`org.freedesktop.secrets`) communicating with GNOME Keyring or KDE KWallet.

---

## 3. Automated Antivirus & Malware Defense Pipeline

RDM integrates directly with desktop antivirus engines to screen all completed downloads before the user opens them.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       POST-DOWNLOAD SECURITY SCANNER                        │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. Download reaches 100% byte verification                                  │
│ 2. File locked in staging mode (`.rdm_part` extension retained)             │
│ 3. Automated Antivirus Scan triggered                                       │
│    - Windows: Windows Defender via AMSI / `MpCmdRun.exe`                    │
│    - macOS: XProtect / Gatekeeper verification (`spctl`)                    │
│    - Linux / Custom: Configurable scanner CLI (ClamAV, etc.)                │
├─────────────────────────────────────────────────────────────────────────────┤
│  [Clean File] ──► Rename to target extension ──► Trigger desktop alert      │
│  [Infected]   ──► Quarantine file to sandbox ──► Display Critical Warning   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.1 Antivirus Integration Engine & User-Configurable Scanner
RDM supports both system-default antivirus integration and custom antivirus binaries:

1. **Windows Defender (Default)**:
   ```powershell
   & "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -Scan -ScanType 3 -File "$target_file_path"
   ```
2. **User-Configurable Scanner (IDM Parity)**:
   Users can configure any third-party antivirus in Settings -> **Security**:
   - **Scanner Binary Path**: e.g., `C:\Program Files\Kaspersky Lab\...\avp.com` or `/usr/bin/clamscan`
   - **Command Line Arguments Template**: e.g., `scan "%FILE%" /quarantine` or `--infected --bell "%FILE%"`
   - RDM dynamically substitutes `%FILE%` with the verified absolute file path.
3. **Detection & Quarantine Handling**:
   - If the scanner exits with a non-zero threat code:
     1. Strips file execution permissions immediately.
     2. Moves the file into `~/Downloads/RDM/.quarantine/`.
     3. Emits high-priority alert in Flutter UI with threat details and quarantine path.

---

## 4. Cross-Platform Packaging & Distribution Pipelines

### 4.1 Windows Distribution
- **MSIX Package**: Modern Windows packaging with identity, auto-updates via Microsoft Store or sideloading, and clean uninstallation.
- **Inno Setup Installer (`.exe`)**: Traditional enterprise-ready installer with options for desktop shortcut, start menu entry, context menu integration, and system startup daemon.
- **Portable ZIP**: Standalone directory containing `rdm.exe` and bundled libraries for USB drive execution.
- **Authenticode Signing**: Signed using a Microsoft Authenticode EV Certificate or Azure Trusted Signing to eliminate Windows SmartScreen warnings.

### 4.2 macOS Distribution
- **Universal Binary**: Compiles Flutter and Rust into universal Mach-O binaries supporting both Apple Silicon (ARM64) and Intel (x86_64).
- **DMG Disk Image**: Signed drag-to-Applications `.dmg` with custom background graphic and symlink.
- **Hardened Runtime & Notarization**:
  - Signed with Apple Developer ID Application Certificate with Hardened Runtime enabled (`--options runtime`).
  - Submitted to Apple Notary Service via `xcrun notarytool` to pass Gatekeeper checks without alerts.

### 4.3 Linux Distribution
- **Flatpak**: Packaged for Flathub with sandboxed permissions for network access and the Downloads directory.
- **AppImage**: Standalone executable containing all bundled dependencies for universal execution across Ubuntu, Fedora, Arch, and openSUSE.
- **Debian / RPM**: Native `.deb` and `.rpm` packages with systemd user service scripts.

---

## 5. Cryptographic Auto-Updater Architecture

RDM features an integrated, zero-interruption background auto-updater:
1. **Periodic Update Probing**: Checks RDM's release feed over HTTPS every 24 hours or upon explicit user request.
2. **Ed25519 Cryptographic Verification (`ed25519-dalek` 2.x)**: Every update manifest contains an Ed25519 signature generated by the official RDM release key. The client verifies this signature before downloading update payloads:
   ```rust
   pub fn verify_release_signature(manifest_bytes: &[u8], signature_bytes: &[u8], public_key_bytes: &[u8]) -> bool {
       use ed25519_dalek::{Verifier, Signature, VerifyingKey};
       if signature_bytes.len() != 64 || public_key_bytes.len() != 32 {
           return false;
       }
       let sig = match Signature::from_slice(signature_bytes) {
           Ok(s) => s,
           Err(_) => return false,
       };
       let key_array: &[u8; 32] = match public_key_bytes.try_into() {
           Ok(arr) => arr,
           Err(_) => return false,
       };
       let verifying_key = match VerifyingKey::from_bytes(key_array) {
           Ok(key) => key,
           Err(_) => return false,
       };
       verifying_key.verify(manifest_bytes, &sig).is_ok()
   }
   ```
3. **Delta Patching**: For minor updates, RDM downloads binary diff patches (reducing update download sizes from 80MB down to < 5MB).
4. **Seamless Replacement**: Uses atomic directory replacement on restart, backing up the prior binary to allow instant rollback if the updated application fails startup integrity tests.
