# Changelog

All notable changes to PortaNode will be documented in this file.

The format is based on [Calendar Versioning](https://calver.org/),
using YYYY.MM.DD format.

## [2026.01.28]
- Bitcoin macOS launchers now distinguish missing vs non-executable binaries and add checks to testnet launcher.
- Windows regtest Bitcoin launchers now include full binary paths in missing-binary errors.
- Added macOS smoke test for Bitcoin launcher error paths.
- Launcher menus: blank input maps to exit, utilities menu reordered, and update binaries added.
- Standardized launcher parity: consistent missing-script checks, error messages, and spacing across .command/.bat/.ps1/.sh.

## [2026.01.27] - Initial Release
- Portable Bitcoin Core and Electrum setup for macOS and Windows.
- Cross-platform launchers (root launchers + per-network scripts).
- Regtest multi-node setups (Alice/Bob/Carol) with clean-start variants.
- Update, verify, rollback, and validation utilities for both OSes.
- Checksums and PGP verification support in update workflows.
- Health checks, log rotation, and monitoring scripts.
