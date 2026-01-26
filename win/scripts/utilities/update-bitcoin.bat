@echo off
setlocal enabledelayedexpansion
REM Update Bitcoin Core binaries (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"
pushd "%ROOTDIR%" >nul 2>&1

set VERSION=30.2
set FILE=bitcoin-%VERSION%-win64.zip
set URL=https://bitcoincore.org/bin/bitcoin-core-%VERSION%/%FILE%
set CHECKSUM_URL=https://bitcoincore.org/bin/bitcoin-core-%VERSION%/SHA256SUMS
set CHECKSUM_SIG_URL=https://bitcoincore.org/bin/bitcoin-core-%VERSION%/SHA256SUMS.asc
set CHECKSUM_FILE=%ROOTDIR%\win/checksums.sha256

set TMPDIR=%ROOTDIR%\win\bin\.tmp-downloads\bitcoin
set STATUS=0
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
mkdir "%TMPDIR%"

echo Updating Bitcoin Core to %VERSION%...

tasklist /fi "imagename eq bitcoind.exe" | find /i "bitcoind.exe" >nul
if %errorlevel%==0 (
    echo Error: Bitcoin Core is running. Stop it before updating.
    popd >nul 2>&1
    exit /b 1
)
tasklist /fi "imagename eq bitcoin-qt.exe" | find /i "bitcoin-qt.exe" >nul
if %errorlevel%==0 (
    echo Error: Bitcoin Core is running. Stop it before updating.
    popd >nul 2>&1
    exit /b 1
)
echo Downloading %URL%...
powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%URL%' -OutFile '%TMPDIR%\\%FILE%' }" || goto :error
powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%CHECKSUM_URL%' -OutFile '%TMPDIR%\\SHA256SUMS' }" || goto :error
powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%CHECKSUM_SIG_URL%' -OutFile '%TMPDIR%\\SHA256SUMS.asc' }" || goto :error

where gpg >nul 2>&1
if %errorlevel%==0 (
    echo Verifying SHA256SUMS signature...
    gpg --verify "%TMPDIR%\\SHA256SUMS.asc" "%TMPDIR%\\SHA256SUMS" || goto :error
) else (
    echo Warning: gpg not found; skipping PGP signature verification.
)

powershell -Command "& { $sum = Get-Content '%TMPDIR%\\SHA256SUMS' | Select-String -Pattern '%FILE%' | Select-Object -First 1; if (-not $sum) { Write-Host 'Checksum entry not found.'; exit 1 } $expected = ($sum -split '\\s+')[0].ToLower(); $actual = (Get-FileHash -Algorithm SHA256 '%TMPDIR%\\%FILE%').Hash.ToLower(); if ($expected -ne $actual) { Write-Host 'Checksum failed.'; exit 1 } Write-Host '%FILE%: OK' }" || goto :error

powershell -Command "& { Expand-Archive -Force '%TMPDIR%\\%FILE%' '%TMPDIR%\\' }" || goto :error

if not exist "%ROOTDIR%\\win\\bin\\backup\\bitcoin" mkdir "%ROOTDIR%\\win\\bin\\backup\\bitcoin"
if exist "%ROOTDIR%\\win\\bin\\bitcoin-qt.exe" copy /y "%ROOTDIR%\\win\\bin\\bitcoin-qt.exe" "%ROOTDIR%\\win\\bin\\backup\\bitcoin\\" >nul
if exist "%ROOTDIR%\\win\\bin\\bitcoind.exe" copy /y "%ROOTDIR%\\win\\bin\\bitcoind.exe" "%ROOTDIR%\\win\\bin\\backup\\bitcoin\\" >nul
if exist "%ROOTDIR%\\win\\bin\\bitcoin-cli.exe" copy /y "%ROOTDIR%\\win\\bin\\bitcoin-cli.exe" "%ROOTDIR%\\win\\bin\\backup\\bitcoin\\" >nul
if exist "%ROOTDIR%\\win\\bin\\bitcoin-wallet.exe" copy /y "%ROOTDIR%\\win\\bin\\bitcoin-wallet.exe" "%ROOTDIR%\\win\\bin\\backup\\bitcoin\\" >nul
if exist "%ROOTDIR%\\win\\bin\\bitcoin-tx.exe" copy /y "%ROOTDIR%\\win\\bin\\bitcoin-tx.exe" "%ROOTDIR%\\win\\bin\\backup\\bitcoin\\" >nul
if exist "%ROOTDIR%\\win\\bin\\bitcoin-util.exe" copy /y "%ROOTDIR%\\win\\bin\\bitcoin-util.exe" "%ROOTDIR%\\win\\bin\\backup\\bitcoin\\" >nul
if exist "%ROOTDIR%\\win\\bin\\bitcoin.exe" copy /y "%ROOTDIR%\\win\\bin\\bitcoin.exe" "%ROOTDIR%\\win\\bin\\backup\\bitcoin\\" >nul

if not exist "%TMPDIR%\\bitcoin-%VERSION%\\bin\\bitcoin-qt.exe" (
    echo Error: extracted binaries not found.
    goto :error
)
copy /y "%TMPDIR%\\bitcoin-%VERSION%\\bin\\*.exe" "%ROOTDIR%\\win\\bin\\" >nul

call :update_checksum "win\\bin\\bitcoin-qt.exe" "%VERSION%"
call :update_checksum "win\\bin\\bitcoind.exe" "%VERSION%"
call :update_checksum "win\\bin\\bitcoin-cli.exe" "%VERSION%"
call :update_checksum "win\\bin\\bitcoin-wallet.exe" "%VERSION%"
call :update_checksum "win\\bin\\bitcoin-tx.exe" "%VERSION%"
call :update_checksum "win\\bin\\bitcoin-util.exe" "%VERSION%"
call :update_checksum "win\\bin\\bitcoin.exe" "%VERSION%"

echo Bitcoin Core updated to %VERSION%

if exist "%SCRIPT_DIR%verify-binaries.bat" (
    call "%SCRIPT_DIR%verify-binaries.bat"
    if errorlevel 1 set STATUS=1
) else (
    echo Warning: verify-binaries.bat not found; skipping verification.
)

goto :cleanup

:update_checksum
set FILEPATH=%~1
set VERSION_LABEL=%~2
if not exist "%FILEPATH%" exit /b 0
powershell -Command "& { $file = '%FILEPATH%'; $version = '%VERSION_LABEL%'; $checksum = '%CHECKSUM_FILE%'; if (!(Test-Path $checksum)) { Write-Host 'Warning: win/checksums.sha256 not found; skipping.'; exit 0 } $hash = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower(); $entry = \"$hash  $file  version=$version\"; $lines = Get-Content $checksum; if ($lines -notcontains $entry) { $lines += $entry } $lines = $lines | Select-Object -Unique; Set-Content -Encoding ASCII $checksum $lines }"
exit /b 0

:error
echo Update failed.
set STATUS=1

:cleanup
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
popd >nul 2>&1
endlocal
exit /b %STATUS%
