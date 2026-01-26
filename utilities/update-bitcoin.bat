@echo off
setlocal enabledelayedexpansion
REM Update Bitcoin Core binaries (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"
pushd "%ROOTDIR%" >nul 2>&1

set VERSION=30.2
set FILE=bitcoin-%VERSION%-win64.zip
set URL=https://bitcoincore.org/bin/bitcoin-core-%VERSION%/%FILE%
set CHECKSUM_URL=https://bitcoincore.org/bin/bitcoin-core-%VERSION%/SHA256SUMS
set CHECKSUM_FILE=%ROOTDIR%\checksums.sha256

set TMPDIR=%TEMP%\portanode-bitcoin-update
set STATUS=0
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
mkdir "%TMPDIR%"

echo Updating Bitcoin Core to %VERSION%...
echo Downloading %URL%...
powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%URL%' -OutFile '%TMPDIR%\\%FILE%' }" || goto :error
powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%CHECKSUM_URL%' -OutFile '%TMPDIR%\\SHA256SUMS' }" || goto :error

powershell -Command "& { $sum = Get-Content '%TMPDIR%\\SHA256SUMS' | Select-String -Pattern '%FILE%' | Select-Object -First 1; if (-not $sum) { Write-Host 'Checksum entry not found.'; exit 1 } $expected = ($sum -split '\\s+')[0].ToLower(); $actual = (Get-FileHash -Algorithm SHA256 '%TMPDIR%\\%FILE%').Hash.ToLower(); if ($expected -ne $actual) { Write-Host 'Checksum failed.'; exit 1 } Write-Host '%FILE%: OK' }" || goto :error

powershell -Command "& { Expand-Archive -Force '%TMPDIR%\\%FILE%' '%TMPDIR%\\' }" || goto :error

if not exist "%ROOTDIR%\\bin-backup\\bitcoin" mkdir "%ROOTDIR%\\bin-backup\\bitcoin"
if exist "%ROOTDIR%\\win\\bin\\bitcoin-qt.exe" copy /y "%ROOTDIR%\\win\\bin\\bitcoin-qt.exe" "%ROOTDIR%\\bin-backup\\bitcoin\\" >nul
if exist "%ROOTDIR%\\win\\bin\\bitcoind.exe" copy /y "%ROOTDIR%\\win\\bin\\bitcoind.exe" "%ROOTDIR%\\bin-backup\\bitcoin\\" >nul
if exist "%ROOTDIR%\\win\\bin\\bitcoin-cli.exe" copy /y "%ROOTDIR%\\win\\bin\\bitcoin-cli.exe" "%ROOTDIR%\\bin-backup\\bitcoin\\" >nul
if exist "%ROOTDIR%\\win\\bin\\bitcoin-wallet.exe" copy /y "%ROOTDIR%\\win\\bin\\bitcoin-wallet.exe" "%ROOTDIR%\\bin-backup\\bitcoin\\" >nul
if exist "%ROOTDIR%\\win\\bin\\bitcoin-tx.exe" copy /y "%ROOTDIR%\\win\\bin\\bitcoin-tx.exe" "%ROOTDIR%\\bin-backup\\bitcoin\\" >nul
if exist "%ROOTDIR%\\win\\bin\\bitcoin-util.exe" copy /y "%ROOTDIR%\\win\\bin\\bitcoin-util.exe" "%ROOTDIR%\\bin-backup\\bitcoin\\" >nul
if exist "%ROOTDIR%\\win\\bin\\bitcoin.exe" copy /y "%ROOTDIR%\\win\\bin\\bitcoin.exe" "%ROOTDIR%\\bin-backup\\bitcoin\\" >nul

if not exist "%TMPDIR%\\bitcoin-%VERSION%\\bin\\bitcoin-qt.exe" (
    echo Error: extracted binaries not found.
    goto :error
)
copy /y "%TMPDIR%\\bitcoin-%VERSION%\\bin\\*.exe" "%ROOTDIR%\\win\\bin\\" >nul

call :update_checksum "win\\bin\\bitcoin-qt.exe"
call :update_checksum "win\\bin\\bitcoind.exe"
call :update_checksum "win\\bin\\bitcoin-cli.exe"
call :update_checksum "win\\bin\\bitcoin-wallet.exe"
call :update_checksum "win\\bin\\bitcoin-tx.exe"
call :update_checksum "win\\bin\\bitcoin-util.exe"
call :update_checksum "win\\bin\\bitcoin.exe"

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
if not exist "%FILEPATH%" exit /b 0
powershell -Command "& { $file = '%FILEPATH%'; $checksum = '%CHECKSUM_FILE%'; if (!(Test-Path $checksum)) { Write-Host 'Warning: checksums.sha256 not found; skipping.'; exit 0 } $hash = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower(); $lines = Get-Content $checksum; $escaped = [regex]::Escape($file); $lines = $lines | Where-Object { $_ -notmatch ('\\s' + $escaped + '$') }; $lines += \"$hash  $file\"; Set-Content -Encoding ASCII $checksum $lines }"
exit /b 0

:error
echo Update failed.
set STATUS=1

:cleanup
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
popd >nul 2>&1
endlocal
exit /b %STATUS%
