Param()

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$Scripts = @{
    "1" = Join-Path $Root "win\scripts\utilities\verify-binaries.bat"
    "2" = Join-Path $Root "win\scripts\utilities\validate-setup.bat"
    "3" = Join-Path $Root "win\scripts\utilities\health-check.bat"
    "4" = Join-Path $Root "win\scripts\utilities\rotate-bitcoin-log.bat"
    "5" = Join-Path $Root "win\scripts\utilities\monitor-bitcoin-log.bat"
    "6" = Join-Path $Root "win\scripts\utilities\clean-artifacts.bat"
    "7" = Join-Path $Root "win\scripts\utilities\set-permissions.bat"
}

while ($true) {
    Write-Host "Utilities Launcher"
    Write-Host "1) Verify binaries (Windows)"
    Write-Host "2) Validate setup (Windows)"
    Write-Host "3) Health check"
    Write-Host "4) Rotate Bitcoin log"
    Write-Host "5) Monitor Bitcoin log"
    Write-Host "6) Clean artifacts (Windows)"
    Write-Host "7) Set permissions"
    Write-Host "0) Exit"
    $choice = Read-Host "Select"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        exit 0
    }

    if ($choice -eq "0") {
        exit 0
    }

    if (-not $Scripts.ContainsKey($choice)) {
        Write-Host "Invalid selection."
        Write-Host ""
        continue
    }

    $scriptPath = $Scripts[$choice]
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Script not found: $scriptPath"
        Write-Host ""
        continue
    }

    & $scriptPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Command failed (exit $LASTEXITCODE)."
    }
    Write-Host ""
}
