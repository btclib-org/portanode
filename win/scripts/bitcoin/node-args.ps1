# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# Reads Bitcoin Core's network switches and data directory out of a Windows
# command line.
# lib.bat beside this file dot-sources it, and tests/win/node-args.ps1
# tests it.
#
# A switch counts only as a whole argument, so a path holding "-regtest" is
# not the switch. Bitcoin Core picks its network this way
# (src/common/args.cpp, src/common/settings.cpp and src/util/chaintype.cpp in
# bitcoin/bitcoin): on Windows "-name", "--name" and "/name" alike, the name in
# any case, and no switch after a lone "-". A boolean switch is true bare, with
# an empty value, or with a value whose leading integer is not zero:
# "-regtest=2" is true, "-regtest=0" and "-regtest=abc" are false. "-noregtest"
# is false, and "-noregtest=0" is true.
# A switch given more than once takes its last value, and so does "-chain".
# "-chain=<name>" selects a network by name, testnet3's being "test", and Core
# refuses to start on an unknown name or on more than one network.
#
# Not read: bitcoin.conf, which can select a network and set the data
# directory too, and an argument Core refuses as unknown, which stops it
# before it runs.

function Split-CommandLine {
  # The arguments of a command line, the program first, as Bitcoin Core on
  # Windows receives them: the argv its main() takes (MAIN_FUNCTION in
  # src/compat/compat.h of bitcoin/bitcoin), as Microsoft's C runtime splits
  # the line (Microsoft Learn, "Parsing C command-line arguments"). A space
  # or a tab outside double quotes separates arguments and the quotes are
  # dropped, so -datadir="D:\a b" is one argument. 2n backslashes before a
  # quote read as n and a quote that opens or closes a quoted run, 2n+1 as n
  # and a literal quote, and a backslash before anything else as itself. ""
  # inside a quoted run reads as a literal quote and stays inside the run.
  # The program's name ends at a space outside quotes. A line that ends
  # inside quotes ends its last argument.
  param([string]$CommandLine)
  $line = $CommandLine
  $i = 0
  $word = New-Object System.Text.StringBuilder
  $quoted = $false
  while ($i -lt $line.Length -and ($quoted -or $line[$i] -notmatch '[ \t]')) {
    if ($line[$i] -eq '"') { $quoted = -not $quoted } else { [void]$word.Append($line[$i]) }
    $i++
  }
  $word.ToString()
  while ($true) {
    while ($i -lt $line.Length -and $line[$i] -match '[ \t]') { $i++ }
    if ($i -ge $line.Length) { break }
    $word = New-Object System.Text.StringBuilder
    # 1 inside a quoted run, 0 outside it.
    $quoted = 0
    $escaped = $false
    while ($i -lt $line.Length -and ($quoted -eq 1 -or $line[$i] -notmatch '[ \t]')) {
      if ($line[$i] -eq '\') {
        $run = 0
        while ($i -lt $line.Length -and $line[$i] -eq '\') { $run++; $i++ }
        if ($i -lt $line.Length -and $line[$i] -eq '"') {
          [void]$word.Append([char]'\', ($run - $run % 2) / 2)
          $escaped = ($run % 2 -eq 1)
        } else {
          [void]$word.Append([char]'\', $run)
        }
      } elseif ($line[$i] -eq '"') {
        if ($escaped) {
          [void]$word.Append([char]'"')
        } elseif ($quoted -eq 1 -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '"') {
          [void]$word.Append([char]'"')
          $i++
        } else {
          $quoted = 1 - $quoted
        }
        $i++
        $escaped = $false
      } else {
        [void]$word.Append($line[$i])
        $i++
      }
    }
    $word.ToString()
  }
}

function Test-ValueReadsFalse {
  # True where Core reads a boolean switch's value as false: a value that is
  # not empty and whose leading integer, after white space and one sign, is
  # zero or absent. The white space is Core's alone: space, tab, vertical tab,
  # form feed, line feed and carriage return (TrimStringView in
  # src/util/string.h).
  param([string]$Value)
  if ($Value -eq '') { return $false }
  $v = $Value.Trim([char[]](32, 12, 10, 13, 9, 11))
  if ($v -match '^[+-]') { $v = $v.Substring(1) }
  return $v -match '^0*($|[^0-9])'
}

function Get-NodeSwitch {
  # The switches of a node's command line in order, as Core reads them: each
  # a Name, lower case and without its dashes, and a Value, null where none
  # is given. Core reads no switch after a lone "-".
  param([string]$CommandLine)
  foreach ($word in @(Split-CommandLine $CommandLine | Select-Object -Skip 1)) {
    if ($word -ceq '-') { break }
    if ($word -notmatch '^[-/]') { continue }
    $word = $word.Substring(1)
    if ($word.StartsWith('-')) { $word = $word.Substring(1) }
    $eq = $word.IndexOf('=')
    if ($eq -lt 0) {
      [pscustomobject]@{ Name = $word.ToLowerInvariant(); Value = $null }
    } else {
      [pscustomobject]@{ Name = $word.Substring(0, $eq).ToLowerInvariant(); Value = $word.Substring($eq + 1) }
    }
  }
}

function Get-NodeChain {
  # The network a node's command line selects, by the name "-chain" takes:
  # "main" where no network switch is true and "-chain" is absent. Null where
  # more than one network is selected. An unknown "-chain" name is returned
  # as given.
  param([string]$CommandLine)
  $flags = @{ testnet = $false; testnet4 = $false; signet = $false; regtest = $false }
  $chain = $null
  foreach ($switch in @(Get-NodeSwitch $CommandLine)) {
    $name = $switch.Name
    $value = $switch.Value
    if ($flags.ContainsKey($name)) {
      $flags[$name] = ($null -eq $value -or -not (Test-ValueReadsFalse $value))
    } elseif ($name.StartsWith('no') -and $flags.ContainsKey($name.Substring(2))) {
      # Core skips a command line whose last value for the switch is a
      # negation, so the switch is false unless the negation is a double one.
      $flags[$name.Substring(2)] = ($null -ne $value -and (Test-ValueReadsFalse $value))
    } elseif ($name -eq 'chain') {
      $chain = if ($null -eq $value) { '' } else { $value }
    } elseif ($name -eq 'nochain') {
      # Core reads a negated -chain as "0" or "1", neither of them a network.
      $chain = '0'
    }
  }
  $selected = @($flags.Keys | Where-Object { $flags[$_] })
  if ($selected.Count + [int]($null -ne $chain) -gt 1) { return $null }
  if ($null -ne $chain) { return $chain }
  if ($selected.Count -eq 0) { return 'main' }
  if ($selected[0] -eq 'testnet') { return 'test' }
  return $selected[0]
}

function Get-NodeDatadir {
  # The data directory a node's command line names with "-datadir", the last
  # one where it names several, as Core reads it. Null where it names none.
  param([string]$CommandLine)
  $datadir = $null
  foreach ($switch in @(Get-NodeSwitch $CommandLine)) {
    if ($switch.Name -ceq 'datadir') { $datadir = "$($switch.Value)" }
  }
  return $datadir
}

function ConvertTo-DatadirKey {
  # One form for the spellings of an absolute Windows path that Windows
  # normalizes alike, following the steps of Microsoft Learn's "File path
  # formats on Windows systems": "/" read as "\", runs of separators
  # collapsed, "." segments dropped and ".." segments taken back, never past
  # the root; then the period of a segment ending in a single one is dropped
  # and, where the path does not end in a separator, every trailing period
  # and space. A trailing separator is dropped last. Case is left as given,
  # for the caller to ignore.
  #
  # A device path names a drive as that page says: "\\.\C:\x" is read as
  # "C:\x" normalized, and "\\?\C:\x" as "C:\x" with nothing normalized but
  # its trailing separator, since Windows normalizes no "\\?\" path. Any
  # other device path, as a volume GUID's, is returned as given, and so
  # matches only itself.
  param([string]$Path)
  if ($Path -match '^\\\\\?\\[A-Za-z]:(\\|$)') { return $Path.Substring(4).TrimEnd([char]'\') }
  $p = $Path.Replace('/', '\')
  if ($p -match '^\\\\[.?]\\') {
    if ($p -notmatch '^\\\\\.\\[A-Za-z]:(\\|$)') { return $Path }
    $p = $p.Substring(4)
  }
  $lead = ''
  $root = 0
  if ($p.StartsWith('\\')) {
    $lead = '\\'
    $root = 2
  } elseif ($p.StartsWith('\')) {
    $lead = '\'
  } elseif ($p -match '^[A-Za-z]:') {
    $root = 1
  }
  $kept = New-Object System.Collections.Generic.List[string]
  foreach ($segment in $p.Split([char]'\')) {
    if ($segment -eq '' -or $segment -eq '.') { continue }
    if ($segment -eq '..') {
      if ($kept.Count -gt $root) { $kept.RemoveAt($kept.Count - 1) }
      continue
    }
    if ($segment -match '[^.]\.$') { $segment = $segment.Substring(0, $segment.Length - 1) }
    $kept.Add($segment)
  }
  $key = $lead + ($kept -join '\')
  if (-not $p.EndsWith('\')) { $key = $key.TrimEnd([char[]]'. ').TrimEnd([char]'\') }
  return $key
}

function Test-NodeOnDatadir {
  # True where a node's command line names $Datadir as its data directory,
  # compared by ConvertTo-DatadirKey with case ignored, and, where $Chain is
  # not empty, selects the network Get-NodeChain names $Chain.
  param([string]$CommandLine, [string]$Datadir, [string]$Chain)
  $d = Get-NodeDatadir $CommandLine
  return ($null -ne $d -and [string]::Equals((ConvertTo-DatadirKey $d),
      (ConvertTo-DatadirKey $Datadir), [StringComparison]::OrdinalIgnoreCase) -and
    (-not $Chain -or (Get-NodeChain $CommandLine) -ceq $Chain))
}

function Test-MainnetNode {
  # True where a node's command line selects mainnet.
  param([string]$CommandLine)
  return ((Get-NodeChain $CommandLine) -ceq 'main')
}
