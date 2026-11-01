# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# Resolve-PortaNodeRoot, in win/scripts/root.ps1, and :resolve_root, in
# win/scripts/root.bat.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }
Push-Location -LiteralPath (Join-Path $repo 'win\scripts')
try { . .\root.ps1 } finally { Pop-Location }

Remove-Item Env:PORTANODE_ROOT -ErrorAction SilentlyContinue
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName

function Add-TestRoot {
  param([string]$Path, [string[]]$Directories)
  foreach ($name in $Directories) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Path $name) | Out-Null
  }
  New-Item -ItemType File -Force -Path (Join-Path $Path 'VERSION') | Out-Null
}

# Runs root.bat's :resolve_root from a cmd.exe of its own, starting at
# $StartDir, and returns the root it sets. The start directory reaches
# cmd.exe through the environment, which spares quoting it on a command line.
function Invoke-BatResolveRoot {
  param([string]$StartDir)
  $bat = Join-Path $tmp 'resolve.bat'
  Set-Content -LiteralPath $bat -Encoding Ascii -Value @(
    '@echo off',
    'setlocal disabledelayedexpansion',
    "call `"$repo\win\scripts\root.bat`" :resolve_root `"%PORTANODE_TEST_START%`" ROOT",
    'echo(%ROOT%'
  )
  $env:PORTANODE_TEST_START = $StartDir
  try { (& cmd.exe /d /c $bat | Out-String).Trim() } finally {
    Remove-Item Env:PORTANODE_TEST_START
  }
}

try {
  Test-Same 'a directory inside this checkout resolves to its root' `
    $repo (Resolve-PortaNodeRoot -StartDir (Join-Path $repo 'win\scripts\bitcoin'))
  Test-Same 'root.bat: a directory inside this checkout resolves to its root' `
    $repo (Invoke-BatResolveRoot "$repo\win\scripts\bitcoin\")

  foreach ($platform in 'macos', 'win', 'linux') {
    $root = Join-Path $tmp "only-$platform"
    Add-TestRoot $root @("$platform\scripts")
    Test-Same "VERSION and $platform\ alone mark a root" `
      $root (Resolve-PortaNodeRoot -StartDir (Join-Path $root "$platform\scripts"))
    Test-Same "root.bat: VERSION and $platform\ alone mark a root" `
      $root (Invoke-BatResolveRoot "$root\$platform\scripts\")
  }

  $start = Join-Path $tmp 'win-file\linux-not\scripts'
  New-Item -ItemType Directory -Force -Path $start | Out-Null
  New-Item -ItemType File -Path (Join-Path $tmp 'win-file\win') | Out-Null
  New-Item -ItemType File -Path (Join-Path $tmp 'win-file\VERSION') | Out-Null
  Test-Same 'a file named win does not mark a root' `
    $start (Resolve-PortaNodeRoot -StartDir $start)
  Test-Same 'root.bat: a file named win does not mark a root' `
    $start (Invoke-BatResolveRoot $start)

  $elsewhere = Join-Path $tmp 'elsewhere'
  Add-TestRoot $elsewhere @('win')
  $env:PORTANODE_ROOT = $elsewhere
  Test-Same 'PORTANODE_ROOT naming a PortaNode folder overrides the walk' `
    $elsewhere (Resolve-PortaNodeRoot -StartDir $repo)
  Test-Same 'root.bat: PORTANODE_ROOT naming a PortaNode folder overrides the walk' `
    $elsewhere (Invoke-BatResolveRoot "$repo\")

  $env:PORTANODE_ROOT = (New-Item -ItemType Directory -Path (Join-Path $tmp 'not-a-root')).FullName
  Test-Same 'PORTANODE_ROOT naming no PortaNode folder resolves to nothing' `
    '' ([string](Resolve-PortaNodeRoot -StartDir $repo 2>$null))
  Remove-Item Env:PORTANODE_ROOT
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
