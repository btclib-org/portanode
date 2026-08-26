@echo off
setlocal
REM Launch Bitcoin Core GUI for regtest as Bob (clean start).
REM Removes and recreates regtest_bob data directory.
REM Data directory: bitcoin-datadir\regtest_bob
REM P2P port: 18555
REM RPC port: 18554
REM Network: regtest
REM Connects to: localhost:18444 (Alice), localhost:18666 (Carol)
REM
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
echo ROOTDIR is "%ROOTDIR%"

if not exist "%ROOTDIR%\win\bin\bitcoin-qt.exe" (
    echo Error: Binary not found at "%ROOTDIR%\win\bin\bitcoin-qt.exe"
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

call "%SCRIPT_DIR%lib.bat" :require_datadir_free ^
  "bitcoin-datadir\regtest_bob"
if errorlevel 1 (
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

echo WARNING: This will delete regtest data.
echo Press Enter to continue or Ctrl+C to cancel.
pause

call "%SCRIPT_DIR%lib.bat" :require_deleted "bitcoin-datadir\regtest_bob"
if errorlevel 1 (
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)
mkdir "%ROOTDIR%\bitcoin-datadir\regtest_bob"

set "DATADIR=%ROOTDIR%\bitcoin-datadir\regtest_bob"
set "NETDIR=%DATADIR%\regtest"
set "BLOCKCHAINDIR=%NETDIR%\blocks"
REM Bitcoin Core creates the wallets subfolder along with the network
REM directory itself, and wallet code then uses it; wallet code never
REM creates one, so the network directory is the wallet directory only
REM where it already exists without a wallets subfolder beside it.
REM Computed after the wipe above rather than beside the ROOTDIR echo: a
REM network directory standing there without a wallets subfolder is the one
REM state that answers with the directory itself, and the wipe is what takes
REM that state away, so reading it earlier would answer for a directory about
REM to be deleted.
set "WALLETDIR=%NETDIR%\wallets"
if exist "%NETDIR%\" if not exist "%NETDIR%\wallets\" set "WALLETDIR=%NETDIR%"
echo DATADIR is "%DATADIR%"
echo BLOCKCHAINDIR is "%BLOCKCHAINDIR%"
echo WALLETDIR is "%WALLETDIR%"

REM Bitcoin Core's regtest RPC port defaults to 18443 regardless of -port, so
REM Alice, Bob and Carol running concurrently would each try to bind RPC on
REM 18443 without an explicit -rpcport. This one is Bob's, distinct from
REM Alice's default and from Carol's, following the P2P-minus-one spacing
REM Bitcoin Core itself uses between a network's own P2P and RPC ports
REM (8333/8332, 18333/18332, 18444/18443).
start "" "%ROOTDIR%\win\bin\bitcoin-qt.exe" ^
  -uacomment=%~n0 ^
  -datadir="%DATADIR%" ^
  -regtest ^
  -port=18555 ^
  -rpcport=18554 ^
  -addnode=localhost:18444 ^
  -addnode=localhost:18666
