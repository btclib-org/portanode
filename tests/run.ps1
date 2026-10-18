# Runs every test file under tests/win/, each in a process of its own under
# the PowerShell running this one, and exits 1 where any of them failed. A
# file fails where it exits non-zero or prints a line starting "not ok ", so
# a file that never calls Complete-Test still fails on a failed case:
#
#   pwsh -NoProfile -File tests\run.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\run.ps1
#
# Windows only: the test files run cmd.exe and the .bat launchers.

if ($env:OS -ne 'Windows_NT') {
  Write-Output 'tests\run.ps1 runs on Windows only.'
  exit 1
}

$exe = (Get-Process -Id $PID).Path
Write-Output "# PowerShell $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"
$failed = @()
$dir = Join-Path $PSScriptRoot 'win'
foreach ($file in Get-ChildItem -LiteralPath $dir -Filter '*.ps1' | Sort-Object Name) {
  Write-Output "# win\$($file.Name)"
  # A script is run by a relative name from its own directory:
  # win/scripts/root.ps1 says why.
  Push-Location -LiteralPath $dir
  try {
    $out = & $exe -NoProfile -ExecutionPolicy Bypass -File ('.\' + $file.Name) 2>&1
    $status = $LASTEXITCODE
  } finally {
    Pop-Location
  }
  $out
  if ($status -ne 0 -or ($out -match '^not ok ')) {
    $failed += "win\$($file.Name)"
  }
}

if ($failed.Count -gt 0) {
  Write-Output "Failed: $($failed -join ' ')"
  exit 1
}
Write-Output 'Every test file passed.'
