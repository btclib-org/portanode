@echo off
setlocal enabledelayedexpansion
REM Rotate Bitcoin debug log (Windows)

set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR

set "LOG_FILE=%ROOTDIR%\bitcoin-datadir\debug.log"
set MAX_ROTATIONS=5

if not exist "%LOG_FILE%" (
    echo Log file not found: bitcoin-datadir\debug.log
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 0
)

set /a START=%MAX_ROTATIONS%-1
for /l %%I in (%START%,-1,1) do (
    if exist "%LOG_FILE%.%%I" (
        set /a NEXT=%%I+1
        ren "%LOG_FILE%.%%I" "debug.log.!NEXT!"
    )
)

REM Built as one physical line -- see :update_checksum in
REM win/scripts/utilities/lib.bat (#144) on why a caret split across a
REM powershell -Command block's open quote is not a continuation.
powershell -NoProfile -Command "& { Copy-Item -Force '%LOG_FILE%' '%LOG_FILE%.1'; Clear-Content -Path '%LOG_FILE%' }"

REM The monitor's stored offset is now past the end of the truncated file;
REM clear it here rather than leaving the monitor to catch the mismatch on
REM its next run, which is a race it can lose (see monitor-bitcoin-log.ps1).
if exist "%ROOTDIR%\.last_log_offset" del /f /q "%ROOTDIR%\.last_log_offset"

echo Log rotated: bitcoin-datadir\debug.log
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b 0
