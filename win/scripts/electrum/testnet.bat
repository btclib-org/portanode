@echo off
setlocal
REM Launch Electrum for testnet.
REM Data directory: electrum-datadir
REM Network: testnet
REM
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
echo ROOTDIR is "%ROOTDIR%"

if not exist "%ROOTDIR%\win\bin\electrum.exe" (
    echo Error: Binary not found at "%ROOTDIR%\win\bin\electrum.exe"
    exit /b 1
)

start "" "%ROOTDIR%\win\bin\electrum.exe" ^
--dir "%ROOTDIR%\electrum-datadir" --testnet
