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

REM Report binary versions from checksums
echo Binary versions:
powershell -Command "& { $checksum = '%ROOTDIR%\\win\\checksums.sha256'; if (-not (Test-Path $checksum)) { Write-Host '- win/checksums.sha256: missing'; exit 0 } $lines = Get-Content $checksum | Where-Object { $_ -and ($_ -notmatch '^[\\s]*#') }; $map = @{}; foreach ($line in $lines) { $m = [regex]::Match($line, '^(?<hash>[0-9a-fA-F]{64})\\s+(?<path>.+?)(?:\\s+version=(?<ver>.+))?$'); if (-not $m.Success) { continue } $path = $m.Groups['path'].Value.Trim(); if (-not $path.ToLower().StartsWith('win/')) { continue } $ver = $m.Groups['ver'].Value; if ([string]::IsNullOrWhiteSpace($ver)) { $ver = 'unknown' } if (-not $map.ContainsKey($path)) { $map[$path] = @() } $map[$path] += [pscustomobject]@{ Hash = $m.Groups['hash'].Value.ToLower(); Version = $ver } } foreach ($path in $map.Keys) { if (-not (Test-Path $path)) { Write-Host \"- $path: missing\"; continue } $computed = (Get-FileHash -Algorithm SHA256 $path).Hash.ToLower(); $matches = $map[$path] | Where-Object { $_.Hash -eq $computed }; if ($matches.Count -gt 0) { $versions = ($matches | Select-Object -ExpandProperty Version | Select-Object -Unique) -join ', '; Write-Host \"- $path: $versions\" } else { Write-Host \"- $path: unknown\" } } }"

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
