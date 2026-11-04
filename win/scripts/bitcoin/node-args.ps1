# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# Reads Bitcoin Core's network switches out of a Windows command line.
# lib.bat beside this file dot-sources it, and tests/win/node-args.ps1
# tests it.
#
# A switch counts only as a whole argument, so a path holding "-regtest" is
# not the switch. Bitcoin Core picks its network this way
# (src/common/args.cpp, src/common/settings.cpp and src/util/chaintype.cpp in
# bitcoin/bitcoin): on Windows "-name", "--name" and "/name" alike, the name in
# any case. A boolean switch is true bare, with an empty value, or with a value
# whose leading integer is not zero: "-regtest=2" is true, "-regtest=0" and
# "-regtest=abc" are false. "-noregtest" is false, and "-noregtest=0" is true.
# A switch given more than once takes its last value, and so does "-chain".
# "-chain=<name>" selects a network by name, testnet3's being "test", and Core
# refuses to start on an unknown name or on more than one network.
#
# Not read: bitcoin.conf, which can select a network too, and an argument Core
# refuses as unknown, which stops it before it runs.

function Split-CommandLine {
  # The arguments of a command line, the program first, as Bitcoin Core on
  # Windows receives them. From v31.0 Core reads the argv of Microsoft's C
  # runtime (Microsoft Learn, "Parsing C command-line arguments"); up to
  # v30.0 it read CommandLineToArgvW, which -CommandLineToArgvW follows, so a
  # guard can ask both. Both read a space or a tab outside double quotes as a
  # separator and drop the quotes, so -datadir="D:\a b" is one argument.
  # Both read 2n backslashes before a quote as n and a quote that opens or
  # closes a quoted run, 2n+1 as n and a literal quote, and a backslash
  # before anything else as itself. They differ on a run of quotes: the C
  # runtime reads "" inside a quoted run as a literal quote and stays inside
  # it; CommandLineToArgvW counts the run modulo 3, the quote that opened
  # the run included, so that "" inside one gives a literal quote and closes
  # it. They differ on the program's name too: the C runtime ends it at a
  # space outside quotes; CommandLineToArgvW ends a name that opens with a
  # quote at the next quote, and any other at a space, its quotes kept.
  # Wine's CommandLineToArgvW (dlls/shcore/main.c) and its tests against
  # Windows (dlls/shell32/tests/shlexec.c) state these rules. A line that
  # ends inside quotes ends its last argument.
  param([string]$CommandLine, [switch]$CommandLineToArgvW)
  $line = $CommandLine
  $i = 0
  $word = New-Object System.Text.StringBuilder
  if ($CommandLineToArgvW -and $line.StartsWith('"')) {
    $i = 1
    while ($i -lt $line.Length -and $line[$i] -ne '"') { [void]$word.Append($line[$i]); $i++ }
    $i++
  } elseif ($CommandLineToArgvW) {
    while ($i -lt $line.Length -and $line[$i] -notmatch '[ \t]') { [void]$word.Append($line[$i]); $i++ }
  } else {
    $quoted = $false
    while ($i -lt $line.Length -and ($quoted -or $line[$i] -notmatch '[ \t]')) {
      if ($line[$i] -eq '"') { $quoted = -not $quoted } else { [void]$word.Append($line[$i]) }
      $i++
    }
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
        } elseif ($CommandLineToArgvW) {
          $quoted++
        } elseif ($quoted -eq 1 -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '"') {
          [void]$word.Append([char]'"')
          $i++
        } else {
          $quoted = 1 - $quoted
        }
        $i++
        $escaped = $false
        if ($CommandLineToArgvW) {
          while ($i -lt $line.Length -and $line[$i] -eq '"') {
            $quoted++
            if ($quoted -eq 3) { [void]$word.Append([char]'"'); $quoted = 0 }
            $i++
          }
          if ($quoted -eq 2) { $quoted = 0 }
        }
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
  # zero or absent.
  param([string]$Value)
  if ($Value -eq '') { return $false }
  $v = $Value.Trim()
  if ($v -match '^[+-]') { $v = $v.Substring(1) }
  return $v -match '^0*($|[^0-9])'
}

function Get-NodeChain {
  # The network a node's command line selects, by the name "-chain" takes:
  # "main" where no network switch is true and "-chain" is absent. Null where
  # more than one network is selected. An unknown "-chain" name is returned
  # as given. -CommandLineToArgvW splits the line as Core up to v30.0 did.
  param([string]$CommandLine, [switch]$CommandLineToArgvW)
  $flags = @{ testnet = $false; testnet4 = $false; signet = $false; regtest = $false }
  $chain = $null
  foreach ($word in @(Split-CommandLine $CommandLine -CommandLineToArgvW:$CommandLineToArgvW | Select-Object -Skip 1)) {
    if ($word -notmatch '^[-/]') { continue }
    $word = $word.Substring(1)
    if ($word.StartsWith('-')) { $word = $word.Substring(1) }
    $eq = $word.IndexOf('=')
    if ($eq -lt 0) {
      $name = $word.ToLowerInvariant()
      $value = $null
    } else {
      $name = $word.Substring(0, $eq).ToLowerInvariant()
      $value = $word.Substring($eq + 1)
    }
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

function Test-MainnetNode {
  # True where a node's command line selects mainnet.
  param([string]$CommandLine)
  return ((Get-NodeChain $CommandLine) -ceq 'main')
}
