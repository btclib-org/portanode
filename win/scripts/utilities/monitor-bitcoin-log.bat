@echo off
setlocal enabledelayedexpansion
REM Monitor Bitcoin log for errors (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"

set LOG_FILE=%ROOTDIR%\bitcoin-datadir\debug.log
set LAST_CHECK_FILE=%ROOTDIR%\.last_log_check

if not exist "%LOG_FILE%" (
    echo Log file not found: %LOG_FILE%
    exit /b 0
)

powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT_DIR%monitor-bitcoin-log.ps1" ^
  -RootDir "%ROOTDIR%"

exit /b 0
