Param()

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptRoot "win\\scripts\\root.ps1")
$Root = Resolve-PortaNodeRoot -StartDir $ScriptRoot

$Scripts = @{
    "1" = Join-Path $Root "win\scripts\electrum\mainnet.bat"
    "2" = Join-Path $Root "win\scripts\electrum\testnet3.bat"
    "3" = Join-Path $Root "win\scripts\electrum\testnet4.bat"
    "4" = Join-Path $Root "win\scripts\electrum\regtest.bat"
    "5" = Join-Path $Root "win\scripts\electrum\mainnet-local-server-only.bat"
}

while ($true) {
    Write-Host "Electrum Launcher"
    Write-Host "1) Mainnet"
    Write-Host "2) Testnet3"
    Write-Host "3) Testnet4"
    Write-Host "4) Regtest"
    Write-Host "5) Mainnet (local server only)"
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
