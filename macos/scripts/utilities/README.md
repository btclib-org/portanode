# Utilities

This directory contains macOS maintenance and utility scripts for PortaNode. Windows utilities live under `win/scripts/utilities/`.

## Scripts Overview

### Update Scripts
- **`update-bitcoin.sh`** (macOS): Downloads and installs the latest Bitcoin Core binaries. Detects architecture (x86_64/arm64), backs up old binaries, verifies checksums, and updates the checksum file.
- **`update-bitcoin.bat`** (Windows): Equivalent to the macOS script, located in `win/scripts/utilities/`.
- **`update-electrum.sh`** (macOS): Fetches the latest Electrum version from electrum.org, downloads the DMG, mounts it, replaces binaries, and backs up old versions.
- **`update-electrum.bat`** (Windows): Downloads the latest Electrum portable EXE for Windows, located in `win/scripts/utilities/`.

### Verification Scripts
- **`verify-binaries.sh`** (macOS): Verifies all binaries against `macos/checksums.sha256` using `shasum`. Supports multiple acceptable hashes per file with version labels.
- **`verify-binaries.bat`** (Windows): Uses PowerShell to compute hashes and compare with the checksum file, located in `win/scripts/utilities/`.

### Rollback Scripts
- **`rollback-bitcoin.sh`** (macOS): Restores Bitcoin binaries from `macos/bin/backup/bitcoin/` if an update fails.
- **`rollback-electrum.sh`** (macOS): Restores Electrum binaries from `macos/bin/backup/electrum/`.
- **`rollback-bitcoin.bat`** (Windows): Restores Bitcoin binaries from `win/bin/backup/bitcoin/`, located in `win/scripts/utilities/`.
- **`rollback-electrum.bat`** (Windows): Restores Electrum binaries from `win/bin/backup/electrum/`, located in `win/scripts/utilities/`.
- **`validate-setup.bat`** (Windows): Validates Windows binaries, checksums, and disk space; located in `win/scripts/utilities/`.
- **`rotate-bitcoin-log.bat`** (Windows): Rotates `bitcoin-datadir/debug.log` and truncates the current log.
- **`monitor-bitcoin-log.bat`** (Windows): Scans Bitcoin log for new errors/warnings.
- **`health-check.bat`** (Windows): Disk space + basic process checks.
- **`clean-artifacts.bat`** (Windows): Removes macOS/Windows artifact files.
- **`set-permissions.bat`** (Windows): Sets restrictive ACLs on data directories.

### Validation and Setup
- **`validate-setup.sh`**: Checks for macOS binaries, runs checksum verification, confirms data directories, and reports disk space. Run after setup or updates.
- **`validate-setup.bat`** (Windows): Equivalent validation for Windows, located in `win/scripts/utilities/`.

### Logging and Monitoring
- **`rotate-bitcoin-log.sh`**: Rotates `bitcoin-datadir/debug.log` by creating backups (debug.log.1, etc.) and starting a new log file.
- **`monitor-bitcoin-log.sh`**: Monitors the Bitcoin log for new errors/warnings, sending macOS notifications if issues are detected. Tracks progress to avoid duplicates.

### Cleanup and Maintenance
- **`clean-artifacts.sh`**: Removes macOS artifacts (`._*`, `.DS_Store`) and Windows artifacts (`ehthumbs.db`, etc.) from the project.
- **`set-permissions.sh`**: Sets restrictive permissions (700) on `bitcoin-datadir/` and `electrum-datadir/` for security.

## Usage Notes
- Run scripts from the project root (e.g., `./macos/scripts/utilities/script.sh`).
- Most scripts require internet for downloads; ensure connectivity.
- Backups are stored in `macos/bin/backup/` and `win/bin/backup/`; rollbacks depend on these.
- `macos/checksums.sha256` is append-only: new verified hashes are added with `version=<x>` and exact duplicates are pruned.
- Update scripts place temporary downloads under `macos/bin/.tmp-downloads/` or `win/bin/.tmp-downloads/` and clean them on exit.
- For Windows scripts, use Command Prompt or PowerShell.
- Check script output for errors; refer to main README.md for troubleshooting.

## Dependencies
- macOS: `curl`, `shasum`, `hdiutil` (for DMG handling).
- Windows: PowerShell (for downloads and hashing).
- General: Bash-compatible shell.

For more details, see the main README.md.
