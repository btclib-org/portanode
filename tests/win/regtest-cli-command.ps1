# The set lines that build BITCOIND_CMD in the regtest CLI launchers, run
# as each launcher writes them, under folders whose paths hold an "&", a
# "^", a "!", parentheses and spaces. Each folder's path stays whole
# inside its own quote pair. A line written as set "BITCOIND_CMD=..." is
# run as written too, and fails where an "&" is in the path.
#
# The control runs every line as set "NAME=value", which
# .pre-commit-config.yaml's header says an "&" breaks, and expects it to.
#
# Then each launcher runs whole under the same folders, from a copy of
# win\scripts in the folder, or outside it where the folder holds a "^", with
# a stub for bitcoind.exe that writes the arguments it receives to a file and
# exits. The stub has to run, with the arguments the set lines build. The set
# lines can build the right value while the start line still loses it, as
# win\scripts\bitcoin\regtest-18444-Alice-cli.bat says (#757). The CLI
# console has to read the folder whole too. Each run leaves two consoles
# open, which cmd /k keeps, and the case closes them. A launcher started
# from the folder's root with COMSPEC unset, the state measured to make a
# bare cmd on a start line read the current directory, does not run a cmd.bat
# planted there (#672).
#
# The folders holding a "!" run again with DelayedExpansion at 1 in
# HKCU\Software\Microsoft\Command Processor, which a console started with
# no /v flag follows (#766). The test puts the key back as it found it,
# unless it is killed first.

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

# Builds the folder: the markers of a root and the binaries, and a copy of
# win\scripts under $Base. In the copy of lib.bat, the CLI console also writes
# the folder as it reads it, as it would read it in the btc macro, to the
# file $env:CONSOLE_OUT names.
function Build-Root {
  param([string]$Root, [string]$Base, [string]$Stub)
  New-Item -ItemType Directory -Path (Join-Path $Root 'win\bin') | Out-Null
  New-Item -ItemType File -Path (Join-Path $Root 'VERSION') | Out-Null
  New-Item -ItemType File -Path (Join-Path $Root 'win\bin\bitcoin-cli.exe') | Out-Null
  Copy-Item -LiteralPath $Stub -Destination (Join-Path $Root 'win\bin\bitcoind.exe')
  New-Item -ItemType Directory -Path (Join-Path $Base 'win') -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $repo 'win\scripts') `
    -Destination (Join-Path $Base 'win\scripts') -Recurse
  $lib = Join-Path $Base 'win\scripts\bitcoin\lib.bat'
  $body = foreach ($line in Get-Content -LiteralPath $lib) {
    $line
    if ($line -like 'doskey btc=*') { '> "%CONSOLE_OUT%" echo "%ROOTDIR%"' }
  }
  [IO.File]::WriteAllText($lib, (($body -join "`r`n") + "`r`n"), [Text.Encoding]::ASCII)
}

# Runs $Command, a launcher, whole, with $Root as the folder and $From as the
# current directory, so that the path is not on this command line. Returns
# what the stub wrote, its arguments one per line, as Arguments, and what the
# CLI console wrote as Console. Either is empty where it never ran.
# The launcher reads one line, which answers the clean variants' pause.
function Get-Started {
  param([string]$Command, [string]$Root, [string]$From)
  $out = Join-Path $Root 'stub-arguments.txt'
  $console = "$tmp\console.txt"
  Remove-Item -LiteralPath $console -ErrorAction SilentlyContinue
  $env:PORTANODE_ROOT = $Root
  $env:STUB_OUT = $out
  $env:CONSOLE_OUT = $console
  [IO.File]::WriteAllText("$tmp\enter.txt", "`r`n")
  $since = Get-Date
  # Files, not pipes: the consoles the launcher starts inherit its handles
  # and would hold a pipe open.
  $p = Start-Process -FilePath cmd.exe -ArgumentList "/d /c $Command" `
    -WorkingDirectory $From `
    -NoNewWindow -PassThru -RedirectStandardInput "$tmp\enter.txt" `
    -RedirectStandardOutput "$tmp\launcher-out.txt" `
    -RedirectStandardError "$tmp\launcher-err.txt"
  if (-not $p.WaitForExit(60000)) { $p.Kill() }
  $deadline = (Get-Date).AddSeconds(15)
  while (-not ((Test-Path -LiteralPath $out) -and (Test-Path -LiteralPath $console)) -and
    (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 200
  }
  Start-Sleep -Milliseconds 500
  # The consoles are the cmd.exe processes the launcher started.
  Get-CimInstance Win32_Process -Filter "ParentProcessId = $($p.Id)" |
    Where-Object { $_.Name -eq 'cmd.exe' -and $_.CreationDate -ge $since } |
    ForEach-Object { & taskkill.exe /pid $_.ProcessId /t /f 2>&1 | Out-Null }
  $started = @{ Arguments = ''; Console = '' }
  if (Test-Path -LiteralPath $out) {
    $started.Arguments = ([IO.File]::ReadAllText($out)).TrimEnd("`n") -replace "`r", ''
  }
  if (Test-Path -LiteralPath $console) {
    $started.Console = ([IO.File]::ReadAllText($console)).TrimEnd()
  }
  $started
}

# Runs each launcher whole under each of $Roots, and checks the stub's
# arguments and what the CLI console read.
function Test-Start {
  param([string[]]$Roots, [string]$Suffix)
  foreach ($file in $launchers) {
    $text = Get-Content -LiteralPath $file.FullName
    $lines = @($text | Where-Object { $_ -match '^set "?BITCOIND_CMD=' })
    $datadirLine = @($text | Where-Object { $_ -like 'set "DATADIR=*' })[0]
    $sub = ($datadirLine -replace '^set "DATADIR=%ROOTDIR%', '').TrimEnd('"')
    foreach ($r in $Roots) {
      # A folder of its own per run, so that no run reads another's data.
      $script:n++
      $root = Join-Path $tmp "start$script:n\$r"
      # A launcher run from a folder holding a "^" exits 1 with "The system
      # cannot find the path specified", so win\scripts stays outside it.
      $base = if ($r -like '*^*') { Join-Path $tmp "scripts$script:n" } else { $root }
      Build-Root -Root $root -Base $base -Stub $stub
      $built = Get-Expected -Lines $lines -Root $root -Name $file.BaseName `
        -Datadir ($root + $sub)
      $want = Get-ArgumentList ($built -replace '^BITCOIND_CMD=', '')
      $started = Get-Started -Command $file.Name -Root $root `
        -From (Join-Path $base 'win\scripts\bitcoin')
      Test-Same "$($file.Name) starts bitcoind under the folder [$r]$Suffix" `
        $want $started.Arguments
      Test-Same "$($file.Name) CLI console reads the folder [$r]$Suffix" `
        "`"$root`"" $started.Console
    }
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
      $want = Get-Expected -Lines $lines -Root $root -Name $file.BaseName `
        -Datadir ($root + $sub)
      $built = Get-Built -Name $file.BaseName -DatadirLine $datadirLine `
        -Lines $lines -Root $root
      Test-Same "$($file.Name) keeps the folder [$r] whole in BITCOIND_CMD" $want $built
    }
    $root = Join-Path $tmp 'a&b'
    $quoted = $lines | ForEach-Object {
      if ($_ -match '^set "') { $_ } else { 'set "' + $_.Substring(4) + '"' }
    }
    $built = Get-Built -Name $file.BaseName -DatadirLine $datadirLine `
      -Lines $quoted -Root $root
    $want = Get-Expected -Lines $lines -Root $root -Name $file.BaseName `
      -Datadir ($root + $sub)
    Test-Same "control: $($file.Name) in set `"NAME=value`" form breaks at the &" `
      'False' "$($built -ceq $want)"
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
  Test-Start -Roots $roots -Suffix ''

  # Each planted cmd.bat leaves a file beside itself.
  $plant = @('@echo off', 'echo ran>"%~dp0%~n0.ran"')
  foreach ($file in $launchers) {
    $n++
    $root = Join-Path $tmp "start$n\plant"
    Build-Root -Root $root -Base $root -Stub $stub
    $ran = Join-Path $root 'cmd.ran'
    Set-Content -LiteralPath (Join-Path $root 'cmd.bat') -Encoding Ascii -Value $plant
    Set-Content -LiteralPath (Join-Path $root 'control.bat') -Encoding Ascii `
      -Value '@set "COMSPEC="', '@start "" /wait cmd /c exit'
    Push-Location -LiteralPath $root
    try { & cmd.exe /d /c control.bat | Out-Null } finally { Pop-Location }
    Test-Same "control: $($file.Name)'s folder runs the planted cmd.bat for a bare cmd with COMSPEC unset" `
      'True' "$(Test-Path -LiteralPath $ran)"
    Remove-Item -LiteralPath $ran -ErrorAction SilentlyContinue
    # From a batch file, because cmd.exe sets COMSPEC where it starts without one.
    Set-Content -LiteralPath (Join-Path $root 'go.bat') -Encoding Ascii -Value @(
      '@set "COMSPEC="', "@call win\scripts\bitcoin\$($file.Name)")
    $started = Get-Started -Command 'go.bat' -Root $root -From $root
    Test-Same "$($file.Name) started from the folder's root does not run its cmd.bat" `
      'False' "$(Test-Path -LiteralPath $ran)"
    Test-Same "$($file.Name) started from the folder's root starts bitcoind" `
      'True' "$($started.Arguments -ne '')"
  }

  $key = 'HKCU:\Software\Microsoft\Command Processor'
  $keyExisted = Test-Path -LiteralPath $key
  $before = (Get-ItemProperty -LiteralPath $key -Name DelayedExpansion `
      -ErrorAction SilentlyContinue).DelayedExpansion
  try {
    if (-not $keyExisted) { New-Item -Path $key | Out-Null }
    New-ItemProperty -LiteralPath $key -Name DelayedExpansion -PropertyType DWord `
      -Value 1 -Force | Out-Null
    Test-Same 'control: a cmd given no /v flag follows the registry value' `
      $env:OS "$(& cmd.exe /d /c 'echo !OS!')"
    # "!b!" names a variable no console defines and "!OS!" one every console
    # does; a lone "!" pairs with nothing.
    $bang = @($roots | Where-Object { $_ -like '*!*' }) + 'a !OS! c', 'a !b c'
    Test-Start -Roots $bang -Suffix ' with DelayedExpansion at 1'
  } finally {
    if (-not $keyExisted) {
      Remove-Item -LiteralPath $key -Recurse
    } elseif ($null -eq $before) {
      Remove-ItemProperty -LiteralPath $key -Name DelayedExpansion
    } else {
      Set-ItemProperty -LiteralPath $key -Name DelayedExpansion -Value $before
    }
  }
} finally {
  Remove-Item Env:ROOTDIR, Env:PORTANODE_ROOT, Env:PORTANODE_LAUNCHER, Env:STUB_OUT,
    Env:CONSOLE_OUT, Env:STUB_SOURCE, Env:STUB_EXE `
    -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
