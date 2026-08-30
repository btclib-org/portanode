Param()

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptRoot "win\\scripts\\root.ps1")
$Root = Resolve-PortaNodeRoot -StartDir $ScriptRoot

# win\scripts\root.bat's :pause_if_own_console reads this. The menu
# below is the console a script returns to, so nothing it printed is
# discarded and a pause buys the reader nothing. The label cannot see
# that for itself: PowerShell runs a .bat through a cmd.exe of its own,
# whose command line names the script exactly as a double-click of it
# does.
$env:PORTANODE_LAUNCHER = "1"

$Scripts = @{
    "1" = "win\scripts\electrum\mainnet.bat"
    "2" = "win\scripts\electrum\testnet3.bat"
    "3" = "win\scripts\electrum\testnet4.bat"
    "4" = "win\scripts\electrum\regtest.bat"
    "5" = "win\scripts\electrum\mainnet-local-server-only.bat"
}

while ($true) {
    Write-Host "Electrum Launcher ($Root)"
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

    $scriptRel = $Scripts[$choice]
    $scriptPath = Join-Path $Root $scriptRel
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Script not found: $scriptRel"
        Write-Host ""
        continue
    }

    & $scriptPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Command failed (exit $LASTEXITCODE)."
    }
    Write-Host ""
}
