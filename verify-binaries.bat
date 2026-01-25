@echo off
REM Verify PortaNode binaries against checksums.sha256

set CHECKSUM_FILE=checksums.sha256

if not exist "%CHECKSUM_FILE%" (
    echo Error: %CHECKSUM_FILE% not found.
    exit /b 1
)

echo Verifying binaries...

powershell -Command "& { $hashes = Get-Content '%CHECKSUM_FILE%'; $fail=0; foreach ($line in $hashes) { if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^[\\s]*#') { continue } $parts = $line -split '  ', 2; if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) { Write-Host \"Malformed line: $line\"; $fail++; continue } $hash = $parts[0].ToLower(); $file = $parts[1]; if (-not (Test-Path $file)) { Write-Host \"$file : MISSING\"; $fail++; continue } $computed = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower(); if ($computed -eq $hash) { Write-Host \"$file : OK\" } else { Write-Host \"$file : FAILED\"; $fail++ } } if ($fail -gt 0) { Write-Host \"Verification failed: $fail file(s).\"; exit 1 } else { Write-Host \"Verification complete: all OK.\" } }"
