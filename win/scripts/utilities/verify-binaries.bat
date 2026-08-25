@echo off
setlocal
REM Verify binaries against win/checksums.sha256

set SCRIPT_DIR=%~dp0
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
call "%SCRIPT_DIR%lib.bat" :rootdir_arg "%ROOTDIR%" ROOTDIR_ARG
set CHECKSUM_FILE=win/checksums.sha256

pushd "%ROOTDIR%" >nul 2>&1

echo Verifying binaries against %CHECKSUM_FILE%

if not exist "%ROOTDIR%\%CHECKSUM_FILE%" (
    echo Error: %CHECKSUM_FILE% not found.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT_DIR%verify-binaries.ps1" ^
  -RootDir "%ROOTDIR_ARG%"

set ERR=%ERRORLEVEL%
popd >nul 2>&1
if not "%ERR%"=="0" call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b %ERR%
