# Binaries

Place the executables here:

- `bitcoind`
- `bitcoin-cli`
- `bitcoin-qt`
- `bitcoin-tx`
- `bitcoin-util`
- `bitcoin-wallet`
- `bitcoin`
- `electrum.AppImage`

These executables are launched by the scripts in `linux/scripts/`.
Update scripts store backups in `backup/`.

Bitcoin Core's Linux release publishes the daemon, the CLI tools and
`bitcoin-qt` together in one archive, so `update-bitcoin.sh` installs
them all from that single download rather than fetching the GUI and
the command-line tools separately. `electrum.AppImage` is a fixed,
version-independent name; `update-electrum.sh` installs the downloaded
AppImage under this name unmodified, run directly rather than
extracted.
