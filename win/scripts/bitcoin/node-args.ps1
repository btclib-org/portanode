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

function Test-MainnetNode {
  # True where a node's command line selects mainnet: no network switch is
  # true and -chain is absent, or -chain=main alone.
  param([string]$CommandLine)
  $flags = @{ testnet = $false; testnet4 = $false; signet = $false; regtest = $false }
  $chain = $null
  foreach ($word in @(Split-CommandLine $CommandLine | Select-Object -Skip 1)) {
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
  $selected = @($flags.Values | Where-Object { $_ }).Count
  if ($null -ne $chain) { $selected += 1 }
  if ($selected -gt 1) { return $false }
  if ($null -ne $chain) { return ($chain -ceq 'main') }
  return ($selected -eq 0)
}
