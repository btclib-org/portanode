Param()

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$Scripts = @{
    "1" = Join-Path $Root "win\scripts\electrum\mainnet.bat"
    "2" = Join-Path $Root "win\scripts\electrum\testnet.bat"
    "3" = Join-Path $Root "win\scripts\electrum\regtest.bat"
    "4" = Join-Path $Root "win\scripts\electrum\mainnet-local-server-only.bat"
}

while ($true) {
    Write-Host "Electrum Launcher"
    Write-Host "1) Mainnet"
    Write-Host "2) Testnet"
    Write-Host "3) Regtest"
    Write-Host "4) Mainnet (local server only)"
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
