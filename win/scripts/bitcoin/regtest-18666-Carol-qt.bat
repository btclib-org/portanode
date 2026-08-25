@echo off
setlocal
REM Launch Bitcoin Core GUI for regtest as Carol.
REM Data directory: bitcoin-datadir\regtest_carol
REM P2P port: 18666
REM RPC port: 18665
REM Network: regtest
REM Creates data directory if not exists.
REM Connects to: localhost:18444 (Alice), localhost:18555 (Bob)
REM
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
echo ROOTDIR is "%ROOTDIR%"
set "DATADIR=%ROOTDIR%\bitcoin-datadir\regtest_carol"
set "NETDIR=%DATADIR%\regtest"
set "BLOCKCHAINDIR=%NETDIR%\blocks"
REM Bitcoin Core creates the wallets subfolder along with the network
REM directory itself, and wallet code then uses it; wallet code never
REM creates one, so the network directory is the wallet directory only
REM where it already exists without a wallets subfolder beside it.
set "WALLETDIR=%NETDIR%\wallets"
if exist "%NETDIR%\" if not exist "%NETDIR%\wallets\" set "WALLETDIR=%NETDIR%"
echo DATADIR is "%DATADIR%"
echo BLOCKCHAINDIR is "%BLOCKCHAINDIR%"
echo WALLETDIR is "%WALLETDIR%"

if not exist "%ROOTDIR%\win\bin\bitcoin-qt.exe" (
    echo Error: Binary not found at "%ROOTDIR%\win\bin\bitcoin-qt.exe"
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

if not exist "%ROOTDIR%\bitcoin-datadir\regtest_carol\" (
    mkdir "%ROOTDIR%\bitcoin-datadir\regtest_carol"
)


REM Bitcoin Core's regtest RPC port defaults to 18443 regardless of -port, so
REM Alice, Bob and Carol running concurrently would each try to bind RPC on
REM 18443 without an explicit -rpcport. This one is Carol's, distinct from
REM Alice's default and from Bob's, following the P2P-minus-one spacing
REM Bitcoin Core itself uses between a network's own P2P and RPC ports
REM (8333/8332, 18333/18332, 18444/18443).
start "" "%ROOTDIR%\win\bin\bitcoin-qt.exe" ^
  -uacomment=%~n0 ^
  -datadir="%DATADIR%" ^
  -regtest ^
  -port=18666 ^
  -rpcport=18665 ^
  -addnode=localhost:18444 ^
  -addnode=localhost:18555
