# Changelog

All notable changes to PortaNode will be documented in this file.

The format is based on [Calendar Versioning](https://calver.org/),
using YYYY.MM.DD format.

## [2026.01.28] - git main branch
- Bitcoin macOS launchers now distinguish missing vs non-executable binaries
  and add checks to testnet launcher.
- Windows regtest Bitcoin launchers now include full binary paths
  in missing-binary errors.
- Added macOS smoke test for Bitcoin launcher error paths.
- Launcher menus: blank input maps to exit, utilities menu reordered,
  and update binaries added.
- Utilities launchers now include rollback options for Bitcoin and Electrum.
- Utilities README now notes the rollback options in the launcher menus.
- Standardized launcher parity: consistent missing-script checks, error messages,
  and spacing across .command/.bat/.ps1/.sh.
- Update scripts now update local checksums after successful PGP verification.
- Rollback scripts now verify the backup binary checksum before restoring.
- Update/rollback scripts now emit one-line directory listings when expected
  files are missing.
- Update scripts now continue when PGP verification cannot be performed due to
  missing `gpg` or signer keys; bad signatures still fail, and checksums are
  only updated after successful verification.
- Utilities READMEs now document the signature verification behavior.
- Utilities READMEs now clarify that detached signatures require local signer
  keys to validate; without them, signatures cannot be checked locally.
- Factored shared update/rollback verification helpers into macOS/Windows
  utility libraries and rewired the scripts to use them.
- Windows Electrum updater now restores the full update flow using shared
  verification and checksum helpers.
- Verify-binaries scripts now treat missing binaries as informational and only
  fail on checksum mismatches.
- Bitcoin updater now hashes the extracted binary (not the app bundle directory)
  when updating checksums.
- Bitcoin updater now validates and locates the extracted app bundle before
  checksum updates and install.
- Bitcoin updater now uses the codesigning tarball to obtain Bitcoin-Qt.app.
- Bitcoin updater now checks the extracted top-level dist/ folder for
  Bitcoin-Qt.app.

## [2026.01.27] - Initial Release
- Portable Bitcoin Core and Electrum setup for macOS and Windows.
- Cross-platform launchers (root launchers + per-network scripts).
- Regtest multi-node setups (Alice/Bob/Carol) with clean-start variants.
- Update, verify, rollback, and validation utilities for both OSes.
- Checksums and PGP verification support in update workflows.
- Health checks, log rotation, and monitoring scripts.
