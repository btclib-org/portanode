# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# The launchers at the root, as Windows runs them: each opens its menu and
# leaves it on 0. No entry is chosen, so nothing here needs a binary under
# win\bin.
#
# Then the same launchers run from a copy of the folder at a path holding a
# "^", and every entry of the Bitcoin and Electrum menus is chosen in turn.
# With no binary under win\bin, each script an entry runs prints the root it
# resolved and stops (#793).

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

Remove-Item Env:PORTANODE_ROOT -ErrorAction SilentlyContinue
$exe = (Get-Process -Id $PID).Path

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName

# Feeds $Lines to the launcher on standard input, from the root $From, the
# repository's by default, and returns its output followed by a line "exit
# <status>". A launcher still running after 20 seconds is killed with its
# children and the line reads "exit timeout", so that a menu that never exits
# fails its case by name.
function Invoke-Launcher {
  param([string]$Launcher, [string[]]$Lines, [string]$From = $repo)
  [IO.File]::WriteAllText("$tmp\in.txt", (($Lines -join "`r`n") + "`r`n"))
  if ($Launcher.EndsWith('.bat')) {
    $file = 'cmd.exe'
    $arguments = "/d /c .\$Launcher"
  } else {
    $file = $exe
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File .\$Launcher"
  }
  $p = Start-Process -FilePath $file -ArgumentList $arguments `
    -WorkingDirectory $From -NoNewWindow -PassThru `
    -RedirectStandardInput "$tmp\in.txt" `
    -RedirectStandardOutput "$tmp\out.txt" `
    -RedirectStandardError "$tmp\err.txt"
  # Windows PowerShell 5.1 leaves ExitCode empty unless Handle is read first.
  $null = $p.Handle
  if ($p.WaitForExit(20000)) {
    $status = $p.ExitCode
  } else {
    & taskkill.exe /pid $p.Id /t /f 2>&1 | Out-Null
    $null = $p.WaitForExit(5000)
    $status = 'timeout'
  }
  $out = "$(Get-Content -Raw -LiteralPath "$tmp\out.txt")" +
    "$(Get-Content -Raw -LiteralPath "$tmp\err.txt")"
  ($out + "`r`nexit $status")
}

function Get-LastLine {
  param([string]$Text)
  ($Text.Trim() -split "`r?`n")[-1]
}

try {
  foreach ($name in 'Bitcoin', 'Electrum', 'Utilities') {
    $bat = "$name-Launcher.bat"
    $out = Invoke-Launcher $bat @('0')
    Test-Contain "$bat opens its menu on this checkout's root" `
      $out "$name Launcher `"$repo`""
    Test-Same "$bat exits 0 on 0" "exit 0" (Get-LastLine $out)

    # set /p keeps the old value on an empty line, so the menu clears it
    # first; without that, the empty line repeats "99" (ISS 686).
    $out = Invoke-Launcher $bat @('99', '')
    Test-Contain "$bat refuses an unknown entry" $out 'Invalid selection.'
    Test-Same "$bat exits 0 on an empty line after an unknown entry" `
      "exit 0" (Get-LastLine $out)

    $ps1 = "$name-Launcher.ps1"
    $out = Invoke-Launcher $ps1 @('0')
    Test-Contain "$ps1 opens its menu on this checkout's root" `
      $out "$name Launcher ($repo)"
    Test-Same "$ps1 exits 0 on 0" "exit 0" (Get-LastLine $out)
  }

  $out = Invoke-Launcher 'Bitcoin-Launcher.ps1' @('99', '0')
  Test-Contain 'Bitcoin-Launcher.ps1 refuses an unknown entry' `
    $out 'Invalid selection.'

  # The probe passes "a ^ b" as two arguments, one expanded before the call
  # and one in the call's own parse, as win\scripts\root.bat says at its head.
  $probe = Join-Path $tmp 'probe.bat'
  Set-Content -LiteralPath $probe -Encoding Ascii -Value @(
    '@echo off', 'setlocal disabledelayedexpansion', 'set "P=a ^ b"',
    'call :show "%P%" "%%P%%"', 'exit /b 0',
    ':show', 'set "FIRST=%~1"', 'set "SECOND=%~2"', 'set FIRST', 'set SECOND')
  Test-Same 'control: call doubles the "^" of a value expanded before it, not after' `
    "FIRST=a ^^ b`nSECOND=a ^ b" (@(& cmd.exe /d /c "`"$probe`"") -join "`n")

  $caret = Join-Path $tmp 'a ^ b'
  New-Item -ItemType Directory -Path (Join-Path $caret 'win') | Out-Null
  Copy-Item -LiteralPath (Join-Path $repo 'VERSION') -Destination $caret
  Copy-Item -LiteralPath (Join-Path $repo 'win\scripts') `
    -Destination (Join-Path $caret 'win\scripts') -Recurse
  foreach ($name in 'Bitcoin', 'Electrum', 'Utilities') {
    foreach ($launcher in "$name-Launcher.bat", "$name-Launcher.ps1") {
      Copy-Item -LiteralPath (Join-Path $repo $launcher) -Destination $caret
    }
  }
  # A root is matched by its last component, whatever form the path to the
  # temporary directory takes.
  $out = Invoke-Launcher 'Utilities-Launcher.bat' @('0') -From $caret
  Test-Same 'Utilities-Launcher.bat opens its menu under [a ^ b]' 'True' `
    "$($out -match 'Utilities Launcher "[^"\r\n]*\\a \^ b"')"
  $out = Invoke-Launcher 'Utilities-Launcher.ps1' @('0') -From $caret
  Test-Same 'Utilities-Launcher.ps1 opens its menu under [a ^ b]' 'True' `
    "$($out -match 'Utilities Launcher \([^\r\n]*\\a \^ b\)')"
  $resolved = 'ROOTDIR is "[^"\r\n]*\\a \^ b"'
  foreach ($name in 'Bitcoin', 'Electrum') {
    # The entries are the numbers the .bat menu maps to a script.
    $entries = @(Get-Content -LiteralPath (Join-Path $repo "$name-Launcher.bat") |
        Where-Object { $_ -match '^if "%CHOICE%"=="([1-9][0-9]*)" set "SCRIPT_REL=' } |
        ForEach-Object { $Matches[1] })
    Test-Same "the $name menu maps entries to scripts" 'True' "$($entries.Count -gt 0)"
    $lines = $entries + '0'
    foreach ($launcher in "$name-Launcher.bat", "$name-Launcher.ps1") {
      $out = Invoke-Launcher $launcher $lines -From $caret
      Test-Same "every entry of $launcher resolves the root under [a ^ b]" `
        "$($entries.Count)" "$([regex]::Matches($out, $resolved).Count)"
      Test-Same "$launcher exits 0 on 0 under [a ^ b]" 'exit 0' (Get-LastLine $out)
    }
  }
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
