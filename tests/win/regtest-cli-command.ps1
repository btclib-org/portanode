# The set lines that build BITCOIND_CMD in the regtest CLI launchers, run
# as each launcher writes them, under folders whose paths hold an "&", a
# "^", a "!", parentheses and spaces. Each folder's path stays whole
# inside its own quote pair.
#
# The control rewrites the same lines as set "NAME=value", the form
# Blinter's SEC002 asks for. The value's own quotes then close the outer
# pair, so the "&" ends the set command and the value comes out wrong.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName

# What cmd.exe should leave in BITCOIND_CMD: the right-hand sides with
# each variable replaced by its value, and nothing else read.
function Get-Expected {
  param([string[]]$Lines, [string]$Root, [string]$Name, [string]$Datadir)
  $value = ''
  foreach ($line in $Lines) {
    $rhs = $line -replace '^set BITCOIND_CMD=', ''
    $rhs = $rhs.Replace('%BITCOIND_CMD%', $value).Replace('%ROOTDIR%', $Root)
    $value = $rhs.Replace('%DATADIR%', $Datadir).Replace('%~n0', $Name)
  }
  "BITCOIND_CMD=$value"
}

# Runs the lines in a file named after the launcher, so that %~n0 reads
# as it does there, and returns what set prints for BITCOIND_CMD.
function Get-Built {
  param([string]$Name, [string]$DatadirLine, [string[]]$Lines, [string]$Root)
  $bat = Join-Path $tmp "$Name.bat"
  $body = @('@echo off', 'setlocal disabledelayedexpansion', $DatadirLine) +
    $Lines + @('set BITCOIND_CMD')
  [IO.File]::WriteAllText($bat, (($body -join "`r`n") + "`r`n"), [Text.Encoding]::ASCII)
  $env:ROOTDIR = $Root
  $out = & cmd.exe /d /c "`"$bat`"" 2>$null
  @($out | Where-Object { $_ -like 'BITCOIND_CMD=*' }) -join "`n"
}

$roots = 'a&b', 'a & b', 'a ^ b', 'a !b! c', 'a (b) c', 'x & (y) ^z !w'
$launchers = @(Get-ChildItem -LiteralPath (Join-Path $repo 'win\scripts\bitcoin') `
    -Filter 'regtest-*-cli*.bat' | Sort-Object Name)
Test-Same 'the regtest CLI launchers are found' 'True' "$($launchers.Count -gt 0)"

try {
  foreach ($file in $launchers) {
    $text = Get-Content -LiteralPath $file.FullName
    $lines = @($text | Where-Object { $_ -like 'set BITCOIND_CMD=*' })
    $datadirLine = @($text | Where-Object { $_ -like 'set "DATADIR=*' })[0]
    $sub = ($datadirLine -replace '^set "DATADIR=%ROOTDIR%', '').TrimEnd('"')
    Test-Same "$($file.Name) builds BITCOIND_CMD in set lines" 'True' "$($lines.Count -gt 0)"
    foreach ($r in $roots) {
      $root = Join-Path $tmp $r
      $want = Get-Expected $lines $root $file.BaseName ($root + $sub)
      Test-Same "$($file.Name) keeps the folder [$r] whole in BITCOIND_CMD" `
        $want (Get-Built $file.BaseName $datadirLine $lines $root)
    }
    $root = Join-Path $tmp 'a&b'
    $quoted = $lines | ForEach-Object { 'set "' + $_.Substring(4) + '"' }
    $built = Get-Built $file.BaseName $datadirLine $quoted $root
    Test-Same "control: $($file.Name) in set `"NAME=value`" form breaks at the &" `
      'False' "$($built -ceq (Get-Expected $lines $root $file.BaseName ($root + $sub)))"
  }
} finally {
  Remove-Item Env:ROOTDIR -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
