# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# Tests win/scripts/bitcoin/node-args.ps1, which reads a running node's
# network switches and data directory for the Windows mainnet launcher and
# the guard of the Alice -clean launchers. It starts no process and reads no
# process list, so PowerShell runs it on any system:
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
  if ($Got -ceq $Want) {
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
  "$qt -regtest.port=1",
  "$qt -testnet=+-1",
  "$qt -testnet=0x1",
  "$qt -nochain -chain=main",
  "$qt -testnet=0 -chain=main",
  # A switch given twice takes its last value.
  "$qt -testnet -notestnet",
  "$qt -testnet -testnet=0",
  "$qt -testnet=1 -testnet=0",
  "$qt -regtest -noregtest",
  "$qt -chain=test -chain=main",
  "$qt -notestnet=0 -notestnet",
  # ISS 828: a backslash before a quote, as Windows reads it.
  ($qt + ' -datadir="C:\a\" -testnet'),
  ($qt + ' -uacomment="a"" -testnet"'),
  # ISS 826: Core reads no switch after a lone "-".
  "$qt - -regtest",
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
  "D:\btc-testnet-old\win\bin\bitcoind.exe -datadir=D:\btc-testnet-old -testnet4",
  "$qt -testnet=1abc",
  "$qt -testnet=99999999999",
  "$qt /-regtest",
  "$qt -TestNet4=1",
  # A switch given twice takes its last value.
  "$qt -notestnet -testnet",
  "$qt -testnet=0 -testnet",
  "$qt -noregtest -regtest",
  "$qt -chain=main -chain=test",
  "$qt -testnet -notestnet=0",
  # Core refuses to start on an unknown -chain name, or on two networks.
  "$qt -chain=testnet",
  "$qt -chain=testnet3",
  "$qt -chain=regtestx",
  "$qt -chain=MAIN",
  "$qt -Chain=Regtest",
  "$qt -chain",
  "$qt -nochain",
  "$qt -chain=main -testnet",
  "$qt -testnet -regtest",
  # ISS 828: a backslash before a quote, as Windows reads it.
  ($qt + ' -uacomment=a\" -testnet'),
  ($qt + ' -datadir="C:\a\\" -testnet')
)
foreach ($c in $other) {
  Test-Case -Description "not mainnet: $c" -Got (Test-MainnetNode $c) -Want $false
}

# ISS 679: the network Get-NodeChain reads, by the name -chain takes.
$chains = @(
  @("$qt", 'main'),
  @("$qt -regtest", 'regtest'),
  @("$qt --regtest", 'regtest'),
  @("$qt /regtest", 'regtest'),
  @("$qt -REGTEST", 'regtest'),
  @("$qt -regtest=", 'regtest'),
  @("$qt -noregtest=0", 'regtest'),
  @("$qt -noregtest -regtest", 'regtest'),
  @("$qt -chain=regtest", 'regtest'),
  @("$qt --chain=regtest", 'regtest'),
  @("$qt /chain=regtest", 'regtest'),
  @("$qt -CHAIN=regtest", 'regtest'),
  @("$qt -chain=main -chain=regtest", 'regtest'),
  @("$qt -chain=regtest -datadir=D:\x", 'regtest'),
  @("$qt -regtest=0", 'main'),
  @("$qt -noregtest", 'main'),
  @("$qt -regtest -noregtest", 'main'),
  @("$qt -chain=regtest -chain=main", 'main'),
  @("$qt -uacomment=-chain=regtest", 'main'),
  @("$qt -datadir=D:\chain=regtest", 'main'),
  @("$qt -chain=Regtest", 'Regtest'),
  @("$qt -testnet", 'test'),
  @("$qt -chain=test", 'test'),
  @("$qt -testnet4", 'testnet4'),
  @("$qt -signet", 'signet'),
  # ISS 828: a backslash before a quote, as Windows reads it.
  @(($qt + ' -rpcpassword=a\" -regtest'), 'regtest'),
  @(($qt + ' -uacomment=a\" -regtest'), 'regtest'),
  @(($qt + ' -uacomment="a\" b" -regtest'), 'regtest'),
  @(($qt + ' -blocknotify="echo \"%s\"" -regtest'), 'regtest'),
  @(($qt + ' -datadir="C:\a\\" -regtest'), 'regtest'),
  @(($qt + ' -datadir="C:\a\" -regtest'), 'main'),
  @(($qt + ' -uacomment="a"" -regtest"'), 'main'),
  # The program's name ends at a space outside quotes.
  @('"C:\n\bitcoind.exe"-regtest', 'main'),
  # ISS 826: Core reads no switch after a lone "-".
  @("$qt - -regtest", 'main'),
  @("$qt `"-`" -regtest", 'main'),
  @("$qt -regtest -", 'regtest'),
  @("$qt -regtest - -noregtest", 'regtest'),
  # ISS 830: Core trims only ASCII white space before the value's integer.
  @(("$qt -noregtest=" + [char]0xA0 + '1'), 'regtest'),
  @(("$qt -regtest=" + [char]0xA0 + '1'), 'main'),
  @(("$qt -regtest=" + [char]0x2003 + '1'), 'main'),
  @(("$qt -regtest=" + [char]11 + [char]12 + '1'), 'regtest'),
  @(("$qt -noregtest=" + [char]11 + '1'), 'main')
)
foreach ($c in $chains) {
  Test-Case -Description "chain: $($c[0])" -Got "$(Get-NodeChain $c[0])" -Want "$($c[1])"
}
foreach ($c in "$qt -chain=regtest -regtest", "$qt -regtest -testnet") {
  Test-Case -Description "chain, two networks: $c" -Got ($null -eq (Get-NodeChain $c)) -Want $true
}

# ISS 830: the white space Core trims, and only that.
$values = @(
  @(' 0', $true),
  @("`t`n`r0", $true),
  @(([string][char]11 + [char]12 + '0'), $true),
  @(([string][char]11 + '1'), $false),
  @(([string][char]0xA0 + '1'), $true),
  @(([string][char]0x2003 + '1'), $true),
  @(('1' + [char]0xA0), $false),
  @(([string][char]0xA0), $true)
)
foreach ($c in $values) {
  $shown = -join ($c[0].ToCharArray() | ForEach-Object { 'U+{0:X4}' -f [int]$_ })
  Test-Case -Description "value reads false: $shown" -Got (Test-ValueReadsFalse $c[0]) -Want $c[1]
}

# ISS 831: the data directory a node names, and the spellings the -clean
# guard counts as one.
$dd = 'C:\r\bitcoin-datadir'
$datadirs = @(
  @("$qt -datadir=$dd", $dd),
  @("$qt -datadir=`"$dd`"", $dd),
  @("$qt /datadir=$dd", $dd),
  @("$qt --DataDir=$dd", $dd),
  @("$qt -datadir=D:\x -datadir=$dd", $dd),
  @("$qt -datadir", ''),
  @("$qt -datadir=$dd - -datadir=D:\x", $dd)
)
foreach ($c in $datadirs) {
  Test-Case -Description "datadir: $($c[0])" -Got "$(Get-NodeDatadir $c[0])" -Want $c[1]
}
foreach ($c in "$qt", "$qt -uacomment=-datadir=$dd", "$qt - -datadir=$dd") {
  Test-Case -Description "datadir, none: $c" -Got ($null -eq (Get-NodeDatadir $c)) -Want $true
}

$sameDatadir = @(
  $dd,
  'C:\r\bitcoin-datadir\',
  'C:/r/bitcoin-datadir',
  'C:/r/bitcoin-datadir/',
  'C:\r\.\bitcoin-datadir',
  'C:\r\\bitcoin-datadir',
  'C:\r\x\..\bitcoin-datadir',
  'C:\..\r\bitcoin-datadir',
  'c:\R\Bitcoin-Datadir',
  'C:\r\bitcoin-datadir.',
  'C:\r.\bitcoin-datadir',
  'C:\r\bitcoin-datadir. .',
  'C:\r\bitcoin-datadir ',
  'C:\r\bitcoin-datadir.\'
)
# Device paths, which GetFullPath does not take back to the drive's path.
$deviceDatadir = @(
  '\\.\C:\r\bitcoin-datadir',
  '\\.\C:\r\.\x\..\bitcoin-datadir.',
  '\\?\C:\r\bitcoin-datadir',
  '\\?\C:\r\bitcoin-datadir\'
)
foreach ($d in @($sameDatadir) + $deviceDatadir) {
  # A space ends an unquoted value, and a backslash before the closing quote
  # would escape it.
  $forms = @()
  if (-not $d.Contains(' ')) { $forms += "-datadir=$d", "/datadir=$d" }
  if (-not $d.EndsWith('\')) { $forms += "-datadir=`"$d`"" }
  foreach ($form in $forms) {
    $line = "$qt $form -regtest"
    Test-Case -Description "on datadir: $line" -Got (Test-NodeOnDatadir $line $dd 'regtest') -Want $true
  }
}
$otherDatadir = @(
  "$qt -datadir=$dd\regtest_bob -regtest",
  "$qt -datadir=C:\r\bitcoin-datadir2 -regtest",
  "$qt -datadir=C:\r\bitcoin-datadir\.. -regtest",
  "$qt -datadir=$dd -datadir=D:\x -regtest",
  "$qt -uacomment=-datadir=$dd -regtest",
  "$qt - -datadir=$dd -regtest",
  "$qt -regtest",
  "$qt -datadir=$dd",
  "$qt -datadir=$dd - -regtest",
  # Windows normalizes no "\\?\" path, so its "." stays a name.
  "$qt -datadir=\\?\C:\r\.\bitcoin-datadir -regtest",
  "$qt -datadir=\\.\Volume{b75e2c83-0000-0000-0000-602f00000000}\r -regtest",
  # The backslash and the quote read as a quote inside the path.
  ($qt + ' -datadir="' + $dd + '\" -regtest')
)
foreach ($line in $otherDatadir) {
  Test-Case -Description "not on datadir: $line" -Got (Test-NodeOnDatadir $line $dd 'regtest') -Want $false
}
Test-Case -Description 'on datadir, any network' -Got (Test-NodeOnDatadir "$qt /datadir=$dd/" $dd '') -Want $true
Test-Case -Description 'on datadir, datadir with a trailing separator' `
  -Got (Test-NodeOnDatadir "$qt -datadir=$dd -regtest" 'C:\r\\bitcoin-datadir\' 'regtest') -Want $true

$keys = @(
  @('C:\a\.\b\..\c\', 'C:\a\c'),
  @('C:\..\..\a', 'C:\a'),
  @('\\srv\share\..\..\a', '\\srv\share\a'),
  @('//srv/share/a/./b', '\\srv\share\a\b'),
  @('\a\..\b', '\b'),
  @('C:\', 'C:'),
  @('C:\a\...\b', 'C:\a\...\b'),
  @('C:\a.\b..', 'C:\a\b'),
  @('C:\a\b. . ', 'C:\a\b'),
  @('C:\a\b \', 'C:\a\b '),
  @('\\.\C:\a\..\b.', 'C:\b'),
  @('\\?\C:\a\..\b.\', 'C:\a\..\b.'),
  @('\\.\Volume{x}\a\..', '\\.\Volume{x}\a\..')
)
foreach ($c in $keys) {
  Test-Case -Description "datadir key: $($c[0])" -Got (ConvertTo-DatadirKey $c[0]) -Want $c[1]
}
# On Windows the key of an absolute path that is not a device path is the
# path GetFullPath normalizes, its trailing separator dropped. GetFullPath
# would join a relative path to the working directory.
if ($env:OS -eq 'Windows_NT') {
  $absolute = @($keys | ForEach-Object { $_[0] } | Where-Object { $_ -notmatch '^\\([^\\]|\\[.?]\\)' })
  foreach ($d in @($sameDatadir) + $absolute) {
    Test-Case -Description "datadir key, GetFullPath: $d" `
      -Got (ConvertTo-DatadirKey $d) -Want ([IO.Path]::GetFullPath($d).TrimEnd([char]'\'))
  }
}

Test-Case -Description 'split: quoted program and value' `
  -Got ((Split-CommandLine '"C:\a b\x.exe" -datadir="D:\c d" -regtest') -join '|') `
  -Want 'C:\a b\x.exe|-datadir=D:\c d|-regtest'
Test-Case -Description 'split: unterminated quote' `
  -Got ((Split-CommandLine 'x.exe -datadir="D:\c d') -join '|') `
  -Want 'x.exe|-datadir=D:\c d'

# ISS 828: the rules of Microsoft's C runtime. The first six lines are the
# examples of Microsoft Learn's "Parsing C command-line arguments".
$splits = @(
  @('x.exe "a b c" d e', 'x.exe|a b c|d|e'),
  @('x.exe "ab\"c" "\\" d', 'x.exe|ab"c|\|d'),
  @('x.exe a\\\b d"e f"g h', 'x.exe|a\\\b|de fg|h'),
  @('x.exe a\\\"b c d', 'x.exe|a\"b|c|d'),
  @('x.exe a\\\\"b c" d e', 'x.exe|a\\b c|d|e'),
  @('x.exe a"b"" c d', 'x.exe|ab" c d'),
  @('x.exe -rpcpassword=a\" -regtest', 'x.exe|-rpcpassword=a"|-regtest'),
  @('x.exe -datadir="C:\a\" -regtest', 'x.exe|-datadir=C:\a" -regtest'),
  @('x.exe -datadir="C:\a\\" -regtest', 'x.exe|-datadir=C:\a\|-regtest'),
  @('x.exe -datadir=C:\a\\b\ -regtest', 'x.exe|-datadir=C:\a\\b\|-regtest'),
  @('x.exe "" -regtest', 'x.exe||-regtest'),
  @("x.exe`t-regtest", 'x.exe|-regtest'),
  @('"C:\a b\"x.exe -regtest', 'C:\a b\x.exe|-regtest')
)
foreach ($c in $splits) {
  Test-Case -Description "split: $($c[0])" -Got ((Split-CommandLine $c[0]) -join '|') -Want $c[1]
}

# ISS 888: on a data directory that resolves, a node's -datadir counts by the
# directory it resolves to. One that is relative or does not resolve throws,
# and so does a data directory that does not resolve where Windows does not
# answer that it is missing.
function Get-Answer {
  param([string]$CommandLine, [string]$Datadir)
  try { "$(Test-NodeOnDatadir $CommandLine $Datadir 'regtest')" } catch { 'threw' }
}

if ($env:OS -eq 'Windows_NT') {
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-node-args-' + [guid]::NewGuid())
  $real = Join-Path $tmp 'bitcoin-datadir'
  $junction = Join-Path $tmp 'junction'
  $other = Join-Path $tmp 'other'
  New-Item -ItemType Directory -Path $real, $other | Out-Null
  New-Item -ItemType Junction -Path $junction -Target $real | Out-Null
  try {
    # Each path is quoted, so a temporary directory holding a space stays
    # one argument.
    $resolved = @(
      @("$qt -datadir=`"$junction`" -regtest", $real, 'True'),
      @("$qt -datadir=`"$real`" -regtest", $junction, 'True'),
      @("$qt -datadir=`"$other`" -regtest", $real, 'False'),
      @("$qt -datadir=bitcoin-datadir -regtest", $real, 'threw'),
      @("$qt -datadir=`"$tmp\absent`" -regtest", $real, 'threw'),
      @("$qt -datadir=bitcoin-datadir -regtest", "$tmp\absent", 'False'),
      # Bob's first start under a bitcoin-datadir that does not exist:
      # ERROR_PATH_NOT_FOUND.
      @("$qt -datadir=`"$real`" -regtest", "$tmp\absent\regtest_bob", 'False'),
      # Windows refuses a name holding "?" with an error other than the two
      # that say it does not exist.
      @("$qt -datadir=`"$real`" -regtest", "$tmp\a?b", 'threw'))
    # The administrative share of the drive reaches the same directories
    # through SMB, under another final path, so only the volume serial number
    # and the file index match.
    $share = '\\localhost\' + $real.Substring(0, 1) + '$' + $real.Substring(2)
    if (Test-Path -LiteralPath $share) {
      Test-Case -Description "the share's final path is not the directory's: $share" `
        -Got ((Resolve-Datadir $share).Path.StartsWith('\Device\Mup\')) -Want $true
      $shareOther = '\\localhost\' + $other.Substring(0, 1) + '$' + $other.Substring(2)
      $resolved += @(
        @("$qt -datadir=`"$share`" -regtest", $real, 'True'),
        @("$qt -datadir=`"$real`" -regtest", $share, 'True'),
        @("$qt -datadir=`"$shareOther`" -regtest", $real, 'False'))
    } else {
      Write-Output "# no administrative share reaches $($real): the share cases are skipped"
    }
    foreach ($c in $resolved) {
      Test-Case -Description "resolved datadir: $($c[0]) on $($c[1])" `
        -Got (Get-Answer $c[0] $c[1]) -Want $c[2]
    }
  } finally {
    # Deleting the junction alone leaves its target where it is.
    [IO.Directory]::Delete($junction)
    Remove-Item -LiteralPath $tmp -Recurse -Force
  }
}

# The same rules on any system, with Resolve-Datadir replaced by a table. A
# path the table does not hold reads as missing, and one it holds as $null
# throws, as where Windows answers with another error.
$datadirs = @{
  'C:\r\bitcoin-datadir' = [pscustomobject]@{
    Path = '\Device\HarddiskVolume1\r\bitcoin-datadir'; Volume = 7; Index = 42 }
  'D:\link' = [pscustomobject]@{
    Path = '\Device\HarddiskVolume1\R\Bitcoin-Datadir'; Volume = 7; Index = 42 }
  '\\srv\share\link' = [pscustomobject]@{
    Path = '\Device\Mup\srv\share\link'; Volume = 7; Index = 42 }
  'D:\other' = [pscustomobject]@{
    Path = '\Device\HarddiskVolume2\other'; Volume = 8; Index = 42 }
  'D:\zero' = [pscustomobject]@{
    Path = '\Device\HarddiskVolume3\zero'; Volume = 0; Index = 43 }
  'D:\locked' = $null
}
function Resolve-Datadir {
  param([string]$Path)
  if (-not $datadirs.ContainsKey($Path)) { return $null }
  if ($null -eq $datadirs[$Path]) { throw "cannot open '$Path'" }
  return $datadirs[$Path]
}
$stubbed = @(
  @("$qt -datadir=D:\link -regtest", $dd, 'True'),
  @("$qt -datadir=\\srv\share\link -regtest", $dd, 'True'),
  @("$qt -datadir=D:\other -regtest", $dd, 'False'),
  @("$qt -datadir=D:\zero -regtest", $dd, 'threw'),
  @("$qt -datadir=D:\link -regtest", 'D:\locked', 'threw'),
  @("$qt -datadir=D:\locked -regtest", 'D:\locked', 'True'),
  @("$qt -datadir=D:\link -regtest", 'E:\absent', 'False'),
  @("$qt -datadir=D:\link", $dd, 'False'),
  @("$qt -datadir=bitcoin-datadir", $dd, 'False'),
  @("$qt -datadir=bitcoin-datadir -regtest", $dd, 'threw'),
  @("$qt -datadir=.\bitcoin-datadir -regtest", $dd, 'threw'),
  @("$qt -datadir=\r\bitcoin-datadir -regtest", $dd, 'threw'),
  @("$qt -datadir=C:bitcoin-datadir -regtest", $dd, 'threw'),
  @("$qt -datadir= -regtest", $dd, 'threw'),
  @("$qt -datadir=D:\absent -regtest", $dd, 'threw'),
  @("$qt -datadir=bitcoin-datadir -regtest", 'E:\absent', 'False'))
foreach ($c in $stubbed) {
  Test-Case -Description "resolved datadir, stubbed: $($c[0]) on $($c[1])" `
    -Got (Get-Answer $c[0] $c[1]) -Want $c[2]
}

if ($script:failed -gt 0) {
  Write-Output "$script:failed case(s) failed"
  exit 1
}
Write-Output 'Every case passed.'
