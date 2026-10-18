# Reads Bitcoin Core's network switches out of a Windows command line.
# lib.bat beside this file dot-sources it, and tests/win/node-args.ps1
# tests it.
#
# A switch counts only as a whole argument, so a path holding "-regtest" is
# not the switch. Bitcoin Core reads its arguments this way
# (src/common/args.cpp and src/util/chaintype.cpp in bitcoin/bitcoin): on
# Windows "-name", "--name" and "/name" alike, the name in any case. A
# boolean switch is true bare, with an empty value, or with a value whose
# leading integer is not zero: "-regtest=2" is true, "-regtest=0" and
# "-regtest=abc" are false. "-noregtest" is false, and "-noregtest=0" is
# true. "-chain=<name>" selects a network by name, testnet3's being "test".

function Split-CommandLine {
  # The arguments of a command line, the program first. White space outside
  # double quotes separates arguments, and the quotes are dropped, so
  # -datadir="D:\a b" is one argument. A backslash before a quote, which
  # Windows reads as a literal quote, is not read that way here.
  param([string]$CommandLine)
  foreach ($m in [regex]::Matches($CommandLine, '(?:"[^"]*"?|[^\s"])+')) {
    $m.Value.Replace('"', '')
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

function Test-SelectsNetwork {
  # True where the arguments, the program left out, select the network that
  # $Flag names as a switch and $Chain as a -chain value.
  param([string[]]$Arguments, [string]$Flag, [string]$Chain)
  foreach ($word in $Arguments) {
    if ($word -notmatch '^[-/]') { continue }
    $word = $word.Substring(1)
    if ($word.StartsWith('-')) { $word = $word.Substring(1) }
    $eq = $word.IndexOf('=')
    if ($eq -lt 0) {
      $name = $word
      $value = $null
    } else {
      $name = $word.Substring(0, $eq)
      $value = $word.Substring($eq + 1)
    }
    if ($name -eq $Flag) {
      if ($null -eq $value -or -not (Test-ValueReadsFalse $value)) { return $true }
    } elseif ($name -eq ('no' + $Flag)) {
      if ($null -ne $value -and (Test-ValueReadsFalse $value)) { return $true }
    } elseif ($name -eq 'chain' -and $value -eq $Chain) {
      return $true
    }
  }
  return $false
}

function Test-MainnetNode {
  # True where a node's command line selects no network but mainnet.
  param([string]$CommandLine)
  $arguments = @(Split-CommandLine $CommandLine | Select-Object -Skip 1)
  $networks = @(
    @('testnet', 'test'),
    @('testnet4', 'testnet4'),
    @('signet', 'signet'),
    @('regtest', 'regtest')
  )
  foreach ($n in $networks) {
    if (Test-SelectsNetwork -Arguments $arguments -Flag $n[0] -Chain $n[1]) {
      return $false
    }
  }
  return $true
}
