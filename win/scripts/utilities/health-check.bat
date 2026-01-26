@echo off
setlocal enabledelayedexpansion
REM Health check for PortaNode (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"

pushd "%ROOTDIR%" >nul 2>&1

echo Running health checks...

for /f "tokens=3" %%F in ('fsutil volume diskfree "%ROOTDIR%" ^| findstr /i "Total # of free bytes"') do set FREE_BYTES=%%F
if defined FREE_BYTES (
    set /a FREE_GB=%FREE_BYTES%/1024/1024/1024
    echo Disk free space: %FREE_GB% GB
) else (
    echo Disk free space: unknown
)

tasklist /fi "imagename eq bitcoind.exe" | find /i "bitcoind.exe" >nul
if %errorlevel%==0 (
    if exist "%ROOTDIR%\win\bin\bitcoin-cli.exe" (
        for /f "usebackq delims=" %%J in (`powershell -Command "& { try { $info = & '%ROOTDIR%\\win\\bin\\bitcoin-cli.exe' -datadir='%ROOTDIR%\\bitcoin-datadir' getblockchaininfo 2>$null | ConvertFrom-Json; if ($info.verificationprogress) { [math]::Round($info.verificationprogress*100,2) } } catch { '' } }"`) do set SYNC=%%J
        if defined SYNC (
            echo Bitcoin sync progress: %SYNC%%%
        ) else (
            echo Bitcoin RPC not accessible
        )
    ) else (
        echo bitcoin-cli.exe not found
    )
) else (
    echo Bitcoin not running
)

tasklist /fi "imagename eq electrum.exe" | find /i "electrum.exe" >nul
if %errorlevel%==0 (
    echo Electrum is running
) else (
    echo Electrum not running
)

echo Health check complete.
popd >nul 2>&1
exit /b 0
