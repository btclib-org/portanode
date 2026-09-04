@echo off
setlocal disabledelayedexpansion
REM Rollback Last Electrum Update

set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
set "BACKUP_DIR=%ROOTDIR%\win\bin\backup\electrum"
REM Explicitly disabled above (line 2) rather than merely not
REM enabled, so the guarantee holds regardless of what a caller set:
REM cmd.exe's delayed-expansion pass strips an unmatched "!" from the
REM *expanded* value of "%ROOTDIR%" exactly as it would from one
REM written in the script text, and a folder mounted at a path
REM containing one is legal on exFAT and NTFS alike (#374). With it on,
REM CHECKSUM_FILE below would lose that "!" before lib.bat's checksum
REM guard ever tests it.
set "CHECKSUM_FILE=%ROOTDIR%\win\checksums.sha256"

set "DRY_RUN=0"
:parse_args
if "%~1"=="" goto :args_done
if "%~1"=="--dry-run" (
    set "DRY_RUN=1"
    shift
    goto :parse_args
)
echo Usage: %~nx0 [--dry-run]
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b 1
:args_done

REM A rollback replaces the file update-electrum.bat installs, so it refuses on
REM the same condition: replacing an .exe under a running process is the same
REM operation whichever script does it, and a rollback is run when something has
REM just gone wrong, which is when Electrum is most likely to still be up. The
REM filter is that script's, repeated here rather than shared, so a change to
REM one is owed to the other.
tasklist /fi "imagename eq electrum.exe" | find /i "electrum.exe" >nul
if %errorlevel%==0 (
    echo Error: Electrum is running. Stop it before rolling back.
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

pushd "%ROOTDIR%" >nul 2>&1

if not exist "%BACKUP_DIR%" (
    echo No backup found in win\bin\backup\electrum
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

echo Rolling back Electrum binaries...

if not exist "%CHECKSUM_FILE%" (
    echo Error: win\checksums.sha256 not found.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\electrum.exe" "win/bin/electrum.exe"
if errorlevel 1 (
    echo Error: backup binary checksum not recognized for electrum.exe.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

if not exist "%BACKUP_DIR%\electrum.exe" (
    echo Backup files not found in win\bin\backup\electrum
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

REM Flat rather than the "( )" block this replaced: with delayed
REM expansion disabled (line 2), a read-after-write in one block
REM would see BACKUPVER/CURRENTVER as they stood when the block was
REM entered -- empty -- rather than as :installed_version just set
REM them; each "%BACKUPVER%"/"%CURRENTVER%" below is its own
REM statement, read fresh at the line that runs it.
if not "%DRY_RUN%"=="1" goto :do_rollback
call "%SCRIPT_DIR%lib.bat" :installed_version "%BACKUP_DIR%\electrum.exe" "win/bin/electrum.exe" "%CHECKSUM_FILE%" BACKUPVER
call "%SCRIPT_DIR%lib.bat" :installed_version "%ROOTDIR%\win\bin\electrum.exe" "win/bin/electrum.exe" "%CHECKSUM_FILE%" CURRENTVER
echo --dry-run: nothing will be changed.
echo Backup found in win\bin\backup\electrum, checksum recognized: version %BACKUPVER%.
echo Currently installed: %CURRENTVER%.
echo Would replace win\bin\electrum.exe with the backup.
popd >nul 2>&1
exit /b 0
:do_rollback

REM The backup is moved rather than copied, so a rollback consumes it: the slot
REM holds the version installed before the last update, and a copy left behind
REM would hold the version that is now installed. A slot that swapped its
REM contents instead would make a second rollback move forward again, where
REM update-electrum.bat brings the newer release back and verifies its PGP
REM signature on the way.
REM Nothing is deleted before the move, so a move that fails leaves win\bin
REM holding the version that was installed and there is nothing to put back;
REM what a failure needs is to be reported. >nul redirects stdout alone, so
REM what move writes to stderr reaches the console.
move /y "%BACKUP_DIR%\electrum.exe" "%ROOTDIR%\win\bin\" >nul
if errorlevel 1 (
    echo Error: restoring win\bin\electrum.exe from the backup failed.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)
if exist "%BACKUP_DIR%" rmdir "%BACKUP_DIR%" >nul 2>&1

echo Rollback complete.
echo The backup in win\bin\backup\electrum is consumed: a second rollback has nothing to restore.
echo update-electrum.bat is what installs the current release again.

popd >nul 2>&1
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b 0
