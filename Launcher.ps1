Param()

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Bat = Join-Path $Root "Launcher.bat"

if (Test-Path $Bat) {
    & $Bat
    exit $LASTEXITCODE
}

Write-Error "Launcher.bat not found."
exit 1
