@echo off
setlocal enabledelayedexpansion
REM Set restrictive permissions for PortaNode data directories (Windows)

set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR

set "BDD=%ROOTDIR%\bitcoin-datadir"
set "EDD=%ROOTDIR%\electrum-datadir"

if not exist "%BDD%" (
    echo Error: bitcoin-datadir not found.
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)
if not exist "%EDD%" (
    echo Error: electrum-datadir not found.
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

echo Setting restrictive permissions on data directories...
icacls "%BDD%" /inheritance:r /grant "%USERDOMAIN%\%USERNAME%:(OI)(CI)F" /t >nul
icacls "%EDD%" /inheritance:r /grant "%USERDOMAIN%\%USERNAME%:(OI)(CI)F" /t >nul

REM exFAT and FAT32 hold no ACL at all: the icacls calls above ran and
REM exited 0 regardless, with nothing on disk to show for either. Read back
REM each data directory's own filesystem and say which case it is in,
REM instead of an unconditional "Permissions set."
call :report_permission_effect "%BDD%" bitcoin-datadir
call :report_permission_effect "%EDD%" electrum-datadir
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b 0

REM Two arguments: the path filesystem-type.ps1 is handed, and the
REM ROOTDIR-relative name the messages use. The folder is mounted at a
REM different point on every machine it is plugged into, so a message
REM quoting the mount point tells the reader where this run happened
REM rather than which directory is meant. The name is passed in because
REM each caller holds it as a literal; cutting %ROOTDIR% off %TARGET%
REM instead needs the second parse of a "call set" (:rootdir_relative in
REM lib.bat) for a value that was never in doubt.
REM
REM The two "exit /b 0" below return from this "call" rather than ending
REM the script, so :pause_if_own_console belongs at the exit that ends
REM it and not here. Measured on windows-latest with the call added
REM before the "exit /b 0" that closes the NTFS/non-NTFS report, and
REM taken while the routine still ended in "pause": a double-click met
REM it once per data directory and again at the end. Each of those is
REM now a 30-second wait rather than a keypress, so the cost of putting
REM the call here is paid before the script has printed everything it
REM has to say.
:report_permission_effect
set "TARGET=%~1"
set "REL=%~2"
set "FS_NAME="
for /f "usebackq delims=" %%F in (`powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT_DIR%filesystem-type.ps1" -Path "%TARGET%"`) do set "FS_NAME=%%F"
if not defined FS_NAME (
    echo Warning: could not determine the filesystem of %REL%; assuming
    echo the icacls above took effect.
    exit /b 0
)
if /i "%FS_NAME%"=="NTFS" (
    echo %REL% is on an NTFS volume: permissions restricted to
    echo !USERDOMAIN!\!USERNAME!.
) else (
    echo Warning: %REL% is on a %FS_NAME% volume, which does not store
    echo ACLs. icacls above changed nothing on disk; the directory is
    echo still readable by anyone with access to the volume. Restrict
    echo access with encryption or physical control of the device instead.
)
exit /b 0
