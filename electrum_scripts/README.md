# Electrum Scripts

This folder contains scripts to launch Electrum, a lightweight Bitcoin
wallet, in various network configurations and modes.

## Overview

Electrum is a fast, secure, and user-friendly Bitcoin wallet that connects
to external servers for blockchain data. These scripts simplify launching
Electrum with different settings for development, testing, and production
use.

## Networks

- **Mainnet**: The live Bitcoin network.
- **Testnet**: The test network for Bitcoin.
- **Regtest**: A local regression test network for development and testing.

## Modes

- **Standard**: Connects to public Electrum servers.
- **Local Server Only**: Connects only to a local Electrum server (useful for
  regtest or private setups).

## Prerequisites

- Electrum executables must be placed in the following locations:
  - macOS: `../electrum_bin/macos/Electrum.app`
  - Windows: `../electrum_bin/win/electrum.exe`
- Ensure the executables are the standalone versions (not portable for
  Windows).
- For local server mode, a local Electrum server should be running.
- Data directories are located in `../electrum_data/`.

## macOS Scripts (macos/ folder)

Run these by double-clicking the .command files or executing them in
Terminal.

- `mainnet.command`: Launch Electrum on mainnet.
- `testnet.command`: Launch Electrum on testnet.
- `regtest.command`: Launch Electrum on regtest.
- `mainnet-local-server-only.command`: Launch Electrum on mainnet,
  connecting only to local server.

## Windows Scripts (win/ folder)

Run these by double-clicking the .bat files or executing them in Command
Prompt.

- `mainnet.bat`: Launch Electrum on mainnet.
- `testnet.bat`: Launch Electrum on testnet.
- `regtest.bat`: Launch Electrum on regtest.
- `mainet-local-server-only.bat`: Launch Electrum on mainnet, connecting
  only to local server.

## Usage

1. Ensure Electrum executables are in the correct bin folders.
2. Navigate to the appropriate OS folder (macos/ or win/).
3. Run the desired script.
4. Electrum will launch with the specified configuration.

## Troubleshooting

- If Electrum fails to start, verify the executable paths and permissions.
- For local server mode, ensure a compatible Electrum server is running
  locally.
- Check `../electrum_data/config` for configuration issues.
- Ensure network connectivity for public server modes.
