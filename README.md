# PortaNode

## Portable (external disk) cross-platform Bitcoin full node.

PortaNode bundles scripts, binaries, and data for running Bitcoin Core and
Electrum on macOS and Windows.

Version: 2026.01.26 (Calendar Versioning)

## Prerequisites

- **Operating System**: macOS 10.15+ or Windows 10+.
- **Disk Space**: At least 500GB free for Bitcoin Core data (mainnet); more for full sync. Regtest/testnet require less.
- **Permissions**: Ensure the external disk is mounted and writable. On macOS, scripts may need executable permissions (run `chmod +x macos/scripts/**/*.command` if needed).
- **Dependencies**: None required beyond standard OS tools. For advanced use, ensure Python (for Electrum) and command-line tools are available.

## Quick Start

1. Mount your external disk and navigate to the PortaNode folder.
2. For macOS: Double-click a script in `macos/scripts/bitcoin/` or `macos/scripts/electrum/` (e.g., `mainnet-8333-qt.command`).
3. For Windows: Double-click a script in `win/scripts/bitcoin/` or `win/scripts/electrum/` (e.g., `mainnet-8333-qt.bat`).
4. Use `Launcher.command` (macOS), `Launcher.bat` (Windows), or `Launcher.ps1` (PowerShell) for a menu-based launcher. `Launcher.sh` is a cross-platform entrypoint when using a shell.
5. Additional root launchers: `Bitcoin-Launcher.*`, `Electrum-Launcher.*`, and `Utilities-Launcher.*` (choose `.command`, `.bat`, `.ps1`, or `.sh` for your OS).
6. Follow on-screen prompts (e.g., confirm data deletion for clean scripts).

## Launcher Notes

- `.command` files are intended for double‑clicking in Finder on macOS.
- `.sh` files are intended for running from a shell (macOS/Linux or Windows MSYS/Cygwin).
- `.bat` files are intended for Command Prompt/PowerShell on Windows.
- `.ps1` files are intended for PowerShell on Windows (menu-based, same options as `.bat`).

## Folder Structure

- `macos/`
  - `bin/`: macOS app bundles for Bitcoin Core and Electrum.
  - `bin/backup/`: macOS backups created by update scripts (see `macos/bin/backup/README.md`).
  - `checksums.sha256`: macOS checksums (versioned).
  - `scripts/`
    - `bitcoin/`: Bitcoin Core launch scripts (.command). See `macos/scripts/bitcoin/README.md`.
    - `electrum/`: Electrum launch scripts (.command). See `macos/scripts/electrum/README.md`.

- `win/`
  - `bin/`: Windows binaries (e.g., `electrum.exe`).
  - `bin/backup/`: Windows backups created by update scripts (see `win/bin/backup/README.md`).
  - `checksums.sha256`: Windows checksums (versioned) at `win/checksums.sha256`.
  - `scripts/`
    - `bitcoin/`: Bitcoin Core launch scripts (.bat). See `win/scripts/bitcoin/README.md`.
    - `electrum/`: Electrum launch scripts (.bat). See `win/scripts/electrum/README.md`.

- `bitcoin-datadir/`: Bitcoin Core configuration/data (e.g., `bitcoin.conf`).
- `electrum-datadir/`: Electrum data (wallets, regtest/testnet data).
- `macos/scripts/utilities/`: macOS maintenance scripts (updates, verification, cleanup, logs).
- `win/scripts/utilities/`: Windows maintenance scripts (updates, verification, cleanup, logs).
- `macos/bin/backup/`: Backups created by update scripts (Electrum.app, Bitcoin-Qt.app).
- `win/bin/backup/`: Backups created by update scripts (Windows .exe files).

## Detailed Setup

### Bitcoin Core
- **Mainnet**: Use `mainnet-8333-qt` scripts for GUI or CLI.
- **Testnet**: Use `testnet3-18333-qt` for testnet.
- **Regtest**: Use `regtest-*` scripts for local testing. Clean scripts reset data.
- Data is stored in `bitcoin-datadir/`. Configure via `bitcoin.conf`.

### Electrum
- **Mainnet**: Use `mainnet` or `mainnet-local-server-only` (connects to local server).
- **Testnet/Regtest**: Use respective scripts.
- Data in `electrum-datadir/`. Wallets are in `wallets/`.

### Environment Overrides
Set `PORTANODE_ROOT` to customize the root path (e.g., if moving the folder):
- macOS: `export PORTANODE_ROOT=/path/to/portanode`
- Windows: `set PORTANODE_ROOT=C:\path\to\portanode`

## Updating Binaries

- **Bitcoin Core**: Download latest from [bitcoincore.org](https://bitcoincore.org/en/download/). Replace files in `macos/bin/Bitcoin-Qt.app` or `win/bin/bitcoin-*.exe`.
- **Electrum**: Download from [electrum.org](https://electrum.org/#download). Replace `Electrum.app` or `electrum.exe`.
- Verify checksums from official sources to ensure integrity.
- If `gpg` is installed, update scripts verify PGP signatures for Bitcoin Core and Electrum downloads.
  - **Bitcoin Core signing keys**: obtain keys from the official Bitcoin Core repository (`contrib/builder-keys/keys.txt`) and import with `gpg --import`.
  - **Electrum signing key**: obtain the release signing key from electrum.org (Download page) and import with `gpg --import`.
- After update, test with regtest scripts.
- Use `./macos/scripts/utilities/update-bitcoin.sh` or `./macos/scripts/utilities/update-electrum.sh` for automated updates (backs up old versions).
- On Windows, use `win\\scripts\\utilities\\update-bitcoin.bat` and `win\\scripts\\utilities\\update-electrum.bat`.
- Rollback with `./macos/scripts/utilities/rollback-bitcoin.sh` or `./macos/scripts/utilities/rollback-electrum.sh` if issues occur.
- On Windows, use `win\\scripts\\utilities\\rollback-bitcoin.bat` and `win\\scripts\\utilities\\rollback-electrum.bat`.
- Validate setup with `./macos/scripts/utilities/validate-setup.sh` after updates.
- On Windows, use `win\\scripts\\utilities\\validate-setup.bat`.
 - **Backup/Rollback**: Rollback scripts depend on backups created by update scripts—test the full update→rollback cycle after changes.
- **Checksums**: `macos/checksums.sha256` and `win/checksums.sha256` keep ever-growing lists of acceptable hashes labeled by version; update scripts append new entries and deduplicate exact duplicates.
 - **Signing Keys**:
   - Bitcoin Core: import keys from `contrib/builder-keys/keys.txt` in the official Bitcoin Core repo. Verify fingerprints before trust.
   - Electrum: import the release signing key from electrum.org Download page. Verify the fingerprint published there.

## Troubleshooting

### Common Issues
- **Script fails with "Binary not found"**: Ensure binaries are in `macos/bin/` or `win/bin/`. Check permissions.
- **Permission denied on macOS**: Run `chmod +x macos/scripts/**/*.command`.
- **Disk space errors**: Free up space or use pruning in `bitcoin.conf` (`prune=550` for ~550MB blocks).
- **Sync issues**: Check logs in `bitcoin-datadir/debug.log`. For Electrum, check console output.
- **Regtest not connecting**: Ensure all regtest scripts are run (Alice, Bob, Carol) and ports are open.
- **Path errors**: If moved, use `PORTANODE_ROOT` or adjust scripts.

### Logs and Debugging
- Bitcoin: `bitcoin-datadir/debug.log`
- Electrum: Check terminal output or `electrum-datadir/` for logs.
- Run scripts from terminal for verbose output: `bash macos/scripts/bitcoin/mainnet-8333-qt.command` or `win\scripts\bitcoin\mainnet-8333-qt.bat`.
- Rotate logs: `./macos/scripts/utilities/rotate-bitcoin-log.sh` or `win\\scripts\\utilities\\rotate-bitcoin-log.bat`
- Monitor logs: `./macos/scripts/utilities/monitor-bitcoin-log.sh` or `win\\scripts\\utilities\\monitor-bitcoin-log.bat` (run periodically to check for errors)

### Getting Help
- Check [Bitcoin Wiki](https://en.bitcoin.it/wiki/Main_Page) or [Electrum Docs](https://electrum.readthedocs.io/).
- Report issues with logs and OS details.

## Version Compatibility

- **Bitcoin Core**: Check `bitcoin-cli --version`.
- **Electrum**: Check `electrum --version`.
- Compatible with macOS 10.15+, Windows 10+. Test on your setup.

## Contributing

This is an open-source project. To contribute:
- Fork the repo and submit pull requests.
- Report bugs with steps to reproduce.
- Suggest improvements via issues.
- Follow coding standards: Use relative paths, add error checks.

## Security Notes

- **Binary Integrity**: Verify binaries with `macos/scripts/utilities/verify-binaries.sh` (macOS) or `win/scripts/utilities/verify-binaries.bat` (Windows) after downloads.
  - Each verification script checks only its platform’s binaries.
- **Data Backups**: Regularly backup `bitcoin-datadir/wallets/` and `electrum-datadir/wallets/`. Use encrypted storage.
- **Network Security**: Bitcoin Core RPC is enabled in `bitcoin.conf`. Bind to localhost only and use strong passwords. Configure firewall to restrict access.
- **Permissions**: Set restrictive permissions on data directories: `./macos/scripts/utilities/set-permissions.sh` or `win\\scripts\\utilities\\set-permissions.bat`.
- **File Artifacts**: macOS creates `._*` and `.DS_Store` files; these are ignored by `.gitignore`. Run `./macos/scripts/utilities/clean-artifacts.sh` or `win\\scripts\\utilities\\clean-artifacts.bat` to remove existing ones.
