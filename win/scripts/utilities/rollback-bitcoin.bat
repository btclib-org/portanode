@echo off
setlocal enabledelayedexpansion
REM Rollback Bitcoin Core binaries (Windows)

set SCRIPT_DIR=%~dp0
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
set BACKUP_DIR=%ROOTDIR%\win\bin\backup\bitcoin
set CHECKSUM_FILE=%ROOTDIR%\win\checksums.sha256

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

REM A rollback replaces the files update-bitcoin.bat installs, so it refuses on
REM the same condition: replacing an .exe under a running process is the same
REM operation whichever script does it, and a rollback is run when something
REM has just gone wrong, which is when the node is most likely to still be up.
REM The filters are that script's, repeated here rather than shared, so a
REM change to one is owed to the other.
tasklist /fi "imagename eq bitcoind.exe" | find /i "bitcoind.exe" >nul
if %errorlevel%==0 (
    echo Error: Bitcoin Core is running. Stop it before rolling back.
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)
tasklist /fi "imagename eq bitcoin-qt.exe" | find /i "bitcoin-qt.exe" >nul
if %errorlevel%==0 (
    echo Error: Bitcoin Core is running. Stop it before rolling back.
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

pushd "%ROOTDIR%" >nul 2>&1

if not exist "%BACKUP_DIR%" (
    echo No backup found in %BACKUP_DIR%
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

echo Rolling back Bitcoin binaries...

if not exist "%CHECKSUM_FILE%" (
    echo Error: %CHECKSUM_FILE% not found.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\bitcoin-qt.exe" "win/bin/bitcoin-qt.exe"
if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-qt.exe.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)
if exist "%BACKUP_DIR%\bitcoind.exe" (
  call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\bitcoind.exe" "win/bin/bitcoind.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoind.exe.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin-cli.exe" (
  call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\bitcoin-cli.exe" "win/bin/bitcoin-cli.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-cli.exe.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin-wallet.exe" (
  call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\bitcoin-wallet.exe" "win/bin/bitcoin-wallet.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-wallet.exe.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin-tx.exe" (
  call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\bitcoin-tx.exe" "win/bin/bitcoin-tx.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-tx.exe.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin-util.exe" (
  call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\bitcoin-util.exe" "win/bin/bitcoin-util.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-util.exe.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin.exe" (
  call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\bitcoin.exe" "win/bin/bitcoin.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin.exe.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
  )
)

if not exist "%BACKUP_DIR%\bitcoin-qt.exe" (
    echo Backup files not found in %BACKUP_DIR%
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

if "%DRY_RUN%"=="1" (
    call "%SCRIPT_DIR%lib.bat" :installed_version "%BACKUP_DIR%\bitcoin-qt.exe" "win/bin/bitcoin-qt.exe" "%CHECKSUM_FILE%" BACKUPVER
    call "%SCRIPT_DIR%lib.bat" :installed_version "%ROOTDIR%\win\bin\bitcoin-qt.exe" "win/bin/bitcoin-qt.exe" "%CHECKSUM_FILE%" CURRENTVER
    echo --dry-run: nothing will be changed.
    echo Backup found in %BACKUP_DIR%, checksum recognized: version !BACKUPVER!.
    echo Currently installed: !CURRENTVER!.
    echo Would replace win\bin binaries with the backup.
    popd >nul 2>&1
    exit /b 0
)

REM The backup is moved rather than copied, so a rollback consumes it: the slot
REM holds the version installed before the last update, and a copy left behind
REM would hold the version that is now installed. A slot that swapped its
REM contents instead would make a second rollback move forward again, where
REM update-bitcoin.bat brings the newer release back and verifies its PGP
REM signature on the way.
REM What is restored is what update-bitcoin.bat backs up, which is the
REM command-line tools as well as bitcoin-qt.exe; the macOS half restores
REM Bitcoin-Qt.app alone because update-bitcoin.sh backs up the app alone.
call :restore_one bitcoin-qt.exe
if errorlevel 1 goto :restore_failed
call :restore_one bitcoind.exe
if errorlevel 1 goto :restore_failed
call :restore_one bitcoin-cli.exe
if errorlevel 1 goto :restore_failed
call :restore_one bitcoin-wallet.exe
if errorlevel 1 goto :restore_failed
call :restore_one bitcoin-tx.exe
if errorlevel 1 goto :restore_failed
call :restore_one bitcoin-util.exe
if errorlevel 1 goto :restore_failed
call :restore_one bitcoin.exe
if errorlevel 1 goto :restore_failed
if exist "%BACKUP_DIR%" rmdir "%BACKUP_DIR%" >nul 2>&1

echo Rollback complete.
echo The backup in win\bin\backup\bitcoin is consumed: a second rollback has nothing to restore.
echo update-bitcoin.bat is what installs the current release again.

popd >nul 2>&1
exit /b 0

:restore_failed
echo Error: the rollback stopped before restoring every binary. What it did not
echo move is still in win\bin\backup\bitcoin. Once the cause is cleared, move
echo what is left there into win\bin by hand, or run update-bitcoin.bat to
echo install the current release over whatever win\bin now holds.
popd >nul 2>&1
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b 1

REM Nothing is deleted before the move, so a move that fails leaves win\bin
REM holding the version that was installed and there is nothing to put back;
REM what a failure needs is to be reported. >nul redirects stdout alone, so
REM what move writes to stderr reaches the console.
REM The skip below is for a backup that does not hold the file at all:
REM update-bitcoin.bat copies only what win\bin held when it ran. It is not for
REM resuming a partial restore -- bitcoin-qt.exe is restored first, so once it
REM has moved out of the backup the "Backup files not found" gate above stops
REM any re-run.
:restore_one
if not exist "%BACKUP_DIR%\%~1" exit /b 0
move /y "%BACKUP_DIR%\%~1" "%ROOTDIR%\win\bin\" >nul
if errorlevel 1 (
    echo Error: restoring win\bin\%~1 from the backup failed.
    exit /b 1
)
exit /b 0
