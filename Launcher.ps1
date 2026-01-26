Param()

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$Scripts = @{
    "1" = Join-Path $Root "win\scripts\bitcoin\mainnet-8333-qt.bat"
    "2" = Join-Path $Root "win\scripts\bitcoin\testnet3-18333-qt.bat"
    "3" = Join-Path $Root "win\scripts\bitcoin\regtest-18444-Alice-qt.bat"
    "4" = Join-Path $Root "win\scripts\bitcoin\regtest-18555-Bob-qt.bat"
    "5" = Join-Path $Root "win\scripts\bitcoin\regtest-18666-Carol-qt.bat"
    "6" = Join-Path $Root "win\scripts\electrum\mainnet.bat"
    "7" = Join-Path $Root "win\scripts\electrum\testnet.bat"
    "8" = Join-Path $Root "win\scripts\electrum\regtest.bat"
    "9" = Join-Path $Root "win\scripts\electrum\mainnet-local-server-only.bat"
}

while ($true) {
    Write-Host "PortaNode Launcher"
    Write-Host "1) Bitcoin Mainnet (GUI)"
    Write-Host "2) Bitcoin Testnet3 (GUI)"
    Write-Host "3) Bitcoin Regtest Alice (GUI)"
    Write-Host "4) Bitcoin Regtest Bob (GUI)"
    Write-Host "5) Bitcoin Regtest Carol (GUI)"
    Write-Host "6) Electrum Mainnet"
    Write-Host "7) Electrum Testnet"
    Write-Host "8) Electrum Regtest"
    Write-Host "9) Electrum Mainnet (local server only)"
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
