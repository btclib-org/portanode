@echo off
setlocal disabledelayedexpansion
REM Set restrictive permissions for PortaNode data directories (Windows)

REM Disabled explicitly rather than merely left off: every call below
REM builds its target from %SCRIPT_DIR% or carries %BDD%/%EDD%, and
REM update-bitcoin.bat's own comment on the same line gives what a
REM "call" does to a "!" in either under delayed expansion (#411).
REM :report_permission_effect turns it back on for its own block, at
REM the line that block's comment names.
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
REM /inheritance:r removes inherited ACEs and leaves explicit ones
REM standing, so the grant alone restricts nothing where another
REM identity already holds an explicit ACE on the directory: that ACE
REM keeps its own (OI)(CI) flags and goes on granting what it grants
REM under a directory this script reports as restricted. Measured on
REM windows-latest with Everyone granted (OI)(CI)F on bitcoin-datadir
REM ahead of a run of the grant alone: Everyone read back explicit on
REM the directory, inherited on a subdirectory that already existed,
REM and inherited on a file created after the run. /reset replaces the
REM directory's DACL with the ACEs its parent offers, and the
REM /inheritance:r below removes those in turn, so the pair leaves the
REM grant as the only ACE on the directory. The two do not fold into
REM one command line: measured, "icacls dir /reset /inheritance:r
REM /grant ..." answers Invalid parameter "/inheritance:r", exits 87,
REM and leaves the ACL as it found it. What the separation costs is a
REM window: between the two calls the directory carries whatever its
REM parent offers, which on a volume root includes
REM BUILTIN\Users:(I)(OI)(CI)(RX) -- measured by reading the ACL back
REM between them -- so a run reopens a directory an earlier run had
REM closed. The next line closes it again, and where that line fails
REM it stays open: measured with a second run whose account did not
REM resolve, the directory read its parent's ACEs afterwards, under
REM the warning below that the grant may have failed. That is one
REM command's exposure, reported where it lasts longer, against an
REM explicit ACE that lasts until somebody removes it by hand.
REM
REM The third call reaches what the grant cannot: the grant covers the
REM directory's contents by inheritance, which an item an earlier run
REM left protected takes none of, and which removes nothing an item
REM carries explicitly of its own. /reset drops such an explicit ACE
REM and clears the protection in one pass, where /inheritance:e clears
REM the protection alone -- measured on windows-latest against a file
REM given Everyone:(F) and then protected with /inheritance:r: after
REM /reset /t it read the granted account's own (I)(F) and nothing
REM else, after /inheritance:e /t it read both explicit ACEs still
REM standing with the inherited one added beside them. A subdirectory
REM reads the same way: one granted Everyone:(OI)(CI)F explicitly,
REM with the data directory itself clean, kept that ACE through a run
REM of the grant and the /inheritance:e form, and read the granted
REM account's own (I)(OI)(CI)(F) and nothing else after /reset /t.
REM This call names the directory's contents rather than the
REM directory, and runs after the grant rather than before it: /reset
REM clears protection on whatever it is given, so on %BDD% itself it
REM would hold the window above open for as long as the walk takes,
REM and ahead of the grant it would leave the contents inheriting an
REM ACL the grant has not written yet.
icacls "%BDD%" /reset >nul
icacls "%BDD%" /inheritance:r /grant "%USERDOMAIN%\%USERNAME%:(OI)(CI)F" >nul
icacls "%BDD%\*" /reset /t >nul
set "BDD_INHERIT_RC=%ERRORLEVEL%"
icacls "%EDD%" /reset >nul
icacls "%EDD%" /inheritance:r /grant "%USERDOMAIN%\%USERNAME%:(OI)(CI)F" >nul
icacls "%EDD%\*" /reset /t >nul
set "EDD_INHERIT_RC=%ERRORLEVEL%"

REM exFAT and FAT32 hold no ACL at all: the icacls calls above ran and
REM exited 0 regardless, with nothing on disk to show for either. Read back
REM each data directory's own filesystem and say which case it is in,
REM instead of an unconditional "Permissions set."
call :report_permission_effect "%BDD%" bitcoin-datadir "%BDD_INHERIT_RC%"
call :report_permission_effect "%EDD%" electrum-datadir "%EDD_INHERIT_RC%"
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b 0

REM The arguments are the path filesystem-type.ps1 is handed, the
REM ROOTDIR-relative name the messages use, and the exit code of the
REM "icacls ... /reset /t" call already made against that path.
REM The caller captures that code on the line below the call it came
REM from because the other data directory's own icacls calls run between
REM the two "call" lines, and ERRORLEVEL holds whichever command ran
REM last; a "call" does not discard it. The folder is mounted at a
REM different point on every machine it is plugged into, so a message
REM quoting the mount point tells the reader where this run happened
REM rather than which directory is meant. The name is passed in because
REM each caller holds it as a literal; cutting %ROOTDIR% off %TARGET%
REM instead needs the second parse of a "call set" (:rootdir_relative in
REM lib.bat) for a value that was never in doubt.
REM
REM The filesystem alone does not say the restriction in the message
REM below is in force: the "icacls ... /grant" above can exit non-zero
REM for a reason its caller never sees, its own output routed to nul.
REM So on NTFS this routine reads the ACL back off the directory itself
REM and looks both for the exact ACE the grant asked for and for any ACE
REM that is not it, rather than trust that the grant and the /reset
REM ahead of it ran at all. That readback says nothing about the third
REM call's own reach into the directory's existing contents, so its exit
REM code, passed in above, is what the warning below is built from
REM instead.
REM
REM The second search is the first one's complement: findstr /v drops
REM every line holding the granted ACE, wherever in the report icacls
REM prints it, and what survives is searched for ":(", which every
REM remaining ACE line carries and neither the blank line nor icacls's
REM own "Successfully processed" summary does. The path icacls echoes
REM ahead of the first ACE cannot supply that pair either: ':' is not a
REM legal character in a Windows file name, and a drive letter's own
REM colon is followed by a backslash. Measured on windows-latest against
REM a directory carrying the granted ACE alone and one carrying it
REM beside Everyone:(OI)(CI)F -- the second of which icacls printed with
REM Everyone on the path line and the granted ACE indented below it, so
REM the filter is read against the order it does not expect as well as
REM the one it does -- the search answered 1 on the first and 0 on the
REM second.
REM
REM The readback runs a control before it runs the search, because the
REM search is one whose informative answer is a miss: findstr answers 1
REM where the string is absent and also 1 where it could not read the
REM file, which win/scripts/electrum/lib.bat records for the same reason.
REM Measured on windows-latest: the ACE search answers 0 where the ACE is
REM there and 1 against a file that is absent, a file that is empty, and
REM a real file the string is missing from alike -- three states behind
REM one code. icacls echoes the path it was given as the first thing on
REM its first line, so a search for TARGET itself answers 0 on a report
REM that arrived and 1 on an empty file; that is the control, and only
REM once it passes does a miss on the ACE mean the ACE is absent.
REM
REM TARGET is read as !TARGET! inside the NTFS block below rather than
REM as %TARGET%: percent expansion runs before cmd.exe matches that
REM block's parentheses, so a closing parenthesis in the mount point
REM would end the block early (#211, #298, #300). Measured on
REM windows-latest against a directory whose name ends in a close
REM parenthesis: an unquoted "%TARGET%" inside such a block ends the
REM block at that character and abandons the run with "was unexpected
REM at this time", where a quoted one is read as the path it names.
REM USERDOMAIN and USERNAME in the same block already carry the bang
REM form. REL and FS_NAME stay percent-expanded there: each caller
REM passes REL as one of two literals held in this file, and FS_NAME is
REM filesystem-type.ps1's answer, so neither carries the mount point's
REM own characters.
REM
REM The scope enabling delayed expansion opens below the three
REM arguments rather than at the top of this file, because a "!" in the
REM mount point reaches here through %~1: with delayed expansion on,
REM the pass that substitutes !TARGET! strips an unmatched "!" from the
REM value %~1 expands to, and from the target path of every call in
REM this file besides (#411). Captured with it off and read with it on,
REM the character survives both -- measured on windows-latest with the
REM folder at C:\Port!Node and TEMP pointed at a directory holding a
REM "!" of its own, this routine's own shape reading back TARGET and a
REM TEMP-derived ACL_FILE unchanged.
REM The block holds no call, which is what lets it be enabled at all.
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
set "INHERIT_RC=%~3"
set "FS_NAME="
for /f "usebackq delims=" %%F in (`powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT_DIR%filesystem-type.ps1" -Path "%TARGET%"`) do set "FS_NAME=%%F"
if not defined FS_NAME (
    echo Warning: could not determine the filesystem of %REL%; assuming
    echo the icacls above took effect.
    exit /b 0
)
setlocal enabledelayedexpansion
if /i "%FS_NAME%"=="NTFS" (
    set "ACL_FILE=!TEMP!\pn_acl_%RANDOM%%RANDOM%.txt"
    icacls "!TARGET!" > "!ACL_FILE!" 2>nul
    findstr /i /c:"!TARGET!" "!ACL_FILE!" >nul 2>&1
    set "READ_RC=!errorlevel!"
    findstr /i /c:"!USERDOMAIN!\!USERNAME!:(OI)(CI)(F)" "!ACL_FILE!" >nul 2>&1
    set "ACE_RC=!errorlevel!"
    findstr /i /v /c:"!USERDOMAIN!\!USERNAME!:(OI)(CI)(F)" "!ACL_FILE!" | findstr /c:":(" >nul 2>&1
    set "OTHER_RC=!errorlevel!"
    del "!ACL_FILE!" >nul 2>&1
    if not "!READ_RC!"=="0" (
        echo Warning: %REL% is on an NTFS volume, but its ACL could not be
        echo read back, so whether the restriction is in force is unknown.
        echo Check with icacls "!TARGET!".
    ) else if not "!ACE_RC!"=="0" (
        echo Warning: %REL% is on an NTFS volume, but !TARGET! does
        echo not carry an ACE granting !USERDOMAIN!\!USERNAME! full
        echo control; the grant above may have failed. Check with
        echo icacls "!TARGET!".
    ) else if "!OTHER_RC!"=="0" (
        echo Warning: %REL% is on an NTFS volume and grants
        echo !USERDOMAIN!\!USERNAME! full control, but !TARGET! still
        echo carries an ACE for another identity, so access to it is not
        echo restricted to that account. icacls "!TARGET!" names that
        echo identity, and icacls with /remove takes its ACE off.
    ) else if not "!INHERIT_RC!"=="0" (
        echo %REL% is on an NTFS volume: !TARGET! itself now
        echo restricts access to !USERDOMAIN!\!USERNAME!, but icacls
        echo reported an error extending that restriction to items
        echo already inside it, exit !INHERIT_RC!. Check with
        echo icacls "!TARGET!\*".
    ) else (
        echo %REL% is on an NTFS volume: permissions restricted to
        echo !USERDOMAIN!\!USERNAME!.
    )
) else (
    echo Warning: %REL% is on a %FS_NAME% volume, which does not store
    echo ACLs. icacls above changed nothing on disk; the directory is
    echo still readable by anyone with access to the volume. Restrict
    echo access with encryption or physical control of the device instead.
)
exit /b 0
