# win\scripts\utilities\clean-artifacts.bat where PowerShell does not
# start: it says so and exits 1, rather than reporting the cleanup done.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

Remove-Item Env:PORTANODE_ROOT -ErrorAction SilentlyContinue
# :pause_if_own_console in win\scripts\root.bat waits 30 seconds in a
# console opened for the script, and returns at once where this is set.
$env:PORTANODE_LAUNCHER = '1'
$cmd = Join-Path $env:SystemRoot 'System32\cmd.exe'

# A PATH naming no directory leaves cmd.exe unable to find powershell.
$path = $env:PATH
$env:PATH = Join-Path $repo 'no-such-directory'
Push-Location -LiteralPath $repo
try {
  $out = & $cmd /d /c '.\win\scripts\utilities\clean-artifacts.bat' 2>&1
  $status = $LASTEXITCODE
} finally {
  Pop-Location
  $env:PATH = $path
}
$text = $out | Out-String
Test-Contain 'clean-artifacts.bat says PowerShell did not run the cleanup' `
  $text 'Error: PowerShell did not run the cleanup.'
Test-Same 'clean-artifacts.bat does not report the cleanup complete' `
  'False' "$($text.Contains('Cleanup complete.'))"
Test-Same 'clean-artifacts.bat exits 1' '1' "$status"

Complete-Test
