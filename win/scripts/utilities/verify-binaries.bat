@echo off
REM Verify binaries against win/checksums.sha256

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"
set CHECKSUM_FILE=win/checksums.sha256

pushd "%ROOTDIR%" >nul 2>&1

echo Verifying binaries against %CHECKSUM_FILE%

if not exist "%ROOTDIR%\%CHECKSUM_FILE%" (
    echo Error: %CHECKSUM_FILE% not found.
    popd >nul 2>&1
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT_DIR%verify-binaries.ps1" ^
  -RootDir "%ROOTDIR%"

set ERR=%ERRORLEVEL%
popd >nul 2>&1
exit /b %ERR%
