@echo off
setlocal
REM Launch Bitcoin Core daemon for regtest as Carol (clean start).
REM Removes and recreates regtest_carol data directory.
REM Data directory: bitcoin-datadir\regtest_carol
REM P2P port: 18666
REM RPC port: 18665
REM Network: regtest
REM RPC: allowed from 127.0.0.1
REM Starts daemon and CLI command prompts.
REM Connects to: localhost:18444 (Alice), localhost:18555 (Bob)
REM
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
echo ROOTDIR is "%ROOTDIR%"

if not exist "%ROOTDIR%\win\bin\bitcoind.exe" (
    echo Error: Binary not found at "%ROOTDIR%\win\bin\bitcoind.exe"
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

call "%SCRIPT_DIR%lib.bat" :require_datadir_free ^
  "%ROOTDIR%\bitcoin-datadir\regtest_carol"
if errorlevel 1 (
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

echo WARNING: This will delete regtest data.
echo Press Enter to continue or Ctrl+C to cancel.
pause

call "%SCRIPT_DIR%lib.bat" :require_deleted "%ROOTDIR%\bitcoin-datadir\regtest_carol"
if errorlevel 1 (
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)
mkdir "%ROOTDIR%\bitcoin-datadir\regtest_carol"

set "DATADIR=%ROOTDIR%\bitcoin-datadir\regtest_carol"
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

start "" cmd /k ^
  ""%ROOTDIR%\win\bin\bitcoind.exe" -uacomment=%~n0 ^
  -datadir="%DATADIR%" ^
  -regtest -port=18666 -rpcport=18665 -rpcallowip=127.0.0.1 ^
  -addnode=localhost:18444 ^
  -addnode=localhost:18555"
start "" cmd /k ^
  "cd /d "%ROOTDIR%\win\bin" & ^
  title %~n0 & ^
  doskey btc=bitcoin-cli.exe -regtest -datadir="%DATADIR%" -rpcport=18665 $*"
