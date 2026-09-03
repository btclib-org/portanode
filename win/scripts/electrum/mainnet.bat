@echo off
setlocal
REM Launch Electrum for mainnet.
REM Data directory: electrum-datadir
REM Network: mainnet
REM
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
echo ROOTDIR is "%ROOTDIR%"

if not exist "%ROOTDIR%\win\bin\electrum.exe" (
    echo Error: Binary not found at "win\bin\electrum.exe"
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

call "%SCRIPT_DIR%lib.bat" :require_non_portable_build ^
  "%ROOTDIR%\win\bin\electrum.exe"
if errorlevel 1 (
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

start "" "%ROOTDIR%\win\bin\electrum.exe" --dir "%ROOTDIR%\electrum-datadir"
