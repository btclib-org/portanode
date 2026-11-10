# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# The launchers at the root, as Windows runs them: each opens its menu and
# leaves it on 0. No entry is chosen, so nothing here needs a binary under
# win\bin.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

Remove-Item Env:PORTANODE_ROOT -ErrorAction SilentlyContinue
$exe = (Get-Process -Id $PID).Path

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName

# Feeds $Lines to the launcher on standard input, from the repository's root,
# and returns its output followed by a line "exit <status>". A launcher still
# running after 20 seconds is killed with its children and the line reads
# "exit timeout", so that a menu that never exits fails its case by name.
function Invoke-Launcher {
  param([string]$Launcher, [string[]]$Lines)
  [IO.File]::WriteAllText("$tmp\in.txt", (($Lines -join "`r`n") + "`r`n"))
  if ($Launcher.EndsWith('.bat')) {
    $file = 'cmd.exe'
    $arguments = "/d /c .\$Launcher"
  } else {
    $file = $exe
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File .\$Launcher"
  }
  $p = Start-Process -FilePath $file -ArgumentList $arguments `
    -WorkingDirectory $repo -NoNewWindow -PassThru `
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
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
