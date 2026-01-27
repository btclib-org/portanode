@echo off
REM Verify PortaNode binaries against win/checksums.sha256

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"
set CHECKSUM_FILE=%ROOTDIR%\win/checksums.sha256

pushd "%ROOTDIR%" >nul 2>&1

if not exist "%CHECKSUM_FILE%" (
    echo Error: %CHECKSUM_FILE% not found.
    popd >nul 2>&1
    exit /b 1
)

echo Verifying binaries...

powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT_DIR%verify-binaries.ps1" ^
  -RootDir "%ROOTDIR%"

set ERR=%ERRORLEVEL%
popd >nul 2>&1
exit /b %ERR%
