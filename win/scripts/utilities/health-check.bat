@echo off
setlocal enabledelayedexpansion
REM Health check for PortaNode (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"

pushd "%ROOTDIR%" >nul 2>&1

echo Health Check

tasklist /fi "imagename eq explorer.exe" >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Note: process listing unavailable; detection may be incomplete.
)

set "MOUNT_PATH=%ROOTDIR%"
for /f "tokens=3" %%F in ('fsutil volume diskfree "%ROOTDIR%" ^| findstr /i "Total # of free bytes"') do set FREE_BYTES=%%F
if defined FREE_BYTES (
    set /a FREE_GB=%FREE_BYTES%/1024/1024/1024
    if defined MOUNT_PATH (
        echo Disk free: %FREE_GB% GB (%MOUNT_PATH%)
    ) else (
        echo Disk free: %FREE_GB% GB
    )
) else (
    echo Disk free: unknown
)

set BTC_RUNNING=0
set BTC_INFO=
set BTC_METHOD=
set ARTIFACTS=
set ARTIFACT_NOTE=
if exist "%ROOTDIR%\win\bin\bitcoin-cli.exe" (
    for /f "usebackq delims=" %%J in (`powershell -Command "& { try { & '%ROOTDIR%\\win\\bin\\bitcoin-cli.exe' -datadir='%ROOTDIR%\\bitcoin-datadir' getblockchaininfo 2>$null } catch { '' } }"`) do set BTC_INFO=%%J
    if defined BTC_INFO (
        set BTC_RUNNING=1
        set BTC_METHOD=bitcoin-cli
    )
)
if "%BTC_RUNNING%"=="0" (
    tasklist /fi "imagename eq bitcoind.exe" | find /i "bitcoind.exe" >nul && (set BTC_RUNNING=1 & set BTC_METHOD=tasklist)
    if "%BTC_RUNNING%"=="0" tasklist /fi "imagename eq bitcoin-qt.exe" | find /i "bitcoin-qt.exe" >nul && (set BTC_RUNNING=1 & set BTC_METHOD=tasklist)
)
if "%BTC_RUNNING%"=="0" (
    if exist "%ROOTDIR%\bitcoin-datadir\.lock" set ARTIFACTS=%ARTIFACTS% .lock
    if exist "%ROOTDIR%\bitcoin-datadir\.cookie" set ARTIFACTS=%ARTIFACTS% .cookie
    if exist "%ROOTDIR%\bitcoin-datadir\bitcoind.pid" (
        set ARTIFACTS=%ARTIFACTS% bitcoind.pid
        for /f "usebackq delims=" %%P in ("%ROOTDIR%\bitcoin-datadir\bitcoind.pid") do set PID=%%P
        if defined PID (
            tasklist /fi "pid eq %PID%" | find /i "%PID%" >nul
            if %errorlevel%==0 (
                set BTC_RUNNING=1
                set BTC_METHOD=pid
            ) else (
                set ARTIFACT_NOTE= (stale pid)
            )
        )
    )
    if defined ARTIFACTS (
        if "%BTC_RUNNING%"=="0" (
            set BTC_RUNNING=2
            set BTC_METHOD=artifacts
            echo Bitcoin artifacts:%ARTIFACTS%%ARTIFACT_NOTE%
        )
    )
)
if "%BTC_RUNNING%"=="1" (
    if defined BTC_METHOD (
        if /i "%BTC_METHOD%"=="bitcoin-cli" (
            for /f "usebackq delims=" %%P in (`powershell -Command "& { try { (Get-Command '%ROOTDIR%\\win\\bin\\bitcoin-cli.exe' -ErrorAction Stop).Path } catch { try { (Get-Command bitcoin-cli.exe -ErrorAction Stop).Path } catch { '' } } }"`) do set BTC_CLI_PATH=%%P
            if defined BTC_CLI_PATH (
                echo Bitcoin running: yes (%BTC_METHOD%: %BTC_CLI_PATH%)
            ) else (
                echo Bitcoin running: yes (%BTC_METHOD%: PATH)
            )
        ) else (
            echo Bitcoin running: yes (%BTC_METHOD%)
        )
    ) else (
        echo Bitcoin running: yes
    )
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
    if "%BTC_RUNNING%"=="2" (
        if defined BTC_METHOD (
            echo Bitcoin running: maybe (%BTC_METHOD%)
        ) else (
            echo Bitcoin running: maybe
        )
        echo Bitcoin sync: unknown
    ) else (
        echo Bitcoin running: no
        echo Bitcoin sync: n/a
    )
)

set ELECTRUM_RUNNING=0
set ELECTRUM_METHOD=
for /f "usebackq delims=" %%P in (`powershell -Command "& { $p = Get-Process electrum -ErrorAction SilentlyContinue; if ($p) { $p | Select-Object -ExpandProperty Path } }"`) do (
    echo %%P | find /i "\\win\\bin\\electrum.exe" >nul && set ELECTRUM_RUNNING=1 && set ELECTRUM_METHOD=process-path
)
if "%ELECTRUM_RUNNING%"=="0" (
    tasklist /fi "imagename eq electrum.exe" | find /i "electrum.exe" >nul && (set ELECTRUM_RUNNING=1 & set ELECTRUM_METHOD=tasklist)
)
if "%ELECTRUM_RUNNING%"=="1" (
    if defined ELECTRUM_METHOD (
        echo Electrum running: yes (%ELECTRUM_METHOD%)
    ) else (
        echo Electrum running: yes
    )
) else (
    echo Electrum running: no
)
popd >nul 2>&1
exit /b 0
