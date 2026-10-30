# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# The running-node guard of the Windows updaters and rollbacks: where tasklist
# is missing or fails, each refuses. tests/sh/running-guard.sh has the shell
# half.
#
# The scripts run with System32 as their current directory, where cmd.exe finds
# the real commands before PATH (root.bat's :leave_folder).
# NoDefaultCurrentDirectoryInExePath stops that search, so these cases can name
# what PATH holds: a directory of copied commands, with one left out or replaced.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

# :pause_if_own_console in win\scripts\root.bat waits 30 seconds in a
# console opened for the script, and returns at once where this is set.
$env:PORTANODE_LAUNCHER = '1'
$system32 = Join-Path $env:SystemRoot 'System32'
$powershellDir = Join-Path $system32 'WindowsPowerShell\v1.0'
$realPath = $env:Path
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName
$env:PORTANODE_ROOT = Join-Path $tmp 'root'
New-Item -ItemType Directory -Path (Join-Path $env:PORTANODE_ROOT 'win') | Out-Null
New-Item -ItemType File -Path (Join-Path $env:PORTANODE_ROOT 'VERSION') | Out-Null

# Copies System32's <Name>.exe to <Dir>\<As>.exe, with the messages it loads.
function Copy-SystemCommand {
  param([string]$Name, [string]$Dir, [string]$As = $Name)
  New-Item -ItemType Directory -Path $Dir -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $system32 "$Name.exe") -Destination (Join-Path $Dir "$As.exe")
  foreach ($mui in Get-ChildItem -Path $system32 -Filter "$Name.exe.mui" -Recurse -Depth 1 -ErrorAction SilentlyContinue) {
    $to = Join-Path $Dir $mui.Directory.Name
    New-Item -ItemType Directory -Path $to -Force | Out-Null
    Copy-Item -LiteralPath $mui.FullName -Destination (Join-Path $to "$As.exe.mui")
  }
}

# A directory holding the commands the scripts run before the guard, and $Also.
function Add-CommandDir {
  param([string]$Name, [string[]]$Also = @())
  $dir = Join-Path $tmp $Name
  foreach ($command in @('findstr', 'where') + $Also) { Copy-SystemCommand $command $dir }
  $dir
}
$noTasklist = Add-CommandDir 'no-tasklist'
$noFind = Add-CommandDir 'no-find' 'tasklist'
# findstr exits non-zero on tasklist's arguments, as a listing that fails does.
$failingTasklist = Add-CommandDir 'failing-tasklist'
Copy-SystemCommand 'findstr' $failingTasklist 'tasklist'

# A tasklist that answers its first call with a listing holding no process, and
# fails every later one. It counts its calls in a file beside it.
$oneListing = Add-CommandDir 'one-listing' 'find'
$oneListingCalls = Join-Path $oneListing 'calls'
$stubSource = @'
class P {
  static int Main() {
    string f = System.IO.Path.Combine(System.AppDomain.CurrentDomain.BaseDirectory, "calls");
    int n = System.IO.File.Exists(f) ? System.IO.File.ReadAllText(f).Length : 0;
    System.IO.File.AppendAllText(f, "x");
    System.Console.WriteLine("INFO: none");
    return n == 0 ? 0 : 1;
  }
}
'@
$env:PORTANODE_TEST_STUB = $stubSource
& (Join-Path $powershellDir 'powershell.exe') -NoProfile -Command `
  "Add-Type -TypeDefinition `$env:PORTANODE_TEST_STUB -OutputType ConsoleApplication -OutputAssembly '$(Join-Path $oneListing 'tasklist.exe')'"
Remove-Item Env:PORTANODE_TEST_STUB

# Runs $CommandLine under cmd.exe from System32 with PATH holding $Dir alone,
# and returns its status.
function Get-CommandStatus {
  param([string]$Dir, [string]$CommandLine)
  $env:NoDefaultCurrentDirectoryInExePath = '1'
  $env:Path = "$Dir;$powershellDir"
  Push-Location -LiteralPath $system32
  try {
    & $env:ComSpec /d /c "$CommandLine >nul 2>&1" | Out-Null
    $LASTEXITCODE
  } finally {
    Pop-Location
    $env:Path = $realPath
    Remove-Item Env:NoDefaultCurrentDirectoryInExePath
  }
}

# Runs a script of win\scripts\utilities and returns its output and status. With
# $Dir, PATH holds $Dir and not System32.
function Invoke-Script {
  param([string]$Script, [string[]]$Arguments, [string]$Dir = '')
  if ($Dir) {
    $env:NoDefaultCurrentDirectoryInExePath = '1'
    $env:Path = "$Dir;$powershellDir"
  }
  try {
    $bat = Join-Path $repo "win\scripts\utilities\$Script"
    $out = @('') | & $env:ComSpec /d /c $bat @Arguments 2>&1
    (($out | Out-String) + "status=$LASTEXITCODE")
  } finally {
    $env:Path = $realPath
    Remove-Item Env:NoDefaultCurrentDirectoryInExePath -ErrorAction SilentlyContinue
  }
}

$scripts = @(
  [pscustomobject]@{ File = 'update-bitcoin.bat'; Past = '--dry-run:'; Name = 'Bitcoin Core'; Doing = 'updating'
    Arguments = @('--dry-run', '--version', '99.0'); Images = @('bitcoind', 'bitcoin-qt') },
  [pscustomobject]@{ File = 'update-electrum.bat'; Past = '--dry-run:'; Name = 'Electrum'; Doing = 'updating'
    Arguments = @('--dry-run', '--version', '99.0.0'); Images = @('electrum') },
  [pscustomobject]@{ File = 'rollback-bitcoin.bat'; Past = 'No backup found'; Name = 'Bitcoin Core'; Doing = 'rolling back'
    Arguments = @('--dry-run'); Images = @('bitcoind', 'bitcoin-qt') },
  [pscustomobject]@{ File = 'rollback-electrum.bat'; Past = 'No backup found'; Name = 'Electrum'; Doing = 'rolling back'
    Arguments = @('--dry-run'); Images = @('electrum') })

try {
  $listing = 'tasklist /fi "imagename eq x.exe"'
  # Each command exits 0 where the real one runs.
  Test-Same 'the first PATH holds no tasklist, System32 being current' 'True' `
    "$((Get-CommandStatus $noTasklist $listing) -ne 0)"
  Test-Same 'the second PATH holds a tasklist that answers' '0' `
    "$(Get-CommandStatus $noFind $listing)"
  Test-Same 'the second PATH holds no find' 'True' `
    "$((Get-CommandStatus $noFind 'find /?') -ne 0)"
  Test-Same 'the third PATH holds a tasklist that fails' 'True' `
    "$((Get-CommandStatus $failingTasklist $listing) -ne 0)"

  # One listing answers the guard: no later call can fail unread.
  $text = Invoke-Script 'rollback-electrum.bat' @('--dry-run') $oneListing
  Test-Same 'the guard runs tasklist once for an image' '1' `
    "$((Get-Item -LiteralPath $oneListingCalls -ErrorAction SilentlyContinue).Length)"
  Test-Contain 'the listing it read lets rollback-electrum.bat go on' $text 'No backup found'
  Remove-Item -LiteralPath $oneListingCalls -ErrorAction SilentlyContinue
  $text = Invoke-Script 'rollback-bitcoin.bat' @('--dry-run') $oneListing
  Test-Contain 'rollback-bitcoin.bat refuses where the second image''s listing fails' $text `
    'Error: cannot tell whether Bitcoin Core is running'

  foreach ($s in $scripts) {
    foreach ($case in @(
        @('without tasklist', $noTasklist),
        @('where tasklist fails', $failingTasklist))) {
      $text = Invoke-Script $s.File $s.Arguments $case[1]
      Test-Contain "$($s.File) cannot tell $($case[0])" $text `
        "Error: cannot tell whether $($s.Name) is running"
      Test-Contain "$($s.File) refuses $($case[0])" $text "Not $($s.Doing)."
      Test-Contain "$($s.File) exits 1 $($case[0])" $text 'status=1'
    }

    # $s.Past is printed only after the guard.
    foreach ($case in @(@('where no process is found', ''), @('without find', $noFind))) {
      $text = Invoke-Script $s.File $s.Arguments $case[1]
      Test-Contain "$($s.File) goes on $($case[0])" $text $s.Past
      Test-Same "$($s.File) says nothing of a process $($case[0])" 'False' `
        "$($text -match 'cannot tell|is running')"
    }

    # A copy of ping under the name of each image is a process tasklist lists.
    foreach ($image in $s.Images) {
      $dir = Join-Path $tmp "running-$image"
      if (-not (Test-Path -LiteralPath $dir)) { Copy-SystemCommand 'ping' $dir $image }
      $process = Start-Process -FilePath (Join-Path $dir "$image.exe") -PassThru `
        -WindowStyle Hidden -ArgumentList '-n', '120', '127.0.0.1'
      try {
        $text = Invoke-Script $s.File $s.Arguments
      } finally {
        Stop-Process -Id $process.Id -Force
        $process.WaitForExit()
      }
      Test-Contain "$($s.File) stops where $image.exe runs" $text `
        "Error: $($s.Name) is running. Stop it before $($s.Doing)."
      Test-Contain "$($s.File) exits 1 where $image.exe runs" $text 'status=1'
    }
  }
} finally {
  $env:Path = $realPath
  Remove-Item Env:PORTANODE_ROOT -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
