# The usage line of the utilities that take options, given an option they
# know and then one they do not: each names itself, however many arguments
# it read before the one it refused.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

Remove-Item Env:PORTANODE_ROOT -ErrorAction SilentlyContinue
# :pause_if_own_console in win\scripts\root.bat waits 30 seconds in a
# console opened for the script, and returns at once where this is set.
$env:PORTANODE_LAUNCHER = '1'

# Runs the script with $Arguments from the repository's root, and returns
# its output followed by a line "exit <status>".
function Invoke-Script {
  param([string]$Script, [string[]]$Arguments)
  Push-Location -LiteralPath $repo
  try {
    $out = & cmd.exe /d /c ('.\win\scripts\utilities\' + $Script) @Arguments 2>&1
    $status = $LASTEXITCODE
  } finally {
    Pop-Location
  }
  (($out | Out-String) + "exit $status")
}

$cases = @(
  @('update-bitcoin.bat', @('--dry-run', '--bogus')),
  @('update-bitcoin.bat', @('--version', '1.0', '--bogus')),
  @('update-electrum.bat', @('--dry-run', '--bogus')),
  @('update-electrum.bat', @('--version', '1.0', '--bogus')),
  @('rollback-bitcoin.bat', @('--dry-run', '--bogus')),
  @('rollback-electrum.bat', @('--dry-run', '--bogus')),
  @('monitor-bitcoin-log.bat', @('--no-notify', '--bogus'))
)
foreach ($case in $cases) {
  $script, $arguments = $case
  $out = Invoke-Script $script $arguments
  $given = $arguments -join ' '
  Test-Contain "$script $given names itself in its usage line" `
    $out "Usage: $script ["
  Test-Same "$script $given exits 1" 'exit 1' (($out.Trim() -split "`r?`n")[-1])
}

Complete-Test
