# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# The sync figure of win\scripts\utilities\health-check.bat. It is
# PowerShell in a batch string, so the test reads that text from the file
# and runs it with a stand-in for bitcoin-cli, as updater-input.ps1 does.
# cmd.exe does not run here, so the cases run on any system with pwsh.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

$bat = Join-Path $repo 'win\scripts\utilities\health-check.bat'
$lines = @(Get-Content -LiteralPath $bat | Where-Object {
    $_.Contains('verificationprogress') -and $_.Contains('-Command "') })
Test-Same 'health-check.bat has the one sync line this test reads' '1' $lines.Count
$line = $lines[0]
$start = $line.IndexOf('-Command "') + 10
$text = $line.Substring($start, $line.LastIndexOf('"') - $start)

# The stand-in answers getblockchaininfo with PORTANODE_TEST_SYNC as its
# verificationprogress. $Culture is the culture the text runs under.
$env:BTC_CLI = 'Invoke-StandIn'
function Get-Sync {
  param([string]$Progress, [string]$Culture = 'en-US')
  $env:PORTANODE_TEST_SYNC = $Progress
  $prefix = "[Threading.Thread]::CurrentThread.CurrentCulture = [cultureinfo]'$Culture'; " +
    'function Invoke-StandIn { ''{"verificationprogress": '' + $env:PORTANODE_TEST_SYNC + ''}'' }; '
  [string](& ([scriptblock]::Create($prefix + $text)))
}

try {
  Test-Same 'a node at 1 reads 100.00' '100.00' (Get-Sync '1')
  # A fraction short of 1 is cut, so none reads 100.00: 0.9999967 is a
  # node about one block behind its best header.
  foreach ($progress in '0.99995', '0.9999967', '0.999999999') {
    Test-Same "a node at $progress reads 99.99" '99.99' (Get-Sync $progress)
  }
  Test-Same 'a node at 0.29 reads 29.00' '29.00' (Get-Sync '0.29')
  Test-Same 'a node at 1.2e-05 reads 0.00' '0.00' (Get-Sync '1.2e-05')

  # The control shows the culture reaches the text: it formats with a comma.
  $comma = [string](& ([scriptblock]::Create(
    "[Threading.Thread]::CurrentThread.CurrentCulture = [cultureinfo]'it-IT'; (0.5).ToString('F2')")))
  Test-Same 'it-IT formats 0.5 as 0,50' '0,50' $comma
  Test-Same 'under it-IT a node at 0.995 reads 99.50' '99.50' (Get-Sync '0.995' 'it-IT')
} finally {
  Remove-Item Env:BTC_CLI, Env:PORTANODE_TEST_SYNC -ErrorAction SilentlyContinue
}

Complete-Test
