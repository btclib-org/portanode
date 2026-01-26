# Windows Utilities

This folder contains Windows maintenance scripts for PortaNode. These are designed for Command Prompt or PowerShell.

## Scripts

### Updates
- `update-bitcoin.bat`: Downloads and installs Bitcoin Core (win64), backs up binaries, updates checksums.
- `update-electrum.bat`: Downloads Electrum portable EXE, backs up binary, updates checksums.

### Verification and Validation
- `verify-binaries.bat`: Verifies Windows binaries against `win/checksums.sha256` (versioned entries supported).
- `validate-setup.bat`: Checks Windows binaries, verifies checksums, and reports disk space.

### Rollback
- `rollback-bitcoin.bat`: Restores Bitcoin binaries from `win/bin/backup/bitcoin/`.
- `rollback-electrum.bat`: Restores Electrum binary from `win/bin/backup/electrum/`.

### Logging and Maintenance
- `rotate-bitcoin-log.bat`: Rotates `bitcoin-datadir/debug.log` and truncates the current log.
- `monitor-bitcoin-log.bat`: Scans the Bitcoin log for new errors/warnings.
- `health-check.bat`: Disk space + basic process checks.
- `clean-artifacts.bat`: Removes Windows artifact files from the repo.
- `set-permissions.bat`: Sets restrictive ACLs on data directories.

## Notes
- Run from repo root or double-click in Explorer; scripts resolve paths relative to the repo.
- Backups are stored in `win/bin/backup/` and are required for rollback.
- Updates download into `win/bin/.tmp-downloads/` and clean up after themselves.
- Log monitoring attempts to show a Windows toast notification; if unavailable, it falls back to a MessageBox or console warning.
- Cleanup scripts are OS-specific; Windows cleanup only targets Windows artifacts.
- If `gpg` is installed, update scripts verify PGP signatures for Bitcoin Core and Electrum downloads.
  - **Bitcoin Core signing keys**: obtain keys from the official Bitcoin Core repository (`contrib/builder-keys/keys.txt`) and import with `gpg --import`.
  - **Electrum signing key**: obtain the release signing key from electrum.org (Download page) and import with `gpg --import`.
- Root launchers `Launcher.bat` and `Launcher.ps1` provide a menu to start common scripts from the repo root.
- Root launchers are also available for specific areas: `Bitcoin-Launcher.*`, `Electrum-Launcher.*`, and `Utilities-Launcher.*` (choose `.bat` or `.ps1` for Windows).

## Smoke Check (Windows)
Run these in order after updates:
1. `win\scripts\utilities\verify-binaries.bat`
2. `win\scripts\utilities\validate-setup.bat`
3. `win\scripts\utilities\health-check.bat`
