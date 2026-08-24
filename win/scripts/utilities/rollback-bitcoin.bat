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
exit /b 1
:args_done

pushd "%ROOTDIR%" >nul 2>&1

if not exist "%BACKUP_DIR%" (
    echo No backup found in %BACKUP_DIR%
    popd >nul 2>&1
    exit /b 1
)

echo Rolling back Bitcoin binaries...

if not exist "%CHECKSUM_FILE%" (
    echo Error: %CHECKSUM_FILE% not found.
    popd >nul 2>&1
    exit /b 1
)

call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\bitcoin-qt.exe" "win/bin/bitcoin-qt.exe"
if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-qt.exe.
    popd >nul 2>&1
    exit /b 1
)
if exist "%BACKUP_DIR%\bitcoind.exe" (
  call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\bitcoind.exe" "win/bin/bitcoind.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoind.exe.
    popd >nul 2>&1
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin-cli.exe" (
  call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\bitcoin-cli.exe" "win/bin/bitcoin-cli.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-cli.exe.
    popd >nul 2>&1
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin-wallet.exe" (
  call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\bitcoin-wallet.exe" "win/bin/bitcoin-wallet.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-wallet.exe.
    popd >nul 2>&1
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin-tx.exe" (
  call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\bitcoin-tx.exe" "win/bin/bitcoin-tx.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-tx.exe.
    popd >nul 2>&1
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin-util.exe" (
  call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\bitcoin-util.exe" "win/bin/bitcoin-util.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-util.exe.
    popd >nul 2>&1
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin.exe" (
  call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\bitcoin.exe" "win/bin/bitcoin.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin.exe.
    popd >nul 2>&1
    exit /b 1
  )
)

if not exist "%BACKUP_DIR%\bitcoin-qt.exe" (
    echo Backup files not found in %BACKUP_DIR%
    popd >nul 2>&1
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

move /y "%BACKUP_DIR%\bitcoin-qt.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
move /y "%BACKUP_DIR%\bitcoind.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
move /y "%BACKUP_DIR%\bitcoin-cli.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
move /y "%BACKUP_DIR%\bitcoin-wallet.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
move /y "%BACKUP_DIR%\bitcoin-tx.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
move /y "%BACKUP_DIR%\bitcoin-util.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
move /y "%BACKUP_DIR%\bitcoin.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
if exist "%BACKUP_DIR%" rmdir "%BACKUP_DIR%" >nul 2>&1

echo Rollback complete.

popd >nul 2>&1
exit /b 0
