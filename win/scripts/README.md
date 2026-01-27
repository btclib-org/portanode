# Scripts

Entry point for launch scripts.

## Folders

- `bitcoin/`: Bitcoin Core scripts (.bat).
  - `mainnet-8333-qt.bat`: GUI for mainnet.
  - `testnet3-18333-qt.bat`: GUI for testnet.
  - `regtest-*-qt.bat`: GUI for regtest (Alice/Bob/Carol).
  - `regtest-*-cli.bat`: Daemon + CLI for regtest.
  - `-clean` variants: Reset data before launch.
- `electrum/`: Electrum scripts (.bat).
  - `mainnet.bat`: Standard mainnet.
  - `mainnet-local-server-only.bat`: Connects to local server.
  - `testnet.bat`, `regtest.bat`: For test/regtest networks.
- `utilities/`: Maintenance scripts (updates, verification, cleanup, logs).

## Usage

Run `.bat` files by double-clicking or from Command Prompt:
`bitcoin\mainnet-8333-qt.bat`.

Scripts include error checks and will prompt for confirmations on data deletion.

Root launchers are available for specific areas: `Bitcoin-Launcher.*`,
`Electrum-Launcher.*`, and `Utilities-Launcher.*` (`.bat` or `.ps1`).

## Customization

Set `PORTANODE_ROOT` to override paths: `set PORTANODE_ROOT=C:\custom\path`.
