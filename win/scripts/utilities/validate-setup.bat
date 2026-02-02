@echo off
setlocal enabledelayedexpansion
REM Validate setup

set SCRIPT_DIR=%~dp0
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR

pushd "%ROOTDIR%" >nul 2>&1

echo Validating setup at %ROOTDIR%


if exist "%SCRIPT_DIR%verify-binaries.bat" (
    call "%SCRIPT_DIR%verify-binaries.bat"
    if errorlevel 1 (
        popd >nul 2>&1
        exit /b 1
    )
) else (
    echo WARNING: verify-binaries.bat not found, skipping checksum check
)

if exist "bitcoin-datadir" if exist "electrum-datadir" (
    echo OK: Data directories exist
) else (
    echo WARNING: Data directories not found
)

for /f "tokens=3" %%F in ('fsutil volume diskfree "%ROOTDIR%" ^| ^
findstr /i "Total # of free bytes"') do set FREE_BYTES=%%F
if not defined FREE_BYTES (
    echo WARNING: Could not determine disk free space.
) else (
    set /a FREE_GB=%FREE_BYTES%/1024/1024/1024
    echo Disk free space: %FREE_GB% GB
    if %FREE_GB% lss 100 (
        echo ERROR: Less than 100GB free.
        popd >nul 2>&1
        exit /b 1
    )
)

echo Setup validation completed.
popd >nul 2>&1
exit /b 0
