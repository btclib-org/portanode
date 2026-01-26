@echo off
setlocal enabledelayedexpansion
REM Health check for PortaNode (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"

pushd "%ROOTDIR%" >nul 2>&1

echo Health Check

for /f "tokens=3" %%F in ('fsutil volume diskfree "%ROOTDIR%" ^| findstr /i "Total # of free bytes"') do set FREE_BYTES=%%F
if defined FREE_BYTES (
    set /a FREE_GB=%FREE_BYTES%/1024/1024/1024
    echo Disk free: %FREE_GB% GB
) else (
    echo Disk free: unknown
)

tasklist /fi "imagename eq bitcoind.exe" | find /i "bitcoind.exe" >nul
if %errorlevel%==0 (
    echo Bitcoin running: yes
    if exist "%ROOTDIR%\win\bin\bitcoin-cli.exe" (
        for /f "usebackq delims=" %%J in (`powershell -Command "& { try { $info = & '%ROOTDIR%\\win\\bin\\bitcoin-cli.exe' -datadir='%ROOTDIR%\\bitcoin-datadir' getblockchaininfo 2>$null | ConvertFrom-Json; if ($info.verificationprogress) { [math]::Round($info.verificationprogress*100,2) } } catch { '' } }"`) do set SYNC=%%J
        if defined SYNC (
            echo Bitcoin sync: %SYNC%%%
        ) else (
            echo Bitcoin sync: unknown
        )
    ) else (
        echo Bitcoin sync: unknown
    )
) else (
    echo Bitcoin running: no
    echo Bitcoin sync: n/a
)

tasklist /fi "imagename eq electrum.exe" | find /i "electrum.exe" >nul
if %errorlevel%==0 (
    echo Electrum running: yes
) else (
    echo Electrum running: no
)
popd >nul 2>&1
exit /b 0
