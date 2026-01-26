# Utilities

This directory contains macOS maintenance and utility scripts for PortaNode.

## Scripts Overview

### Update Scripts
- **`update-bitcoin.sh`**: Downloads and installs the latest Bitcoin Core binaries. Detects architecture (x86_64/arm64), backs up old binaries, verifies checksums, and updates the checksum file.
- **`update-electrum.sh`**: Fetches the latest Electrum version from electrum.org, downloads the DMG, mounts it, replaces binaries, and backs up old versions.

### Verification Scripts
- **`verify-binaries.sh`**: Verifies all binaries against `macos/checksums.sha256` using `shasum`. Supports multiple acceptable hashes per file with version labels.
- **Note**: `verify-binaries.sh` uses `bash` features (associative arrays). Run it with `bash` if your system’s default `sh` is not bash.

### Rollback Scripts
- **`rollback-bitcoin.sh`**: Restores Bitcoin binaries from `macos/bin/backup/bitcoin/` if an update fails.
- **`rollback-electrum.sh`**: Restores Electrum binaries from `macos/bin/backup/electrum/`.

### Validation and Setup
- **`validate-setup.sh`**: Checks for macOS binaries, runs checksum verification, confirms data directories, and reports disk space. Run after setup or updates.

### Logging and Monitoring
- **`rotate-bitcoin-log.sh`**: Rotates `bitcoin-datadir/debug.log` by creating backups (debug.log.1, etc.) and starting a new log file.
- **`monitor-bitcoin-log.sh`**: Monitors the Bitcoin log for new errors/warnings, sending macOS notifications if issues are detected. Tracks progress to avoid duplicates.

### Cleanup and Maintenance
- **`clean-artifacts.sh`**: Removes macOS artifacts (`._*`, `.DS_Store`) from the project.
- **`set-permissions.sh`**: Sets restrictive permissions (700) on `bitcoin-datadir/` and `electrum-datadir/` for security.

## Usage Notes
- Run scripts from the project root (e.g., `./macos/scripts/utilities/script.sh`).
- Most scripts require internet for downloads; ensure connectivity.
- If `gpg` is installed, update scripts verify PGP signatures for Bitcoin Core and Electrum downloads.
  - **Bitcoin Core signing keys**: obtain keys from the official Bitcoin Core repository (`contrib/builder-keys/keys.txt`) and import with `gpg --import`.
  - **Electrum signing key**: obtain the release signing key from electrum.org (Download page) and import with `gpg --import`.
- Backups are stored in `macos/bin/backup/`; rollbacks depend on these.
- `macos/checksums.sha256` is append-only: new verified hashes are added with `version=<x>` and exact duplicates are pruned.
- Update scripts place temporary downloads under `macos/bin/.tmp-downloads/` and clean them on exit.
- Cleanup scripts are OS-specific; macOS cleanup only targets macOS artifacts.
- Health checks rely on process listing; some sandboxed environments may restrict this and reduce detection accuracy.
- Root launchers are available for specific areas: `Bitcoin-Launcher.*`, `Electrum-Launcher.*`, and `Utilities-Launcher.*` (choose `.command` or `.sh` for macOS).
- Check script output for errors; refer to main README.md for troubleshooting.

## Dependencies
- macOS: `curl`, `shasum`, `hdiutil` (for DMG handling).
- General: Bash-compatible shell.

For more details, see the main README.md.
