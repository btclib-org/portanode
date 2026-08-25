@echo off
setlocal
REM Launch Bitcoin Core daemon for regtest as Alice.
REM Data directory: bitcoin-datadir
REM P2P port: 18444
REM Network: regtest
REM RPC: allowed from 127.0.0.1
REM Starts daemon and CLI command prompts.
REM Connects to: localhost:18555 (Bob), localhost:18666 (Carol)
REM
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
echo ROOTDIR is "%ROOTDIR%"
set "DATADIR=%ROOTDIR%\bitcoin-datadir"
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

if not exist "%ROOTDIR%\win\bin\bitcoind.exe" (
    echo Error: Binary not found at "%ROOTDIR%\win\bin\bitcoind.exe"
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

rem rmdir "%ROOTDIR%\bitcoin-datadir\regtest" /s /q

start "" cmd /k ^
  ""%ROOTDIR%\win\bin\bitcoind.exe" -uacomment=%~n0 ^
  -datadir="%DATADIR%" ^
  -regtest -rpcallowip=127.0.0.1 ^
  -addnode=localhost:18555 ^
  -addnode=localhost:18666"
start "" cmd /k ^
  "cd /d "%ROOTDIR%\win\bin" & ^
  title %~n0 & ^
  doskey btc=bitcoin-cli.exe -regtest -datadir="%DATADIR%" $*"
