# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# The lines win/scripts/utilities/monitor-bitcoin-log.ps1 prints, with the
# cases of tests/sh/monitor-bitcoin-log.sh. It starts no process.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

$monitor = Join-Path $repo 'win\scripts\utilities\monitor-bitcoin-log.ps1'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName
$utf8 = New-Object System.Text.UTF8Encoding $false

# Returns what the monitor reports for a debug.log holding $Line, one string,
# its lines joined by "`n".
function Get-Report {
  param([string]$Line)
  $root = Join-Path $tmp ([guid]::NewGuid())
  $datadir = Join-Path $root 'bitcoin-datadir'
  New-Item -ItemType Directory -Path $datadir | Out-Null
  [IO.File]::WriteAllBytes((Join-Path $datadir 'debug.log'),
    $utf8.GetBytes($Line + "`r`n"))
  $out = & $monitor -RootDir $root -NoNotify 6>&1 | ForEach-Object { [string]$_ }
  $out -join "`n"
}

# Builds a string from text and character codes.
function Join-Char {
  param([object[]]$Part)
  -join ($Part | ForEach-Object { if ($_ -is [int]) { [string][char]$_ } else { $_ } })
}

$title = 'Bitcoin log errors detected:'
try {
  Test-Same 'C0 prints as \xHH' `
    "$title`nERROR c0 \x00\x01\x09\x0d\x1b[31m\x1f end" `
    (Get-Report (Join-Char 'ERROR c0 ', 0, 1, 9, 13, 27, '[31m', 31, ' end'))
  Test-Same 'DEL prints as \x7f' "$title`nERROR del \x7f end" `
    (Get-Report (Join-Char 'ERROR del ', 127, ' end'))
  Test-Same 'C1 prints as \u00HH' `
    "$title`nERROR c1 \u0080\u009b\u009f end" `
    (Get-Report (Join-Char 'ERROR c1 ', 0x80, 0x9b, 0x9f, ' end'))
  $plain = Join-Char 'ERROR plain ~ ', 0xa0, ' ', 0xe9, ' ', 0x20ac, ' end'
  Test-Same 'the characters around the ranges print unchanged' `
    "$title`n$plain" (Get-Report $plain)
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
