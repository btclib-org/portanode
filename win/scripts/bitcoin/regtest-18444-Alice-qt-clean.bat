@echo off
setlocal
REM Launch Bitcoin Core GUI for regtest as Alice (clean start).
REM Removes the regtest data directory.
REM Data directory: bitcoin-datadir
REM P2P port: 18444
REM Network: regtest
REM Connects to: localhost:18555 (Bob), localhost:18666 (Carol)
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
  "%ROOTDIR%\bitcoin-datadir" -regtest
if errorlevel 1 (
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

echo WARNING: This will delete regtest data.
echo Press any key to continue or Ctrl+C to cancel.
pause

rmdir "%ROOTDIR%\bitcoin-datadir\regtest" /s /q

start "" "%ROOTDIR%\win\bin\bitcoin-qt.exe" ^
  -uacomment=%~n0 ^
  -datadir="%ROOTDIR%\bitcoin-datadir" ^
  -regtest ^
  -addnode=localhost:18555 ^
  -addnode=localhost:18666
