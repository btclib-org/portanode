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
    "1" = "win\scripts\bitcoin\mainnet-8333-qt.bat"
    "2" = "win\scripts\bitcoin\testnet3-18333-qt.bat"
    "3" = "win\scripts\bitcoin\testnet4-48333-qt.bat"
    "4" = "win\scripts\bitcoin\regtest-18444-Alice-qt.bat"
    "5" = "win\scripts\bitcoin\regtest-18444-Alice-qt-clean.bat"
    "6" = "win\scripts\bitcoin\regtest-18444-Alice-cli.bat"
    "7" = "win\scripts\bitcoin\regtest-18444-Alice-cli-clean.bat"
    "8" = "win\scripts\bitcoin\regtest-18555-Bob-qt.bat"
    "9" = "win\scripts\bitcoin\regtest-18555-Bob-qt-clean.bat"
    "10" = "win\scripts\bitcoin\regtest-18555-Bob-cli.bat"
    "11" = "win\scripts\bitcoin\regtest-18555-Bob-cli-clean.bat"
    "12" = "win\scripts\bitcoin\regtest-18666-Carol-qt.bat"
    "13" = "win\scripts\bitcoin\regtest-18666-Carol-qt-clean.bat"
    "14" = "win\scripts\bitcoin\regtest-18666-Carol-cli.bat"
    "15" = "win\scripts\bitcoin\regtest-18666-Carol-cli-clean.bat"
}

while ($true) {
    Write-Host "Bitcoin Launcher ($Root)"
    Write-Host "1) Mainnet (GUI)"
    Write-Host "2) Testnet3 (GUI)"
    Write-Host "3) Testnet4 (GUI)"
    Write-Host "4) Regtest Alice (GUI)"
    Write-Host "5) Regtest Alice (GUI, clean)"
    Write-Host "6) Regtest Alice (CLI)"
    Write-Host "7) Regtest Alice (CLI, clean)"
    Write-Host "8) Regtest Bob (GUI)"
    Write-Host "9) Regtest Bob (GUI, clean)"
    Write-Host "10) Regtest Bob (CLI)"
    Write-Host "11) Regtest Bob (CLI, clean)"
    Write-Host "12) Regtest Carol (GUI)"
    Write-Host "13) Regtest Carol (GUI, clean)"
    Write-Host "14) Regtest Carol (CLI)"
    Write-Host "15) Regtest Carol (CLI, clean)"
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
    # Test-Path -LiteralPath: see win/scripts/root.ps1 (#297) for why.
    if (-not (Test-Path -LiteralPath $scriptPath)) {
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
