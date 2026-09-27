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
REM Each step stops the run where it fails, before a later one
REM overwrites or empties what it would have kept: a failed ren leaves
REM debug.log.N for the copy below to overwrite, and a failed copy
REM leaves Clear-Content discarding the only copy of the log. The offset
REM file goes only once the log has been emptied, and the exit status
REM is the rotation's.
for /l %%I in (%START%,-1,1) do call :rotate_one %%I || goto :rotate_failed

REM Built as one physical line -- see :update_checksum in
REM win/scripts/utilities/lib.bat (#144) on why a caret split across a
REM powershell -Command block's open quote is not a continuation.
REM Values reach PowerShell as $env: reads: see :install_verified in
REM lib.bat (#578). Copy-Item's and Clear-Content's errors are
REM non-terminating, which leaves powershell.exe exiting 0 after one, so
REM each carries -ErrorAction Stop and a catch that exits 1, as the
REM updaters' downloads do (#364).
powershell -NoProfile -Command "& { try { Copy-Item -Force -LiteralPath $env:LOG_FILE -Destination ($env:LOG_FILE + '.1') -ErrorAction Stop } catch { Write-Host ('Error: copying bitcoin-datadir\debug.log to debug.log.1 failed: ' + $_.Exception.Message); Write-Host 'debug.log was not rotated.'; exit 1 } try { Clear-Content -LiteralPath $env:LOG_FILE -ErrorAction Stop } catch { Write-Host ('Error: emptying bitcoin-datadir\debug.log failed: ' + $_.Exception.Message); Write-Host 'Its content is also in debug.log.1.'; exit 1 } }"
if errorlevel 1 goto :rotate_failed

REM The monitor's stored offset is now past the end of the truncated file;
REM clear it here rather than leaving the monitor to catch the mismatch on
REM its next run, which is a race it can lose (see monitor-bitcoin-log.ps1).
if exist "%ROOTDIR%\.last_log_offset" del /f /q "%ROOTDIR%\.last_log_offset"

echo Log rotated: bitcoin-datadir\debug.log
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b 0

:rotate_failed
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b 1

REM :rotate_one INDEX -- rename debug.log.INDEX to debug.log.INDEX+1
REM ren refuses a target that exists, where mv on the POSIX half
REM replaces it, so the oldest archive is deleted first. Only the top
REM index can find one: every lower target was renamed away by the call
REM before.
:rotate_one
if not exist "%LOG_FILE%.%1" exit /b 0
set /a NEXT=%1+1
if exist "%LOG_FILE%.%NEXT%" del /f /q "%LOG_FILE%.%NEXT%"
if exist "%LOG_FILE%.%NEXT%" (
    echo Error: deleting bitcoin-datadir\debug.log.%NEXT% failed; debug.log was not rotated.
    exit /b 1
)
ren "%LOG_FILE%.%1" "debug.log.%NEXT%"
if errorlevel 1 (
    echo Error: renaming bitcoin-datadir\debug.log.%1 failed; debug.log was not rotated.
    exit /b 1
)
exit /b 0
