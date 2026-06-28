# Binaries

Place the app bundles here:

- `Bitcoin-Qt.app`
- `Electrum.app`

These apps are launched by the scripts in `macos/scripts/`.
Update scripts store backups in `backup/` and temporary downloads in
`.tmp-downloads/`.

The Bitcoin updater also installs the command-line tools here (`bitcoind`,
`bitcoin-cli`, `bitcoin-qt`, `bitcoin-tx`, `bitcoin-util`, `bitcoin-wallet`),
which the `.app` GUI bundle does not ship. The health check uses `bitcoin-cli`
to read sync status.
