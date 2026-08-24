@echo off
setlocal enabledelayedexpansion
REM Rollback Last Electrum Update

set SCRIPT_DIR=%~dp0
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
set BACKUP_DIR=%ROOTDIR%\win\bin\backup\electrum
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

echo Rolling back Electrum binaries...

if not exist "%CHECKSUM_FILE%" (
    echo Error: %CHECKSUM_FILE% not found.
    popd >nul 2>&1
    exit /b 1
)

call "%SCRIPT_DIR%lib.bat" :verify_checksum "%BACKUP_DIR%\electrum.exe" "win/bin/electrum.exe"
if errorlevel 1 (
    echo Error: backup binary checksum not recognized for electrum.exe.
    popd >nul 2>&1
    exit /b 1
)

if not exist "%BACKUP_DIR%\electrum.exe" (
    echo Backup files not found in %BACKUP_DIR%
    popd >nul 2>&1
    exit /b 1
)

if "%DRY_RUN%"=="1" (
    call "%SCRIPT_DIR%lib.bat" :installed_version "%BACKUP_DIR%\electrum.exe" "win/bin/electrum.exe" "%CHECKSUM_FILE%" BACKUPVER
    call "%SCRIPT_DIR%lib.bat" :installed_version "%ROOTDIR%\win\bin\electrum.exe" "win/bin/electrum.exe" "%CHECKSUM_FILE%" CURRENTVER
    echo --dry-run: nothing will be changed.
    echo Backup found in %BACKUP_DIR%, checksum recognized: version !BACKUPVER!.
    echo Currently installed: !CURRENTVER!.
    echo Would replace win\bin\electrum.exe with the backup.
    popd >nul 2>&1
    exit /b 0
)

move /y "%BACKUP_DIR%\electrum.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
if exist "%BACKUP_DIR%" rmdir "%BACKUP_DIR%" >nul 2>&1

echo Rollback complete.

popd >nul 2>&1
exit /b 0
