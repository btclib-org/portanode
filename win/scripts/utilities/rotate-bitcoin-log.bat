@echo off
setlocal disabledelayedexpansion
REM Rotate Bitcoin debug log (Windows)

REM Explicitly disabled on line 2 rather than merely not enabled, so
REM the guarantee holds regardless of what a caller set. cmd.exe runs
REM its delayed-expansion pass after percent expansion, so with it on
REM an unmatched "!" is stripped out of the expanded "%~dp0" below and
REM out of every path built on ROOTDIR, and a folder mounted at a path
REM holding one is legal on exFAT and NTFS alike (#374).
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
REM One rotation per call rather than the "( )" body this replaced:
REM with delayed expansion off, a "%NEXT%" read inside that body is
REM expanded when cmd.exe parses the whole block, before "set /a" has
REM run, so the rename target would be "debug.log.". Each line of
REM :rotate_one is its own statement, expanded at the moment it runs.
for /l %%I in (%START%,-1,1) do call :rotate_one %%I

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

REM :rotate_one INDEX -- rename debug.log.INDEX to debug.log.INDEX+1
:rotate_one
if not exist "%LOG_FILE%.%1" goto :eof
set /a NEXT=%1+1
ren "%LOG_FILE%.%1" "debug.log.%NEXT%"
goto :eof
