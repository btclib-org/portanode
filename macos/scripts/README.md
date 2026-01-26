# Scripts

Entry point for launch scripts.

## Folders

- `bitcoin/`: Bitcoin Core scripts (.command).
  - `mainnet-8333-qt.command`: GUI for mainnet.
  - `testnet3-18333-qt.command`: GUI for testnet.
  - `regtest-*-qt.command`: GUI for regtest (Alice/Bob/Carol).
  - `-clean` variants: Reset data before launch.
- `electrum/`: Electrum scripts (.command).
  - `mainnet.command`: Standard mainnet.
  - `mainnet-local-server-only.command`: Connects to local server.
  - `testnet.command`, `regtest.command`: For test/regtest networks.
- `utilities/`: Maintenance scripts (updates, verification, cleanup, logs).

## Usage

Run `.command` files by double-clicking or from Terminal: `bash bitcoin/mainnet-8333-qt.command`.

Scripts include error checks and will prompt for confirmations on data deletion.

Root launchers are available for specific areas: `Bitcoin-Launcher.*`, `Electrum-Launcher.*`, and `Utilities-Launcher.*` (`.command` or `.sh`).

## Customization

Set `PORTANODE_ROOT` to override paths: `export PORTANODE_ROOT=/custom/path`.
