# Tests win/scripts/bitcoin/node-args.ps1, which reads a running node's
# network switches for the Windows mainnet launcher. It starts no process
# and reads no process list, so PowerShell runs it on any system:
#
#   pwsh -NoProfile -File tests/win/node-args.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\win\node-args.ps1
#
# It prints one line per case, "ok" or "not ok" and then the case, and
# exits 1 where any case failed.

# Dot-sourced by a relative name from its own directory:
# win/scripts/root.ps1 says why.
Push-Location -LiteralPath (Join-Path $PSScriptRoot '../../win/scripts/bitcoin')
try { . ./node-args.ps1 } finally { Pop-Location }

$script:failed = 0

function Test-Case {
  param([string]$Description, $Got, $Want)
  if ($Got -eq $Want) {
    Write-Output "ok $Description"
  } else {
    Write-Output "not ok $Description (wanted $Want, got $Got)"
    $script:failed += 1
  }
}

$qt = '"D:\portanode\win\bin\bitcoin-qt.exe"'

# ISS 676: a network switch inside a path is not the switch, quoted or not.
$mainnet = @(
  '"D:\btc-testnet-old\win\bin\bitcoin-qt.exe" -datadir="D:\btc-testnet-old\bitcoin-datadir"',
  'D:\btc-testnet-old\win\bin\bitcoin-qt.exe -datadir=D:\btc-testnet-old\bitcoin-datadir',
  'D:\my -regtest\win\bin\bitcoind.exe -datadir=D:\x',
  "$qt -datadir=`"D:\btc -regtest\bitcoin-datadir`"",
  "$qt -datadir=D:\btc-regtest-old\data",
  "$qt -datadir=D:\btc-signet-old -uacomment=x",
  "$qt -datadir=D:\btc-testnet4-old",
  "$qt -datadir=D:\chain=regtest",
  "$qt -uacomment=-regtest",
  "$qt -testnet=0",
  "$qt -testnet=00",
  "$qt -testnet=abc",
  "$qt -testnet=-",
  "$qt -testnet=`" `"",
  "$qt -notestnet",
  "$qt -notestnet=",
  "$qt -notestnet=1",
  "$qt -chain=main",
  "$qt -chain=testnet",
  "$qt -chain=testnet3",
  "$qt -chain=regtestx",
  "$qt -regtest.port=1",
  $qt
)
foreach ($c in $mainnet) {
  Test-Case -Description "mainnet: $c" -Got (Test-MainnetNode $c) -Want $true
}

$other = @(
  "$qt -testnet",
  "$qt -testnet=1",
  "$qt -testnet=2",
  "$qt -testnet=-1",
  "$qt -testnet=01",
  "$qt -testnet=",
  "$qt -testnet=`" 1`"",
  "$qt -notestnet=0",
  "$qt -notestnet=abc",
  "$qt -testnet4",
  "$qt -signet",
  "$qt -regtest",
  "$qt --regtest",
  "$qt /regtest",
  "$qt -REGTEST",
  "$qt `"-regtest`"",
  "$qt -chain=test",
  "$qt -chain=testnet4",
  "$qt -chain=signet",
  "$qt -chain=regtest",
  "$qt --chain=regtest",
  "$qt -datadir=`"D:\btc testnet\data`" -regtest",
  "D:\btc-testnet-old\win\bin\bitcoind.exe -datadir=D:\btc-testnet-old -testnet4"
)
foreach ($c in $other) {
  Test-Case -Description "other network: $c" -Got (Test-MainnetNode $c) -Want $false
}

Test-Case -Description 'split: quoted program and value' `
  -Got ((Split-CommandLine '"C:\a b\x.exe" -datadir="D:\c d" -regtest') -join '|') `
  -Want 'C:\a b\x.exe|-datadir=D:\c d|-regtest'
Test-Case -Description 'split: unterminated quote' `
  -Got ((Split-CommandLine 'x.exe -datadir="D:\c d') -join '|') `
  -Want 'x.exe|-datadir=D:\c d'

if ($script:failed -gt 0) {
  Write-Output "$script:failed case(s) failed"
  exit 1
}
Write-Output 'Every case passed.'
