# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# :preview_keyring, in win/scripts/utilities/lib.bat, which the updaters'
# --dry-run calls on a keyring under the folder, under folders whose paths hold
# a "^", an "&", a "!", a "%", parentheses and spaces. A keyring holding a byte
# is reported found; an empty one and one that is not there are reported
# refused. The folders holding a "^" are the case win\scripts\root.bat
# describes at its head.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName

# Runs the label from a cmd.exe of its own, as an updater calls it, and returns
# what it prints followed by a line "exit <status>". The keyring's path reaches
# cmd.exe through the environment, which spares quoting it on a command line.
function Get-Preview {
  param([string]$Keyring)
  $bat = Join-Path $tmp 'preview.bat'
  Set-Content -LiteralPath $bat -Encoding Ascii -Value @(
    '@echo off',
    'setlocal disabledelayedexpansion',
    'call "%%TEST_LIB%%" :preview_keyring "%%TEST_KEYRING%%" "keys\test.gpg" "the update" 3',
    'exit /b %errorlevel%')
  $env:TEST_LIB = Join-Path $repo 'win\scripts\utilities\lib.bat'
  $env:TEST_KEYRING = $Keyring
  try {
    $out = @(& cmd.exe /d /c "`"$bat`"" 2>&1)
    ($out + "exit $LASTEXITCODE") -join "`n"
  } finally {
    Remove-Item Env:TEST_LIB, Env:TEST_KEYRING -ErrorAction SilentlyContinue
  }
}

$found = "gpg: found. Verification asks for 3 good signature(s) from`n" +
  "distinct keys in keys\test.gpg.`nexit 0"
$refused = "gpg: found, but keys\test.gpg is missing, empty or unreadable --`n" +
  "verification would refuse the update.`nexit 0"

try {
  foreach ($r in 'plain', 'a ^ b', 'a & b', 'a !b! c', 'a (b) c', 'a %x% b', '100%',
    'x & (y) ^z !w') {
    $keys = Join-Path (Join-Path $tmp $r) 'keys'
    New-Item -ItemType Directory -Path $keys | Out-Null
    $keyring = Join-Path $keys 'test.gpg'
    [IO.File]::WriteAllText($keyring, 'k')
    Test-Same "a keyring holding a byte in the folder [$r] is found" `
      $found (Get-Preview $keyring)
    [IO.File]::WriteAllText($keyring, '')
    Test-Same "an empty keyring in the folder [$r] is refused" `
      $refused (Get-Preview $keyring)
    Test-Same "a keyring that is not there in the folder [$r] is refused" `
      $refused (Get-Preview (Join-Path $keys 'absent.gpg'))
  }
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
