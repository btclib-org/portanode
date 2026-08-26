# Scripts

Entry point for Linux launch scripts.

## Folders

- `bitcoin/`: Bitcoin Core scripts (.sh).
    - `mainnet-8333-qt.sh`: GUI for mainnet.
    - `testnet3-18333-qt.sh`: GUI for testnet3.
    - `testnet4-48333-qt.sh`: GUI for testnet4.
    - `regtest-*-qt.sh`: GUI for regtest (Alice/Bob/Carol).
    - `regtest-*-cli.sh`: Daemon + CLI for regtest.
    - `-clean` variants: Reset data before launch.
- `electrum/`: Electrum scripts (.sh).
    - `mainnet.sh`: Standard mainnet.
    - `mainnet-local-server-only.sh`: Connects to local server.
    - `testnet3.sh`, `testnet4.sh`, `regtest.sh`: For test and regtest
      networks.
- `utilities/`: Maintenance scripts (updates, verification, cleanup, logs).
- `lib.sh` and `utilities/lib.sh`: forward to the root-resolution and the
  download/PGP/checksum helpers under `shared/`, the paths the scripts
  under `electrum/` and `utilities/` source them by.

## Usage

Run a `.sh` file with `bash`: `bash bitcoin/mainnet-8333-qt.sh`.

Scripts include error checks and will prompt for confirmations on data
deletion.

The root `Bitcoin-Launcher.sh`, `Electrum-Launcher.sh` and
`Utilities-Launcher.sh` each refuse Linux rather than reaching this
directory, so a script under `bitcoin/`, `electrum/` or `utilities/` is
run by its own path.

## Customization

Set `PORTANODE_ROOT` to override paths: `export PORTANODE_ROOT=/custom/path`.
