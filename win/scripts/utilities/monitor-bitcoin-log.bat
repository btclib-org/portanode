@echo off
setlocal enabledelayedexpansion
REM Monitor Bitcoin log for errors (Windows)

set SCRIPT_DIR=%~dp0
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
call "%SCRIPT_DIR%lib.bat" :rootdir_arg "%ROOTDIR%" ROOTDIR_ARG

set LOG_FILE=%ROOTDIR%\bitcoin-datadir\debug.log

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
    echo Log file not found: %LOG_FILE%
    exit /b 0
)

powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT_DIR%monitor-bitcoin-log.ps1" ^
  -RootDir "%ROOTDIR_ARG%" %NO_NOTIFY_ARG%

exit /b 0
