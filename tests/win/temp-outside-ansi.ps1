# win/scripts/utilities/filesystem-type.ps1 and free-space-gb.ps1 under a
# TEMP holding a letter outside the ANSI code page, and under one on a drive
# letter no volume carries. Each runs under powershell.exe, the Windows
# PowerShell 5.1 the .bat callers start, and under the PowerShell running
# this file, started as the callers start it. Windows only: both scripts
# call kernel32.

Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . ./lib.ps1 } finally { Pop-Location }

if ($env:OS -ne 'Windows_NT') {
  Write-Output 'ok - SKIP: the TEMP cases (they run on Windows only)'
  exit 0
}

$utilities = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\win\scripts\utilities')).Path
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-temp-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName
# U+0142 U+00F3 d U+017A: the first and last are outside code page 1252, the
# ANSI code page of an English Windows
$outside = Join-Path $tmp ([string][char]0x0142 + [char]0x00F3 + 'd' + [char]0x017A)
New-Item -ItemType Directory -Path $outside | Out-Null
$used = [IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name[0] }
# the first letter from Z down to D that names no drive
$letter = [char[]](90..68) | Where-Object { $used -notcontains $_ } | Select-Object -First 1
$unmapped = "$($letter):\temp"

# Runs $Script on $tmp under $Exe with TEMP and TMP set to $Temp, and returns
# its exit code and output on one line.
function Invoke-Utility {
  param([string]$Exe, [string]$Script, [string]$Temp)
  $saved = $env:TEMP, $env:TMP
  $env:TEMP = $Temp
  $env:TMP = $Temp
  $env:PORTANODE_TEST_DIR = $utilities
  $env:PORTANODE_TEST_PATH = $tmp
  try {
    $command = 'Set-Location -LiteralPath $env:PORTANODE_TEST_DIR -ErrorAction Stop; ' +
      "& .\$Script -Path `$env:PORTANODE_TEST_PATH; exit `$LASTEXITCODE"
    $out = & $Exe -NoProfile -ExecutionPolicy Bypass -Command $command
    "exit $LASTEXITCODE`: $(($out | Out-String).Trim())"
  } finally {
    $env:TEMP, $env:TMP = $saved
    Remove-Item Env:PORTANODE_TEST_DIR, Env:PORTANODE_TEST_PATH
  }
}

# Passes where $Actual matches $Pattern.
function Test-Match {
  param([string]$Name, [string]$Pattern, [string]$Actual)
  Write-TestResult -Name $Name -Passed ($Actual -match $Pattern) -Detail @(
    "pattern:  $Pattern", "actual:   $Actual")
}

$exes = @((Get-Command powershell.exe).Source)
$self = (Get-Process -Id $PID).Path
if ($exes -notcontains $self) { $exes += $self }

try {
  foreach ($exe in $exes) {
    $shell = Split-Path -Leaf $exe
    $fs = Invoke-Utility -Exe $exe -Script 'filesystem-type.ps1' -Temp $env:TEMP
    Test-Match -Name "$($shell): filesystem-type.ps1 names a filesystem under the usual TEMP" `
      -Pattern '^exit 0: \w+$' -Actual $fs
    Test-Match -Name "$($shell): free-space-gb.ps1 answers under the usual TEMP" `
      -Pattern '^exit 0: \d+$' `
      -Actual (Invoke-Utility -Exe $exe -Script 'free-space-gb.ps1' -Temp $env:TEMP)
    foreach ($case in @(@('a TEMP outside the ANSI code page', $outside),
        @("a TEMP on the unmapped $($letter):", $unmapped))) {
      Test-Same "$($shell): filesystem-type.ps1 answers as usual under $($case[0])" `
        $fs (Invoke-Utility -Exe $exe -Script 'filesystem-type.ps1' -Temp $case[1])
      Test-Match -Name "$($shell): free-space-gb.ps1 answers under $($case[0])" `
        -Pattern '^exit 0: \d+$' `
        -Actual (Invoke-Utility -Exe $exe -Script 'free-space-gb.ps1' -Temp $case[1])
    }
  }
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
