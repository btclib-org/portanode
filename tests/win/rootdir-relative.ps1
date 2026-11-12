# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# :rootdir_relative, in win/scripts/utilities/lib.bat, under folders whose
# paths hold a "^", an "&", a "!", a "%", parentheses and spaces (#892). A
# path in the folder comes back relative to it, whatever the case of its
# prefix; a path outside it, one that only begins with the folder's name,
# and every path where ROOTDIR is unset come back unchanged.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName

# Runs the label from a cmd.exe of its own and returns what set prints for
# OUT. The values reach cmd.exe through the environment, which spares quoting
# them on a command line; $Root $null leaves ROOTDIR unset.
function Get-Relative {
  param([string]$Root, [string]$Path)
  $bat = Join-Path $tmp 'relative.bat'
  Set-Content -LiteralPath $bat -Encoding Ascii -Value @(
    '@echo off',
    'setlocal disabledelayedexpansion',
    'call "%%TEST_LIB%%" :rootdir_relative "%%TEST_PATH%%" OUT',
    'set OUT')
  $env:TEST_LIB = Join-Path $repo 'win\scripts\utilities\lib.bat'
  $env:TEST_PATH = $Path
  if ($Root) { $env:ROOTDIR = $Root } else { Remove-Item Env:ROOTDIR -ErrorAction SilentlyContinue }
  try { (& cmd.exe /d /c "`"$bat`"" 2>&1 | Out-String).Trim() } finally {
    Remove-Item Env:TEST_LIB, Env:TEST_PATH, Env:ROOTDIR -ErrorAction SilentlyContinue
  }
}

try {
  foreach ($r in 'plain', 'a ^ b', 'a & b', 'a !b! c', 'a (b) c', 'a %x% b', '100%',
    'x & (y) ^z !w') {
    $root = Join-Path $tmp $r
    Test-Same "a path in the folder [$r] comes back relative" `
      'OUT=win\bin\bitcoin-cli.exe' (Get-Relative $root "$root\win\bin\bitcoin-cli.exe")
    Test-Same "a path in the folder [$r] with its prefix in upper case comes back relative" `
      'OUT=win\bin\bitcoin-cli.exe' (Get-Relative $root "$($root.ToUpperInvariant())\win\bin\bitcoin-cli.exe")
    Test-Same "a path that only begins with the name of the folder [$r] comes back unchanged" `
      "OUT=${root}x\win" (Get-Relative $root "${root}x\win")
    Test-Same "a path outside the folder [$r] comes back unchanged" `
      "OUT=$tmp\elsewhere\x" (Get-Relative $root "$tmp\elsewhere\x")
  }
  Test-Same 'a drive root as the folder leaves the path relative to it' `
    'OUT=win\bin' (Get-Relative 'C:\' 'C:\win\bin')
  Test-Same 'with ROOTDIR unset a path comes back unchanged' `
    "OUT=$tmp\a ^ b\win" (Get-Relative $null "$tmp\a ^ b\win")
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
