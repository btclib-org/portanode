@echo off
REM Verify PortaNode binaries against win/checksums.sha256

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"
set CHECKSUM_FILE=%ROOTDIR%\win/checksums.sha256

pushd "%ROOTDIR%" >nul 2>&1

if not exist "%CHECKSUM_FILE%" (
    echo Error: %CHECKSUM_FILE% not found.
    popd >nul 2>&1
    exit /b 1
)

echo Verifying binaries...

powershell -Command "& { $ErrorActionPreference = 'Stop'; $lines = Get-Content '%CHECKSUM_FILE%'; $map = @{}; foreach ($line in $lines) { if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^[\\s]*#') { continue } $m = [regex]::Match($line, '^(?<hash>[0-9a-fA-F]{64})\\s+(?<path>.+?)(?:\\s+version=(?<ver>.+))?$'); if (-not $m.Success) { Write-Host \"Malformed line: $line\"; exit 1 } $hash = $m.Groups['hash'].Value.ToLower(); $path = $m.Groups['path'].Value.Trim(); if (-not $path.ToLower().StartsWith('win/')) { continue } $ver = $m.Groups['ver'].Value; if ([string]::IsNullOrWhiteSpace($ver)) { $ver = 'unknown' } if (-not $map.ContainsKey($path)) { $map[$path] = @() } $map[$path] += [pscustomobject]@{ Hash = $hash; Version = $ver } } $fail = 0; foreach ($path in $map.Keys) { if (-not (Test-Path $path)) { Write-Host \"$path : MISSING\"; $fail++; continue } $computed = (Get-FileHash -Algorithm SHA256 $path).Hash.ToLower(); $matches = $map[$path] | Where-Object { $_.Hash -eq $computed }; if ($matches.Count -gt 0) { $versions = ($matches | Select-Object -ExpandProperty Version | Select-Object -Unique) -join ', '; Write-Host \"$path : OK (version: $versions)\" } else { Write-Host \"$path : FAILED\"; $fail++ } } if ($fail -gt 0) { Write-Host \"Verification failed: $fail file(s).\"; exit 1 } else { Write-Host \"Verification complete: all OK.\" } }"

set ERR=%ERRORLEVEL%
popd >nul 2>&1
exit /b %ERR%
