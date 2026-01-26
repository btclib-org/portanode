@echo off
setlocal enabledelayedexpansion
REM Validate PortaNode setup (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"

pushd "%ROOTDIR%" >nul 2>&1

echo Validating PortaNode setup...

set BINARIES=^
win\bin\bitcoin-qt.exe ^
win\bin\bitcoind.exe ^
win\bin\bitcoin-cli.exe ^
win\bin\bitcoin-tx.exe ^
win\bin\bitcoin-wallet.exe ^
win\bin\electrum.exe

set MISSING=0
for %%B in (%BINARIES%) do (
    if not exist "%%B" (
        echo ERROR: Binary %%B not found.
        set MISSING=1
    )
)

if %MISSING% neq 0 (
    popd >nul 2>&1
    exit /b 1
)
echo OK: Binaries present

if exist "%SCRIPT_DIR%verify-binaries.bat" (
    call "%SCRIPT_DIR%verify-binaries.bat"
    if errorlevel 1 (
        popd >nul 2>&1
        exit /b 1
    )
    echo OK: Checksums valid
) else (
    echo WARNING: verify-binaries.bat not found, skipping checksum check
)

if exist "bitcoin-datadir" if exist "electrum-datadir" (
    echo OK: Data directories exist
) else (
    echo WARNING: Data directories not found
)

for /f "tokens=3" %%F in ('fsutil volume diskfree "%ROOTDIR%" ^| findstr /i "Total # of free bytes"') do set FREE_BYTES=%%F
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

echo Validation complete. Setup looks good!
popd >nul 2>&1
exit /b 0
