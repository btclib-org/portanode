# Bitcoin Core Scripts

Launch scripts for Bitcoin Core.
Each script differs by network,
for regtest,
there are scripts with different node identity and port
to allow more nodes on the same device,
and whether it starts with a clean data folder.

## Differences by script

- `mainnet-8333-qt.bat`: Mainnet, GUI (QT), P2P port 8333.
- `testnet3-18333-qt.bat`: Testnet3, GUI (QT), P2P port 18333.
- `regtest-18444-Alice-qt.bat`: Regtest GUI for Alice, port 18444.
- `regtest-18444-Alice-qt-clean.bat`: Same as above, but deletes the
  data directory before starting.
- `regtest-18444-Alice-cli.bat`: Regtest CLI for Alice, port 18444.
- `regtest-18444-Alice-cli-clean.bat`: Same as above, clean start.
- `regtest-18555-Bob-qt.bat`: Regtest GUI for Bob, port 18555.
- `regtest-18555-Bob-qt-clean.bat`: Same as above, clean start.
- `regtest-18666-Carol-qt.bat`: Regtest GUI for Carol, port 18666.
- `regtest-18666-Carol-qt-clean.bat`: Same as above, clean start.

Regtest scripts run isolated nodes with fixed ports and connect peers on
localhost. Alice uses the default regtest folder under `bitcoin-datadir`,
while Bob and Carol use `regtest_bob` and `regtest_carol` subfolders.

Peer connections (addnode targets):
- Alice (18444) connects to Bob (18555) and Carol (18666).
- Bob (18555) connects to Alice (18444) and Carol (18666).
- Carol (18666) connects to Alice (18444) and Bob (18555).

## Prerequisites

- Bitcoin Core executables in `win/bin/` (e.g., `bitcoin-qt.exe`,
  `bitcoind.exe`, `bitcoin-cli.exe`).
