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
REM set-datadir-acl.ps1 replaces the directory's DACL in one write with a
REM protected one granting %USERDOMAIN%\%USERNAME% full control,
REM inheritable by the directory's contents. That is the DACL an "icacls
REM <dir> /reset" followed by an "icacls <dir> /inheritance:r /grant
REM <account>:(OI)(CI)F" arrives at: measured on windows-latest against a
REM directory taken through each, the two compare equal as SDDL, both
REM protected, and icacls reads the same "(OI)(CI)(F)" line off either.
REM Those two icacls calls do not fold into one command line -- measured,
REM "icacls dir /reset /inheritance:r /grant ..." answers Invalid
REM parameter "/inheritance:r", exits 87, and leaves the ACL as it found
REM it -- and run in sequence they leave the directory carrying whatever
REM its parent offers between them, BUILTIN\Users:(I)(OI)(CI)(RX) among
REM them on a volume root. Writing the DACL in one operation is what
REM removes that: measured on windows-latest with a second process
REM reading the ACL back in a loop while each ran, the loop saw the
REM protected DACL throughout the .ps1's write, and saw the parent's ACEs
REM appear and go again across the icacls pair.
REM
REM An ACE another identity holds explicitly on the directory survives
REM none of it, the granted rule being the whole of the DACL written --
REM measured on windows-latest with Everyone:(OI)(CI)F set on the
REM directory beforehand: the write left the granted ACE alone, where
REM "icacls /inheritance:r /grant" against the same setup left Everyone
REM standing beside it, /inheritance:r removing inherited ACEs and not
REM explicit ones.
REM
REM Where the account does not resolve nothing is written and the
REM directory keeps the DACL it had -- measured on windows-latest with an
REM account that does not exist, against a directory carrying its
REM parent's ACEs and against one already restricted, the ACL comparing
REM equal before and after in both. Unchanged is not the same as closed:
REM a directory that was inheriting from its parent goes on doing so, and
REM :report_permission_effect below is what says which of the two the
REM reader has. What the write costs is a PowerShell start, which this
REM script already pays once per data directory for filesystem-type.ps1.
REM
REM The write reaches the directory's contents by inheritance rather than
REM by a walk: measured, a file created under the directory afterwards
REM reads "(I)(F)" and a subdirectory "(I)(OI)(CI)(F)". Writing
REM (OI)(CI)F onto each item instead -- icacls's /t on a grant -- leaves
REM each file with an empty DACL, those flags carrying no access on a
REM file, which denies every identity including the granted one: measured
REM on windows-latest, "type bitcoin.conf" then answers "Access is
REM denied." and "icacls bitcoin.conf" prints the path with no ACE beside
REM it.
REM
REM The icacls call under each write reaches what inheritance cannot: an
REM item an earlier run left protected takes no inherited ACE, and an ACE
REM an item carries explicitly of its own is removed by nothing above.
REM /reset drops such an explicit ACE and clears the protection in one
REM pass, where /inheritance:e clears the protection alone -- measured on
REM windows-latest against a file given Everyone:(F) and then protected
REM with /inheritance:r: after /reset /t it read the granted account's
REM own (I)(F) and nothing else, after /inheritance:e /t it read both
REM explicit ACEs still standing with the inherited one added beside
REM them. A subdirectory reads the same way: one granted
REM Everyone:(OI)(CI)F explicitly, with the data directory itself clean,
REM kept that ACE through a run of the grant and the /inheritance:e form,
REM and read the granted account's own (I)(OI)(CI)(F) and nothing else
REM after /reset /t. That call names the directory's contents rather than
REM the directory, and runs after the write rather than before it:
REM /reset replaces the DACL of whatever it is given with the ACEs its
REM parent offers, so on %BDD% itself it would undo the write for as long
REM as the walk takes, and ahead of the write it would leave the contents
REM inheriting an ACL that has not been written yet.
REM
REM The write carries no ">nul": it prints nothing on success, and on
REM failure its stderr names the account and the path, which is what a
REM reader has to go on where the report below finds the directory
REM unrestricted.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%set-datadir-acl.ps1" -Path "%BDD%" -Account "%USERDOMAIN%\%USERNAME%"
icacls "%BDD%\*" /reset /t >nul
set "BDD_INHERIT_RC=%ERRORLEVEL%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%set-datadir-acl.ps1" -Path "%EDD%" -Account "%USERDOMAIN%\%USERNAME%"
icacls "%EDD%\*" /reset /t >nul
set "EDD_INHERIT_RC=%ERRORLEVEL%"

REM exFAT and FAT32 hold no ACL at all: the write and the icacls call
REM above each ran and exited 0 regardless, with nothing on disk to show
REM for either -- measured on windows-latest against an exFAT volume and
REM a FAT32 one on attached VHDs, each directory reading "No permissions
REM are set. All users have full control." afterwards. Read back each data
REM directory's own filesystem and say which case it is in, instead of an
REM unconditional "Permissions set."
REM
REM Each report's own status is captured on the line below the call it
REM came from, for the reason :report_permission_effect's own comment
REM gives for INHERIT_RC: the other data directory's calls run between
REM the two "call" lines and ERRORLEVEL holds whichever command ran
REM last. The higher of the two is what this script exits with, which
REM orders the statuses by how far the answer is out of a caller's
REM reach: a directory this run fell short on is reachable by acting on
REM what its own message names, and a volume storing no ACL is reachable
REM by neither that nor a second run. Each directory's own message is
REM printed either way, so what the single status drops is which of the
REM two directories it came from rather than anything the reader is not
REM told. STATUS is settled before :pause_if_own_console runs, that call
REM setting an ERRORLEVEL of its own.
call :report_permission_effect "%BDD%" bitcoin-datadir "%BDD_INHERIT_RC%"
set "BDD_STATUS=%ERRORLEVEL%"
call :report_permission_effect "%EDD%" electrum-datadir "%EDD_INHERIT_RC%"
set "EDD_STATUS=%ERRORLEVEL%"
set "STATUS=%BDD_STATUS%"
if %EDD_STATUS% GTR %STATUS% set "STATUS=%EDD_STATUS%"
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b %STATUS%

REM The arguments are the path filesystem-type.ps1 is handed, the
REM ROOTDIR-relative name the messages use, and the exit code of the
REM "icacls ... /reset /t" call already made against that path.
REM The caller captures that code on the line below the call it came
REM from because the other data directory's own calls run between
REM the two "call" lines, and ERRORLEVEL holds whichever command ran
REM last; a "call" does not discard it. The folder is mounted at a
REM different point on every machine it is plugged into, so a message
REM quoting the mount point tells the reader where this run happened
REM rather than which directory is meant. The name is passed in because
REM each caller holds it as a literal; cutting %ROOTDIR% off %TARGET%
REM instead needs the second parse of a "call set" (:rootdir_relative in
REM lib.bat) for a value that was never in doubt.
REM
REM What this returns is the status the script exits with, and
REM README.md's Permissions bullet states them for every platform: 0
REM where the directory is restricted to the account named,
REM 1 where this run fell short of that and acting on what the message
REM names is what would reach it, 2 where the volume stores no ACL and
REM no run of this script restricts the directory at all.
REM
REM The filesystem alone does not say the restriction in the message
REM below is in force: the caller reads no exit code off the write
REM above. So this routine reads the ACL back off the directory itself
REM and looks both for the exact ACE the write asked for and for any ACE
REM that is not it, rather than trust that the write ran at all.
REM That readback says nothing about the icacls call's own reach into
REM the directory's existing contents, so that call's exit code, passed
REM in above, is what the warning below is built from instead.
REM
REM The filesystem's name decides only which volumes are answered
REM without a readback -- those that hold no ACL for one to read, where
REM icacls prints "No permissions are set. All users have full control."
REM and the ACE the write asked for is missing for a reason no re-run
REM addresses. Every other name reaches the readback, so a filesystem
REM this file has never heard of is judged by what its directory
REM actually carries rather than by its name. The two ways of being
REM wrong about that name are not the same size: a filesystem
REM missing from the list below is reported unrestricted, which the
REM readback has established, with the generic "the write above may have
REM failed" in place of the volume's own explanation, where a filesystem
REM wrongly on it would be reported unrestricted without the readback
REM ever running. macos/scripts/utilities/set-permissions.sh reads its
REM own filesystem first for the opposite reason: macOS synthesises
REM rwx------ on a volume storing no mode, so there the readback answers
REM the same 700 a real restriction does.
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
REM TARGET is read as !TARGET! inside the readback block below rather
REM than as %TARGET%: percent expansion runs before cmd.exe matches that
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
REM Every "exit /b" below returns from this "call" rather than ending
REM the script, so :pause_if_own_console belongs at the exit that ends
REM it and not here. Measured on windows-latest with the call added
REM before the "exit /b 0" that closes the report, and taken while the
REM routine still ended in "pause": a double-click met it once per data
REM directory and again at the end. Each of those is now a 30-second
REM wait rather than a keypress, so the cost of putting the call here is
REM paid before the script has printed everything it has to say.
:report_permission_effect
set "TARGET=%~1"
set "REL=%~2"
set "INHERIT_RC=%~3"
set "FS_NAME="
for /f "usebackq delims=" %%F in (`powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT_DIR%filesystem-type.ps1" -Path "%TARGET%"`) do set "FS_NAME=%%F"
if not defined FS_NAME (
    echo Warning: could not determine the filesystem of %REL%, so
    echo whether the write above restricted it is not established.
    exit /b 1
)
set "NO_ACL="
if /i "%FS_NAME%"=="exFAT" set "NO_ACL=1"
if /i "%FS_NAME%"=="FAT32" set "NO_ACL=1"
if /i "%FS_NAME%"=="FAT" set "NO_ACL=1"
if defined NO_ACL (
    echo Warning: %REL% is on %FS_NAME%, which does not store ACLs. The
    echo write above changed nothing on disk; the directory is still
    echo readable by anyone with access to the volume. Restrict access
    echo with encryption or physical control of the device instead.
    exit /b 2
)
setlocal enabledelayedexpansion
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
    echo Warning: %REL% is on %FS_NAME%, but its ACL could not be read
    echo back, so whether the restriction is in force is not established.
    echo Check with icacls "!TARGET!".
    exit /b 1
) else if not "!ACE_RC!"=="0" (
    echo Warning: %REL% is on %FS_NAME%, but !TARGET! does not
    echo carry an ACE granting !USERDOMAIN!\!USERNAME! full
    echo control; the write above may have failed. Check with
    echo icacls "!TARGET!".
    exit /b 1
) else if "!OTHER_RC!"=="0" (
    echo Warning: %REL% is on %FS_NAME% and grants
    echo !USERDOMAIN!\!USERNAME! full control, but !TARGET! still
    echo carries an ACE for another identity, so access to it is not
    echo restricted to that account. icacls "!TARGET!" names that
    echo identity, and icacls with /remove takes its ACE off.
    exit /b 1
) else if not "!INHERIT_RC!"=="0" (
    echo Warning: %REL% is on %FS_NAME% and !TARGET! itself now
    echo restricts access to !USERDOMAIN!\!USERNAME!, but icacls
    echo reported an error extending that restriction to items
    echo already inside it, exit !INHERIT_RC!. Check with
    echo icacls "!TARGET!\*".
    exit /b 1
) else (
    echo %REL% is on %FS_NAME%: permissions restricted to
    echo !USERDOMAIN!\!USERNAME!.
    exit /b 0
)
