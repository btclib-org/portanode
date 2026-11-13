# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# The guard of the Alice -clean launchers, run whole while a stand-in node
# runs: it refuses where a node on bitcoin-datadir selects regtest on its
# command line, as win\scripts\bitcoin\node-args.ps1 reads it (#679), and
# goes on where the node selects another network or uses another data
# directory. It refuses as well where the node reaches bitcoin-datadir
# through a junction, and says it cannot tell where the node's data
# directory is relative or does not exist (ISS 888). Every clean launcher,
# Bob's and Carol's as well, refuses with stdin at end of input rather than
# take it for the Enter its prompt asks for (ISS 932).
#
# The stand-in is a program that sleeps, under the name of a node binary,
# started with the arguments of the case. The binaries under win\bin are
# empty files, which only the launchers' existence checks read. The test
# holds a file in bitcoin-datadir\regtest open, so a launcher that goes on
# past the guard fails to delete the directory and starts nothing.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

# :pause_if_own_console in win\scripts\root.bat waits 30 seconds in a
# console opened for the script, and returns at once where this is set.
$env:PORTANODE_LAUNCHER = '1'
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName
$root = Join-Path $tmp 'root'
$datadir = Join-Path $root 'bitcoin-datadir'
$netdir = Join-Path $datadir 'regtest'
$wallet = Join-Path $netdir 'wallet.dat'
$nodes = Join-Path $tmp 'nodes'
$junction = Join-Path $tmp 'junction'

# A node's data directory exists, or Core does not start: so does Bob's here.
New-Item -ItemType Directory -Path (Join-Path $root 'win\bin'), $netdir, $nodes,
  (Join-Path $datadir 'regtest_bob') | Out-Null
New-Item -ItemType Junction -Path $junction -Target $datadir | Out-Null
foreach ($name in 'VERSION', 'win\bin\bitcoind.exe', 'win\bin\bitcoin-cli.exe',
  'win\bin\bitcoin-qt.exe') {
  New-Item -ItemType File -Path (Join-Path $root $name) | Out-Null
}
$env:PORTANODE_ROOT = $root

# Add-Type writes a console program under Windows PowerShell only.
$env:PORTANODE_TEST_STUB = 'class P { static void Main() { System.Threading.Thread.Sleep(300000); } }'
& $powershell -NoProfile -Command `
  "Add-Type -TypeDefinition `$env:PORTANODE_TEST_STUB -OutputType ConsoleApplication -OutputAssembly '$(Join-Path $nodes 'bitcoind.exe')'"
Remove-Item Env:PORTANODE_TEST_STUB
Copy-Item -LiteralPath (Join-Path $nodes 'bitcoind.exe') -Destination (Join-Path $nodes 'bitcoin-qt.exe')

# {d} stands for bitcoin-datadir's full path, {f} for the same with forward
# slashes, {r} for the folder's root, and {j} for a junction to
# bitcoin-datadir.
$refused = @(
  @('bitcoind', '-datadir={d} -regtest'),
  @('bitcoind', '-regtest -datadir={d}'),
  @('bitcoind', '-datadir={d} -chain=regtest'),
  @('bitcoin-qt', '-chain=regtest -datadir="{d}"'),
  @('bitcoind', '-datadir={d} -noregtest=0'),
  @('bitcoind', '-rpcpassword=a\" -regtest -datadir={d}'),
  # ISS 830: Core trims no U+00A0, so this is a double negative.
  @('bitcoind', ('-datadir={d} -noregtest=' + [char]0xA0 + '1')),
  # ISS 831: other spellings of the same -datadir.
  @('bitcoind', '/datadir={d} -regtest'),
  @('bitcoind', '-DATADIR={d}\ -regtest'),
  @('bitcoind', '-datadir={f} -regtest'),
  @('bitcoin-qt', '-regtest -datadir="{r}\.\bitcoin-datadir"'),
  @('bitcoind', '-datadir="{d}. " -regtest'),
  @('bitcoind', '-datadir=\\.\{d} -regtest'),
  @('bitcoind', '-datadir={j} -regtest'))
$unknown = @(
  @('bitcoind', '-datadir=bitcoin-datadir -regtest'),
  @('bitcoind', '-datadir={r}\absent -regtest'))
$allowed = @(
  @('bitcoind', '-datadir={d}'),
  @('bitcoind', '-datadir={d} -chain=main'),
  @('bitcoind', '-datadir={d} -regtest=0'),
  @('bitcoind', '-datadir={d} -uacomment=-chain=regtest'),
  @('bitcoind', '-datadir={d} -uacomment="a\" -regtest"'),
  # "" inside a quoted run is a literal quote, so -regtest is in the value.
  @('bitcoind', '-datadir={d} -rpcpassword="a"" -regtest'),
  @('bitcoind', '-datadir={d}\regtest_bob -chain=regtest'),
  @('bitcoin-qt', '-chain=regtest -datadir={d}\regtest_bob'),
  # ISS 826: Core reads no switch after a lone "-".
  @('bitcoind', '-datadir={d} - -regtest'))

# Runs $Bat whole while the stand-in $Image runs with $Arguments, and returns
# its output and status.
function Invoke-Launcher {
  param([string]$Bat, [string]$Image, [string]$Arguments)
  if (-not (Test-Path -LiteralPath $wallet)) {
    New-Item -ItemType File -Path $wallet | Out-Null
  }
  $node = Start-Process -FilePath (Join-Path $nodes "$Image.exe") -PassThru `
    -WindowStyle Hidden -ArgumentList $Arguments.Replace('{d}', $datadir).Replace(
      '{f}', $datadir.Replace('\', '/')).Replace('{r}', $root).Replace('{j}', $junction)
  Push-Location -LiteralPath $repo
  try {
    # The line answers the launcher's Press Enter prompt, which
    # :require_confirmed in win\scripts\bitcoin\lib.bat reads.
    $out = @('') | & cmd.exe /d /c ('.\win\scripts\bitcoin\' + $Bat) 2>&1
    (($out | Out-String) + "status=$LASTEXITCODE")
  } finally {
    Pop-Location
    Stop-Process -Id $node.Id -Force
    $node.WaitForExit()
  }
}

$held = $null
try {
  # ISS 932: every clean launcher, with stdin at end of input and no node
  # running, refuses at its prompt and deletes nothing. Run before the file is
  # held, so that a launcher going on past the prompt deletes the wallet.
  $kept = @{
    'regtest-18444-Alice-qt-clean.bat' = $wallet
    'regtest-18444-Alice-cli-clean.bat' = $wallet
    'regtest-18555-Bob-qt-clean.bat' = Join-Path $datadir 'regtest_bob\wallet.dat'
    'regtest-18555-Bob-cli-clean.bat' = Join-Path $datadir 'regtest_bob\wallet.dat'
    'regtest-18666-Carol-qt-clean.bat' = Join-Path $datadir 'regtest_carol\wallet.dat'
    'regtest-18666-Carol-cli-clean.bat' = Join-Path $datadir 'regtest_carol\wallet.dat'
  }
  foreach ($bat in ($kept.Keys | Sort-Object)) {
    $file = $kept[$bat]
    if (-not (Test-Path -LiteralPath $file)) {
      New-Item -ItemType File -Path $file -Force | Out-Null
    }
    Push-Location -LiteralPath $repo
    try {
      $out = & cmd.exe /d /c ('.\win\scripts\bitcoin\' + $bat + ' < nul') 2>&1
      $text = ($out | Out-String) + "status=$LASTEXITCODE"
    } finally {
      Pop-Location
    }
    Test-Contain "$bat at end of input refuses" $text 'Error: no answer was read.'
    Test-Contain "$bat at end of input exits 1" $text 'status=1'
    Test-Same "$bat at end of input deletes nothing" 'True' "$(Test-Path -LiteralPath $file)"
  }

  $held = [IO.File]::Open((Join-Path $netdir 'held'), 'OpenOrCreate', 'ReadWrite', 'None')
  foreach ($bat in 'regtest-18444-Alice-qt-clean.bat', 'regtest-18444-Alice-cli-clean.bat') {
    foreach ($case in $refused) {
      $name = "$bat, $($case[0]) $($case[1])"
      $text = Invoke-Launcher -Bat $bat -Image $case[0] -Arguments $case[1]
      Test-Contain "$name refuses" $text 'Error: a Bitcoin node is using "bitcoin-datadir".'
      Test-Contain "$name exits 1" $text 'status=1'
      Test-Same "$name deletes nothing" 'True' "$(Test-Path -LiteralPath $wallet)"
    }
    foreach ($case in $unknown) {
      $name = "$bat, $($case[0]) $($case[1])"
      $text = Invoke-Launcher -Bat $bat -Image $case[0] -Arguments $case[1]
      Test-Contain "$name cannot tell" $text 'Error: could not tell whether a Bitcoin node is using'
      Test-Contain "$name exits 1" $text 'status=1'
      Test-Same "$name deletes nothing" 'True' "$(Test-Path -LiteralPath $wallet)"
    }
    foreach ($case in $allowed) {
      $name = "$bat, $($case[0]) $($case[1])"
      $text = Invoke-Launcher -Bat $bat -Image $case[0] -Arguments $case[1]
      Test-Contain "$name goes on past the guard" $text 'WARNING: This will delete regtest data.'
      Test-Same "$name does not refuse" 'False' "$($text.Contains('is using'))"
    }
  }
} finally {
  if ($held) { $held.Dispose() }
  # Deleting the junction alone leaves its target where it is.
  [IO.Directory]::Delete($junction)
  Remove-Item Env:PORTANODE_ROOT -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
