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
icacls "%BDD%" /inheritance:r /grant "%USERDOMAIN%\%USERNAME%:(OI)(CI)F" /t >nul
icacls "%EDD%" /inheritance:r /grant "%USERDOMAIN%\%USERNAME%:(OI)(CI)F" /t >nul

REM exFAT and FAT32 hold no ACL at all: the icacls calls above ran and
REM exited 0 regardless, with nothing on disk to show for either. Read back
REM each data directory's own filesystem and say which case it is in,
REM instead of an unconditional "Permissions set."
call :report_permission_effect "%BDD%"
call :report_permission_effect "%EDD%"
exit /b 0

:report_permission_effect
set "TARGET=%~1"
set "FS_NAME="
for /f "usebackq delims=" %%F in (`powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT_DIR%filesystem-type.ps1" -Path "%TARGET%"`) do set "FS_NAME=%%F"
if not defined FS_NAME (
    echo Warning: could not determine the filesystem of %TARGET%; assuming
    echo the icacls above took effect.
    exit /b 0
)
if /i "%FS_NAME%"=="NTFS" (
    echo %TARGET% is on an NTFS volume: permissions restricted to
    echo %USERDOMAIN%\%USERNAME%.
) else (
    echo Warning: %TARGET% is on a %FS_NAME% volume, which does not store
    echo ACLs. icacls above changed nothing on disk; the directory is
    echo still readable by anyone with access to the volume. Restrict
    echo access with encryption or physical control of the device instead.
)
exit /b 0
