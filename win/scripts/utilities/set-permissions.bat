@echo off
setlocal enabledelayedexpansion
REM Set restrictive permissions for PortaNode data directories (Windows)

set SCRIPT_DIR=%~dp0
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR

set BDD=%ROOTDIR%\bitcoin-datadir
set EDD=%ROOTDIR%\electrum-datadir

if not exist "%BDD%" (
    echo Error: bitcoin-datadir not found.
    exit /b 1
)
if not exist "%EDD%" (
    echo Error: electrum-datadir not found.
    exit /b 1
)

echo Setting restrictive permissions on data directories...
icacls "%BDD%" /inheritance:r /grant "%USERNAME%:(OI)(CI)F" /t >nul
icacls "%EDD%" /inheritance:r /grant "%USERNAME%:(OI)(CI)F" /t >nul
echo Permissions set.
exit /b 0
