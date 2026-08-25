@echo off
setlocal
REM Launch Bitcoin Core GUI for regtest as Alice.
REM Data directory: bitcoin-datadir
REM P2P port: 18444
REM Network: regtest
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

if not exist "%ROOTDIR%\win\bin\bitcoin-qt.exe" (
    echo Error: Binary not found at "%ROOTDIR%\win\bin\bitcoin-qt.exe"
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

rem rmdir "%ROOTDIR%\bitcoin-datadir\regtest" /s /q

start "" "%ROOTDIR%\win\bin\bitcoin-qt.exe" ^
  -uacomment=%~n0 ^
  -datadir="%DATADIR%" ^
  -regtest ^
  -addnode=localhost:18555 ^
  -addnode=localhost:18666
