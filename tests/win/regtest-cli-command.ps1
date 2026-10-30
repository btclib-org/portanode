# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# The set lines that build BITCOIND_CMD in the regtest CLI launchers, run
# as each launcher writes them, under folders whose paths hold an "&", a
# "^", a "!", parentheses and spaces. Each folder's path stays whole
# inside its own quote pair. A line written as set "BITCOIND_CMD=..." is
# run as written too, and fails where an "&" is in the path.
#
# The control runs every line as set "NAME=value", which
# .pre-commit-config.yaml's header says an "&" breaks, and expects it to.
#
# Then each launcher runs whole under the same folders, with a stub for
# bitcoind.exe that writes the arguments it receives to a file and exits.
# The stub has to run, with the arguments the set lines build. The set
# lines can build the right value while the start line still loses it,
# as win\scripts\bitcoin\regtest-18444-Alice-cli.bat says (#757). Each
# run leaves two consoles open, which cmd /k keeps, and the case closes
# them.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName

# What cmd.exe should leave in BITCOIND_CMD: the right-hand sides, less
# any outer quote pair, with each variable replaced by its value, and
# nothing else read.
function Get-Expected {
  param([string[]]$Lines, [string]$Root, [string]$Name, [string]$Datadir)
  $value = ''
  foreach ($line in $Lines) {
    $rhs = $line -replace '^set BITCOIND_CMD=', ''
    if ($line -match '^set "BITCOIND_CMD=') {
      $rhs = ($line -replace '^set "BITCOIND_CMD=', '') -replace '"$', ''
    }
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

# The arguments bitcoind.exe receives from the command $Value holds: each
# word after the first, quotes dropped, words split at spaces outside them.
function Get-ArgumentList {
  param([string]$Value)
  $words = [regex]::Matches($Value, '(?:"[^"]*"|[^\s"])+') |
    ForEach-Object { $_.Value.Replace('"', '') }
  @($words | Select-Object -Skip 1) -join "`n"
}

# Runs the launcher whole, with $Root as the folder, and returns what the
# stub wrote: its arguments, one per line, or nothing where it never ran.
# The launcher reads one line, which answers the clean variants' pause.
function Get-Started {
  param([string]$File, [string]$Root)
  $out = Join-Path $Root 'stub-arguments.txt'
  $env:PORTANODE_ROOT = $Root
  $env:STUB_OUT = $out
  [IO.File]::WriteAllText("$tmp\enter.txt", "`r`n")
  $since = Get-Date
  # Files, not pipes: the consoles the launcher starts inherit its handles
  # and would hold a pipe open.
  $p = Start-Process -FilePath cmd.exe -ArgumentList "/d /c `"$File`"" `
    -NoNewWindow -PassThru -RedirectStandardInput "$tmp\enter.txt" `
    -RedirectStandardOutput "$tmp\launcher-out.txt" `
    -RedirectStandardError "$tmp\launcher-err.txt"
  if (-not $p.WaitForExit(60000)) { $p.Kill() }
  $deadline = (Get-Date).AddSeconds(15)
  while (-not (Test-Path -LiteralPath $out) -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 200
  }
  Start-Sleep -Milliseconds 500
  # The consoles are the cmd.exe processes the launcher started.
  Get-CimInstance Win32_Process -Filter "ParentProcessId = $($p.Id)" |
    Where-Object { $_.Name -eq 'cmd.exe' -and $_.CreationDate -ge $since } |
    ForEach-Object { & taskkill.exe /pid $_.ProcessId /t /f 2>&1 | Out-Null }
  if (Test-Path -LiteralPath $out) {
    ([IO.File]::ReadAllText($out)).TrimEnd("`n") -replace "`r", ''
  }
}

# bitcoind.exe's stand-in, compiled by Windows PowerShell, whose Add-Type
# builds a console program where PowerShell 7's builds only a library.
$stubSource = @'
using System; using System.IO; using System.Text;
class Stub { static void Main(string[] args) {
  File.WriteAllText(Environment.GetEnvironmentVariable("STUB_OUT"),
    string.Join("\n", args) + "\n", new UTF8Encoding(false)); } }
'@

$roots = 'a&b', 'a & b', 'a ^ b', 'a !b! c', 'a (b) c', 'x & (y) ^z !w'
$launchers = @(Get-ChildItem -LiteralPath (Join-Path $repo 'win\scripts\bitcoin') `
    -Filter 'regtest-*-cli*.bat' | Sort-Object Name)
Test-Same 'the regtest CLI launchers are found' 'True' "$($launchers.Count -gt 0)"

try {
  foreach ($file in $launchers) {
    $text = Get-Content -LiteralPath $file.FullName
    $lines = @($text | Where-Object { $_ -match '^set "?BITCOIND_CMD=' })
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
    $quoted = $lines | ForEach-Object {
      if ($_ -match '^set "') { $_ } else { 'set "' + $_.Substring(4) + '"' }
    }
    $built = Get-Built $file.BaseName $datadirLine $quoted $root
    Test-Same "control: $($file.Name) in set `"NAME=value`" form breaks at the &" `
      'False' "$($built -ceq (Get-Expected $lines $root $file.BaseName ($root + $sub)))"
  }

  Remove-Item Env:ROOTDIR
  # :pause_if_own_console in win\scripts\root.bat waits 30 seconds in a
  # console opened for the script, and returns at once where this is set.
  $env:PORTANODE_LAUNCHER = '1'
  $stub = Join-Path $tmp 'stub.exe'
  Set-Content -LiteralPath "$tmp\stub.cs" -Value $stubSource -Encoding ascii
  # The paths reach Windows PowerShell through the environment, so that no
  # character in them is read as code.
  $env:STUB_SOURCE = "$tmp\stub.cs"
  $env:STUB_EXE = $stub
  & powershell.exe -NoProfile -Command ('Add-Type -TypeDefinition (Get-Content -Raw ' +
    '-LiteralPath $env:STUB_SOURCE) -OutputAssembly $env:STUB_EXE -OutputType ConsoleApplication')
  Test-Same 'the bitcoind.exe stub is built' 'True' "$(Test-Path -LiteralPath $stub)"
  $n = 0
  foreach ($file in $launchers) {
    $text = Get-Content -LiteralPath $file.FullName
    $lines = @($text | Where-Object { $_ -match '^set "?BITCOIND_CMD=' })
    $datadirLine = @($text | Where-Object { $_ -like 'set "DATADIR=*' })[0]
    $sub = ($datadirLine -replace '^set "DATADIR=%ROOTDIR%', '').TrimEnd('"')
    foreach ($r in $roots) {
      # A folder of its own per run, so that no run reads another's data.
      $n++
      $root = Join-Path $tmp "start$n\$r"
      New-Item -ItemType Directory -Path (Join-Path $root 'win\bin') | Out-Null
      New-Item -ItemType File -Path (Join-Path $root 'VERSION') | Out-Null
      New-Item -ItemType File -Path (Join-Path $root 'win\bin\bitcoin-cli.exe') | Out-Null
      Copy-Item -LiteralPath $stub -Destination (Join-Path $root 'win\bin\bitcoind.exe')
      $built = Get-Expected -Lines $lines -Root $root -Name $file.BaseName `
        -Datadir ($root + $sub)
      $want = Get-ArgumentList ($built -replace '^BITCOIND_CMD=', '')
      Test-Same "$($file.Name) starts bitcoind under the folder [$r]" `
        $want "$(Get-Started $file.FullName $root)"
    }
  }
} finally {
  Remove-Item Env:ROOTDIR, Env:PORTANODE_ROOT, Env:PORTANODE_LAUNCHER, Env:STUB_OUT,
    Env:STUB_SOURCE, Env:STUB_EXE `
    -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
