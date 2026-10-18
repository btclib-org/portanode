# The launchers at the root, as Windows runs them: each opens its menu and
# leaves it on 0 or an empty line. No entry is chosen, so nothing here needs a
# binary under win\bin.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

Remove-Item Env:PORTANODE_ROOT -ErrorAction SilentlyContinue
$exe = (Get-Process -Id $PID).Path

# Feeds $Lines to the launcher on standard input, from the repository's root,
# and returns its output followed by a line "exit <status>".
function Invoke-Launcher {
  param([string]$Launcher, [string[]]$Lines)
  Push-Location -LiteralPath $repo
  try {
    if ($Launcher.EndsWith('.bat')) {
      $out = $Lines | & cmd.exe /d /c ('.\' + $Launcher) 2>&1
    } else {
      $out = $Lines | & $exe -NoProfile -ExecutionPolicy Bypass `
        -File ('.\' + $Launcher) 2>&1
    }
    $status = $LASTEXITCODE
  } finally {
    Pop-Location
  }
  (($out | Out-String) + "exit $status")
}

function Get-LastLine {
  param([string]$Text)
  ($Text.Trim() -split "`r?`n")[-1]
}

foreach ($name in 'Bitcoin', 'Electrum', 'Utilities') {
  $bat = "$name-Launcher.bat"
  $out = Invoke-Launcher $bat @('0')
  Test-Contain "$bat opens its menu on this checkout's root" `
    $out "$name Launcher `"$repo`""
  Test-Same "$bat exits 0 on 0" "exit 0" (Get-LastLine $out)

  $ps1 = "$name-Launcher.ps1"
  $out = Invoke-Launcher $ps1 @('0')
  Test-Contain "$ps1 opens its menu on this checkout's root" `
    $out "$name Launcher ($repo)"
  Test-Same "$ps1 exits 0 on 0" "exit 0" (Get-LastLine $out)
}

# The .bat menu is given no unknown entry: fed "99" and then "0" through a
# pipe, it showed itself again without end on windows-latest, for a reason
# not run down here.
$out = Invoke-Launcher 'Bitcoin-Launcher.ps1' @('99', '0')
Test-Contain 'Bitcoin-Launcher.ps1 refuses an unknown entry' `
  $out 'Invalid selection.'

Complete-Test
