# Electrum Scripts (macOS)

macOS launch scripts for Electrum. Each script differs by network and
whether it restricts connections to a local Electrum server only.

## Differences by script

- `mainnet.command`: Mainnet, standard server connections.
- `testnet.command`: Testnet, standard server connections.
- `regtest.command`: Regtest, standard server connections (typically local).
- `mainnet-local-server-only.command`: Mainnet, connects only to a local
  Electrum server.

## Prerequisites

- Electrum app bundle in `macos/bin/Electrum.app`.
- Data directory in `electrum-datadir/`.
- For local server mode, a local Electrum server must be running.
- Note: Some Electrum builds expose `run_electrum` instead of `Electrum` inside
  the app bundle. The launcher scripts accept either.
