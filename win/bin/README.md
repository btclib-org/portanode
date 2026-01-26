# Windows Binaries

Place the Windows executables here:

- `bitcoin-qt.exe`
- `bitcoind.exe`
- `bitcoin-cli.exe`
- `bitcoin-tx.exe`
- `bitcoin-util.exe`
- `bitcoin-wallet.exe`
- `bitcoin.exe`
- `electrum.exe`

These executables are launched by the scripts in `win/scripts/`.

The Bitcoin Core helpers (`bitcoin-cli.exe`, `bitcoin-tx.exe`, `bitcoin-util.exe`,
`bitcoin-wallet.exe`, `bitcoin.exe`) are included because several scripts and
health checks assume they exist alongside `bitcoind.exe` and `bitcoin-qt.exe`.
