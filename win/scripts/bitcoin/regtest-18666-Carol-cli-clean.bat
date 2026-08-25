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

rmdir "%ROOTDIR%\bitcoin-datadir\regtest_carol" /s /q
mkdir "%ROOTDIR%\bitcoin-datadir\regtest_carol"

start "" cmd /k ^
  ""%ROOTDIR%\win\bin\bitcoind.exe" -uacomment=%~n0 ^
  -datadir="%ROOTDIR%\bitcoin-datadir\regtest_carol" ^
  -regtest -port=18666 -rpcport=18665 -rpcallowip=127.0.0.1 ^
  -addnode=localhost:18444 ^
  -addnode=localhost:18555"
start "" cmd /k ^
  "cd /d "%ROOTDIR%\win\bin" & ^
  title %~n0 & ^
  doskey btc=bitcoin-cli.exe -regtest -datadir="%ROOTDIR%\bitcoin-datadir\regtest_carol" -rpcport=18665 $*"
