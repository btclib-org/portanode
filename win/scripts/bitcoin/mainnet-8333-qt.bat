@echo off
setlocal
REM Launch Bitcoin Core GUI for mainnet.
REM Data directory: bitcoin-datadir
REM P2P port: 8333
REM
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
echo ROOTDIR is "%ROOTDIR%"

if not exist "%ROOTDIR%\win\bin\bitcoin-qt.exe" (
    echo Error: Binary not found at "%ROOTDIR%\win\bin\bitcoin-qt.exe"
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

call "%SCRIPT_DIR%lib.bat" :require_no_mainnet_node
if errorlevel 1 (
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

start "" "%ROOTDIR%\win\bin\bitcoin-qt.exe" -uacomment=%~n0 ^
-datadir="%ROOTDIR%\bitcoin-datadir"
