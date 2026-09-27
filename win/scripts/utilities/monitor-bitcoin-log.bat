@echo off
setlocal disabledelayedexpansion
REM Monitor Bitcoin log for errors (Windows)

REM Explicitly disabled on line 2 rather than merely not enabled, so
REM the guarantee holds regardless of what a caller set. cmd.exe runs
REM its delayed-expansion pass after percent expansion, so with it on
REM an unmatched "!" is stripped out of the expanded "%~dp0" below and
REM out of every path built on ROOTDIR, and a folder mounted at a path
REM holding one is legal on exFAT and NTFS alike (#374). Nothing here
REM reads a bang-delimited variable, so disabling it outright costs
REM nothing.
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR

set "LOG_FILE=%ROOTDIR%\bitcoin-datadir\debug.log"

set "NO_NOTIFY_ARG="
:parse_args
if "%~1"=="" goto :args_done
if "%~1"=="--no-notify" (
    set "NO_NOTIFY_ARG=-NoNotify"
    shift
    goto :parse_args
)
echo Usage: %~nx0 [--no-notify]
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b 1
:args_done

if not exist "%LOG_FILE%" (
    echo Log file not found: bitcoin-datadir\debug.log
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 0
)

REM Run from its own directory by a relative name: win/scripts/root.ps1
REM says why, and the values arrive as $env: reads.
powershell -NoProfile -ExecutionPolicy Bypass ^
  -Command "Set-Location -LiteralPath $env:SCRIPT_DIR -ErrorAction Stop; & .\monitor-bitcoin-log.ps1 -RootDir $env:ROOTDIR %NO_NOTIFY_ARG%; exit $LASTEXITCODE"
set "ERR=%ERRORLEVEL%"

call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b %ERR%
