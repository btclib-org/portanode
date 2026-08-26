# Electrum Scripts (macOS)

macOS launch scripts for Electrum. Each script differs by network and
whether it restricts connections to a local Electrum server only.

## Differences by script

- `mainnet.command`: Mainnet, standard server connections.
- `testnet3.command`: Testnet3, standard server connections.
- `testnet4.command`: Testnet4, standard server connections.
- `regtest.command`: Regtest, standard server connections (typically local).
- `mainnet-local-server-only.command`: Mainnet, connects only to a local
  Electrum server.

## Prerequisites

- Electrum app bundle in `macos/bin/Electrum.app`.
- Data directory in `electrum-datadir/`.
- For local server mode, a local Electrum server must be running.
- Note: Some Electrum builds expose `run_electrum` instead of `Electrum` inside
  the app bundle. The launcher scripts accept either.

## Running two mainnet launchers against the same datadir

`mainnet.command` and `mainnet-local-server-only.command` pass the
same `--dir electrum-datadir` and open the identical mainnet state kept
at the top level of that directory, the way the Linux pair
(`linux/scripts/electrum/README.md`) does. What was measured there:
starting the second launcher while the first is still running produces
no process of its own, and a `daemon`/`daemon_rpc_socket` left behind
by a terminated first instance does not, by itself, stop the other
from starting. Neither launcher checks for a running sibling before
starting, on any platform, so the same effect is expected here; it has
not been measured on macOS itself. Stop one of the two before starting
the other.
