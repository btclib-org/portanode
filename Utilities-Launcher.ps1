Param()

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$Scripts = @{
    "1" = Join-Path $Root "win\scripts\utilities\update-bitcoin.bat"
    "2" = Join-Path $Root "win\scripts\utilities\update-electrum.bat"
    "3" = Join-Path $Root "win\scripts\utilities\verify-binaries.bat"
    "4" = Join-Path $Root "win\scripts\utilities\validate-setup.bat"
    "5" = Join-Path $Root "win\scripts\utilities\set-permissions.bat"
    "6" = Join-Path $Root "win\scripts\utilities\health-check.bat"
    "7" = Join-Path $Root "win\scripts\utilities\monitor-bitcoin-log.bat"
    "8" = Join-Path $Root "win\scripts\utilities\rotate-bitcoin-log.bat"
    "9" = Join-Path $Root "win\scripts\utilities\clean-artifacts.bat"
}

while ($true) {
    Write-Host "Utilities Launcher"
    Write-Host "1) Update Bitcoin binaries"
    Write-Host "2) Update Electrum binaries"
    Write-Host "3) Verify binaries"
    Write-Host "4) Validate setup"
    Write-Host "5) Set permissions"
    Write-Host "6) Health check"
    Write-Host "7) Monitor Bitcoin log"
    Write-Host "8) Rotate Bitcoin log"
    Write-Host "9) Clean Windows artifacts"
    Write-Host "0) Exit"
    $choice = Read-Host "Select"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        $choice = "0"
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
