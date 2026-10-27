# win\scripts\utilities\health-check.bat under a folder whose path holds
# an "&", with no node running and the files a node that stopped
# uncleanly leaves in its data directory. It lists both files and calls
# the node's state a maybe. bitcoind.pid names a process ID no process
# holds, so the check reads it as stale.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

# :pause_if_own_console in win\scripts\root.bat waits 30 seconds in a
# console opened for the script, and returns at once where this is set.
$env:PORTANODE_LAUNCHER = '1'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName

# Runs the check with PORTANODE_ROOT naming $Root and returns its output.
function Invoke-HealthCheck {
  param([string]$Root)
  $env:PORTANODE_ROOT = $Root
  Push-Location -LiteralPath $repo
  try {
    $out = @('') | & cmd.exe /d /c '.\win\scripts\utilities\health-check.bat' 2>&1
  } finally {
    Pop-Location
  }
  $out | Out-String
}

try {
  $root = Join-Path $tmp 'a & b (c)'
  New-Item -ItemType Directory -Path (Join-Path $root 'bitcoin-datadir') | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $root 'win') | Out-Null
  New-Item -ItemType File -Path (Join-Path $root 'VERSION') | Out-Null
  New-Item -ItemType File -Path (Join-Path $root 'bitcoin-datadir\.cookie') | Out-Null
  Set-Content -LiteralPath (Join-Path $root 'bitcoin-datadir\bitcoind.pid') -Value '99999999'

  $text = Invoke-HealthCheck $root
  Test-Contain 'health-check.bat lists the cookie and the stale pid file' `
    $text 'Bitcoin artifacts: .cookie bitcoind.pid (stale pid)'
  Test-Contain 'health-check.bat calls the node a maybe' `
    $text 'Bitcoin running: maybe (artifacts)'

  Remove-Item -LiteralPath (Join-Path $root 'bitcoin-datadir\bitcoind.pid')
  $text = Invoke-HealthCheck $root
  Test-Contain 'health-check.bat lists the cookie alone where it is the only file' `
    $text ('Bitcoin artifacts: .cookie' + [Environment]::NewLine)
} finally {
  Remove-Item Env:PORTANODE_ROOT -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
