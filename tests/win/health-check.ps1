# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# win\scripts\utilities\health-check.bat under a folder whose path holds
# an "&", with no node running and the files a node that stopped
# uncleanly leaves in its data directory. It lists both files and calls
# the node's state a maybe. bitcoind.pid names a process ID no process
# holds, so the check reads it as stale.
#
# The same check started from the folder's root, which holds a
# powershell.bat and a tasklist.bat that would answer for the real
# commands there, as root.bat's :leave_folder says. Neither runs, and
# the free space is printed in GB, where a planted powershell.bat that
# ran would leave it "unknown".

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

# :pause_if_own_console in win\scripts\root.bat waits 30 seconds in a
# console opened for the script, and returns at once where this is set.
$env:PORTANODE_LAUNCHER = '1'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName

# Runs the check with PORTANODE_ROOT naming $Root and returns its output.
# It starts in $From, the checkout where none is given.
function Invoke-HealthCheck {
  param([string]$Root, [string]$From = $repo)
  $env:PORTANODE_ROOT = $Root
  $bat = Join-Path $repo 'win\scripts\utilities\health-check.bat'
  Push-Location -LiteralPath $From
  try {
    $out = @('') | & cmd.exe /d /c $bat 2>&1
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

  # Each planted command leaves a file named after it beside itself.
  $planted = 'powershell', 'tasklist'
  foreach ($name in $planted) {
    Set-Content -LiteralPath (Join-Path $root "$name.bat") -Encoding Ascii -Value @(
      '@echo off', 'echo ran>"%~dp0%~n0.ran"')
  }
  Push-Location -LiteralPath $root
  try {
    & cmd.exe /d /c 'powershell -NoProfile -Command exit' | Out-Null
  } finally {
    Pop-Location
  }
  Test-Same 'the planted powershell.bat runs for powershell from the folder''s root' `
    'True' "$(Test-Path -LiteralPath (Join-Path $root 'powershell.ran'))"
  Remove-Item -LiteralPath (Join-Path $root 'powershell.ran')

  $text = Invoke-HealthCheck $root $root
  foreach ($name in $planted) {
    Test-Same "health-check.bat started from the folder's root does not run its $name.bat" `
      'False' "$(Test-Path -LiteralPath (Join-Path $root "$name.ran"))"
  }
  Test-Same 'health-check.bat started from the folder''s root reports the free space' `
    'True' "$($text -match 'Disk free: \d+ GB')"
} finally {
  Remove-Item Env:PORTANODE_ROOT -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
