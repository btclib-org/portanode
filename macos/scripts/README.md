# Scripts

Entry point for launch scripts.

## Folders

- `bitcoin/`: Bitcoin Core scripts (.command).
    - `mainnet-8333-qt.command`: GUI for mainnet.
    - `testnet3-18333-qt.command`: GUI for testnet3.
    - `testnet4-48333-qt.command`: GUI for testnet4.
    - `regtest-*-qt.command`: GUI for regtest (Alice/Bob/Carol).
    - `regtest-*-cli.command`: Daemon + CLI for regtest.
    - `-clean` variants: Reset data before launch.
- `electrum/`: Electrum scripts (.command).
    - `mainnet.command`: Standard mainnet.
    - `mainnet-local-server-only.command`: Connects to local server.
    - `testnet3.command`, `testnet4.command`, `regtest.command`: For test
      and regtest networks.
- `utilities/`: Maintenance scripts (updates, verification, cleanup, logs).

## Usage

Run `.command` files by double-clicking or from Terminal:
`bash bitcoin/mainnet-8333-qt.command`.

Scripts include error checks and will prompt for confirmations on data deletion.

Root launchers are available for specific areas: `Bitcoin-Launcher.*`,
`Electrum-Launcher.*`, and `Utilities-Launcher.*` (`.command` or `.sh`).

## Customization

Set `PORTANODE_ROOT` to override paths: `export PORTANODE_ROOT=/custom/path`.
