# Electrum Scripts (Windows)

Windows launch scripts for Electrum. Each script differs by network and
whether it restricts connections to a local Electrum server only.

## Differences by script

- `mainnet.bat`: Mainnet, standard server connections.
- `testnet3.bat`: Testnet3, standard server connections.
- `testnet4.bat`: Testnet4, standard server connections.
- `regtest.bat`: Regtest, standard server connections (typically local).
- `mainnet-local-server-only.bat`: Mainnet, connects only to a local
  Electrum server.

## Prerequisites

- Electrum executable in `win/bin/electrum.exe`.
- Data directory in `electrum-datadir/`.
- For local server mode, a local Electrum server must be running.
