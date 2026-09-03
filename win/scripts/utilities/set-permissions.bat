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
REM icacls applies each operation on its command line to every item it
REM walks, so /t on the grant would put (OI)(CI)F on the files too, and
REM those flags carry no access on a file: each file is left with an
REM empty DACL, which denies every identity, the one granted here and
REM Administrators included. Measured on windows-latest with /t: "type
REM bitcoin.conf" answers "Access is denied." and "icacls bitcoin.conf"
REM prints the path with no ACE beside it. Granted on the directory
REM alone the ACE is inheritable: a separate run, over a tree carrying
REM wallets\my wallet\wallet.dat and testnet4\blocks\index\000003.ldb
REM and locked by the /t form beforehand, read both back as "(I)(F)",
REM so the subtree is covered without being walked.
REM
REM The second call reaches what the first cannot: a file an earlier run
REM left protected takes no inherited ACE until inheritance is enabled
REM on it again. It names the directory's contents rather than the
REM directory, and runs after the grant rather than before it, because
REM /inheritance:e clears protection on whatever it is given: on %BDD%
REM itself it leaves the directory inheriting the volume's own ACEs for
REM the length of the walk. Measured by sampling the directory's ACL
REM while each order ran: with /inheritance:e first the directory reads
REM unprotected and carrying BUILTIN\Users through most of the walk, and
REM in this order through none of it, both ending on the same ACL.
REM /reset would serve as the repair and drop each object's explicit
REM ACEs with it.
icacls "%BDD%" /inheritance:r /grant "%USERDOMAIN%\%USERNAME%:(OI)(CI)F" >nul
icacls "%BDD%\*" /inheritance:e /t >nul
icacls "%EDD%" /inheritance:r /grant "%USERDOMAIN%\%USERNAME%:(OI)(CI)F" >nul
icacls "%EDD%\*" /inheritance:e /t >nul

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
