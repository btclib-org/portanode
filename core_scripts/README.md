# Core Scripts

This folder contains scripts to launch Bitcoin Core in various network
configurations and modes.

## Overview

Bitcoin Core is the reference implementation of the Bitcoin protocol. These
scripts simplify launching Bitcoin Core with different settings for
development, testing, and production use.

## Networks

- **Mainnet**: The live Bitcoin network.
- **Testnet3**: The test network for Bitcoin.
- **Regtest**: A local regression test network for development and testing.

## Nodes

For regtest, multiple nodes are configured (Alice, Bob, Carol) to simulate a
multi-node network for testing purposes.

## Modes

- **QT**: Graphical User Interface (GUI) mode.
- **CLI**: Command-Line Interface mode (Windows only for some scripts).
- **Clean**: Resets the data directory before launching (useful for fresh
  starts).

## macOS Scripts (macos/ folder)

Run these by double-clicking the .command files or executing them in
Terminal.

- `mainnet-8333-qt.command`: Launch GUI on mainnet (port 8333).
- `testnet3-18333-qt.command`: Launch GUI on testnet3 (port 18333).
- `regtest-18444-Alice-qt.command`: Launch GUI on regtest for Alice (port
  18444).
- `regtest-18444-Alice-qt-clean.command`: Launch GUI on regtest for Alice
  with clean data.
- `regtest-18555-Bob-qt.command`: Launch GUI on regtest for Bob (port
  18555).
- `regtest-18555-Bob-qt-clean.command`: Launch GUI on regtest for Bob with
  clean data.
- `regtest-18666-Carol-qt.command`: Launch GUI on regtest for Carol (port
  18666).
- `regtest-18666-Carol-qt-clean.command`: Launch GUI on regtest for Carol
  with clean data.

## Windows Scripts (win/ folder)

Run these by double-clicking the .bat files or executing them in Command
Prompt.

- `mainnet-8333-qt.bat`: Launch GUI on mainnet (port 8333).
- `testnet3-18333-qt.bat`: Launch GUI on testnet3 (port 18333).
- `regtest-18444-Alice-cli-clean.bat`: Launch CLI on regtest for Alice with
  clean data.
- `regtest-18444-Alice-cli.bat`: Launch CLI on regtest for Alice.
- `regtest-18444-Alice-qt-clean.bat`: Launch GUI on regtest for Alice with
  clean data.
- `regtest-18444-Alice-qt.bat`: Launch GUI on regtest for Alice.
- `regtest-18555-Bob-qt-clean.bat`: Launch GUI on regtest for Bob with clean
  data.
- `regtest-18555-Bob-qt.bat`: Launch GUI on regtest for Bob.
- `regtest-18666-Carol-qt-clean.bat`: Launch GUI on regtest for Carol with
  clean data.
- `regtest-18666-Carol-qt.bat`: Launch GUI on regtest for Carol.

## Prerequisites

- Bitcoin Core must be installed and available in your PATH.
- For regtest, ensure ports 18444, 18555, 18666 are available.
- Data directories will be created automatically in the appropriate
  locations.

## Usage

1. Navigate to the appropriate OS folder (macos/ or win/).
2. Run the desired script.
3. For GUI modes, the Bitcoin Core window will open.
4. For CLI modes, Bitcoin Core will run in the terminal/command prompt.

## Troubleshooting

- If ports are in use, stop other Bitcoin Core instances or change ports in
  the scripts.
- For clean versions, existing data will be removed - backup important data
  first.
- Ensure Bitcoin Core is properly installed and configured.