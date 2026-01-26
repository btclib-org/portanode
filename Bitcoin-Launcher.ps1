Param()

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$Scripts = @{
    "1" = Join-Path $Root "win\scripts\bitcoin\mainnet-8333-qt.bat"
    "2" = Join-Path $Root "win\scripts\bitcoin\testnet3-18333-qt.bat"
    "3" = Join-Path $Root "win\scripts\bitcoin\regtest-18444-Alice-qt.bat"
    "4" = Join-Path $Root "win\scripts\bitcoin\regtest-18555-Bob-qt.bat"
    "5" = Join-Path $Root "win\scripts\bitcoin\regtest-18666-Carol-qt.bat"
}

while ($true) {
    Write-Host "Bitcoin Launcher"
    Write-Host "1) Mainnet (GUI)"
    Write-Host "2) Testnet3 (GUI)"
    Write-Host "3) Regtest Alice (GUI)"
    Write-Host "4) Regtest Bob (GUI)"
    Write-Host "5) Regtest Carol (GUI)"
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
