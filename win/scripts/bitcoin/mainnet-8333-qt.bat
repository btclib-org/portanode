@echo off
setlocal disabledelayedexpansion
REM Launch Bitcoin Core GUI for mainnet.
REM Data directory: bitcoin-datadir
REM P2P port: 8333
REM
REM Explicitly disabled on line 2 rather than merely not enabled: a bare
REM "setlocal" keeps whatever state the caller left the pass at, and the
REM caller here is the console this was started from. The measurement is
REM in win\scripts\root.bat, above :resolve_root (#473).
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
echo ROOTDIR is "%ROOTDIR%"
set "DATADIR=%ROOTDIR%\bitcoin-datadir"
set "NETDIR=%DATADIR%"
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
    echo Error: Binary not found at "win\bin\bitcoin-qt.exe"
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

call "%SCRIPT_DIR%lib.bat" :require_no_mainnet_node
if errorlevel 1 (
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

start "" "%ROOTDIR%\win\bin\bitcoin-qt.exe" -uacomment=%~n0 ^
-datadir="%DATADIR%"
