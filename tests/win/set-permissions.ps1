# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# win/scripts/utilities/set-permissions.bat, run whole in a copy of the tree,
# and its readback in :report_permission_effect. The folders are those a
# findstr search of icacls's report misses, as the comment above that label
# says: one named in CJK letters right after a backslash, and one whose name
# starts with "_" after a backslash. ASCII, Latin-1 and U+0142 folders run
# beside them. Where a local account can be made, the readback runs for an
# account named in CJK letters too, and the account is removed afterwards.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName

# Folder names from code points, so that this file stays ASCII under every
# PowerShell that reads it.
$names = [ordered]@{
  'ASCII'      = 'plain'
  'underscore' = '_temp'
  'Latin-1'    = 'Pi' + [char]0xE8 + 'ce'
  'U+0142'     = ([string][char]0x142) + [char]0xF3 + 'd' + [char]0x17A
  'CJK'        = ([string][char]0x65E5) + [char]0x672C + [char]0x8A9E
}

# The PowerShell the script starts is Windows PowerShell, which a pwsh
# parent's module path would stop from loading the module of Set-Acl.
$modulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')

# Runs $Bat under cmd.exe with $Env set, and returns its output and exit
# status. The values reach cmd.exe through the environment, which spares
# quoting a path that holds a letter on a command line.
function Invoke-Bat {
  param([string]$Bat, [hashtable]$Env)
  $Env = $Env.Clone()
  $Env['PSModulePath'] = $modulePath
  $old = @{}
  foreach ($key in $Env.Keys) {
    $old[$key] = [Environment]::GetEnvironmentVariable($key)
    [Environment]::SetEnvironmentVariable($key, $Env[$key])
  }
  try {
    $out = & cmd.exe /d /c $Bat 2>&1
    $status = $LASTEXITCODE
  } finally {
    foreach ($key in $old.Keys) {
      [Environment]::SetEnvironmentVariable($key, $old[$key])
    }
  }
  [pscustomobject]@{ Text = (($out | Out-String)); Status = $status }
}

function New-Driver {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseShouldProcessForStateChangingFunctions', '',
    Justification = 'a test helper that writes a file in the test folder')]
  param([string]$Name, [string[]]$Lines)
  $path = Join-Path $tmp $Name
  Set-Content -LiteralPath $path -Encoding Ascii -Value $Lines
  $path
}

# Makes a PortaNode folder at $Root holding a copy of win\scripts, and returns
# the path of its set-permissions.bat.
function New-PortaNodeCopy {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseShouldProcessForStateChangingFunctions', '',
    Justification = 'a test helper that writes in the test folder')]
  param([string]$Root)
  foreach ($dir in 'win', 'bitcoin-datadir', 'electrum-datadir') {
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $dir) | Out-Null
  }
  New-Item -ItemType File -Path (Join-Path $Root 'VERSION') | Out-Null
  Copy-Item -Recurse -LiteralPath (Join-Path $repo 'win\scripts') -Destination (Join-Path $Root 'win')
  Join-Path $Root 'win\scripts\utilities\set-permissions.bat'
}

# The number of data directories the script's output reports restricted.
function Get-RestrictedCount {
  param([string]$Text)
  ([regex]::Matches($Text, ': permissions restricted to')).Count
}

# The script is started by a "call" from a driver of its own, so that its
# console is not the one cmd.exe opened for it and :pause_if_own_console
# does not wait.
$whole = New-Driver 'whole.bat' @(
  '@echo off',
  'call "%TEST_SCRIPT%"',
  'exit /b %errorlevel%')

try {
  # --- the whole script -------------------------------------------------------
  foreach ($label in $names.Keys) {
    $root = Join-Path $tmp $names[$label]
    $script = New-PortaNodeCopy $root
    $r = Invoke-Bat $whole @{ TEST_SCRIPT = $script }
    Test-Same "set-permissions.bat exits 0 in a $label folder" '0' ([string]$r.Status)
    Test-Same "set-permissions.bat reports both data directories restricted in a $label folder" `
      '2' ([string](Get-RestrictedCount $r.Text))
    # An account that does not resolve: the write changes nothing, and the
    # readback says the ACE is missing rather than reporting a restriction.
    $r = Invoke-Bat $whole @{ TEST_SCRIPT = $script; USERNAME = 'portanode-no-such-account' }
    Test-Same "set-permissions.bat exits 1 for an account that does not resolve in a $label folder" `
      '1' ([string]$r.Status)
    Test-Contain "set-permissions.bat says the ACE is missing for that account in a $label folder" `
      $r.Text 'carry an ACE granting'
  }

  # --- the readback on its own -----------------------------------------------
  # The statements below the volumes answered from their name, to the end of
  # the file, run as they stand with the values :report_permission_effect is
  # given.
  $lines = Get-Content -LiteralPath (Join-Path $repo 'win\scripts\utilities\set-permissions.bat')
  $first = [array]::IndexOf($lines, '    exit /b 2') + 2
  $readback = New-Driver 'readback.bat' (@(
    '@echo off',
    'set "TARGET=%TEST_TARGET%"',
    'set "REL=bitcoin-datadir"',
    'set "FS_NAME=NTFS"',
    'set "INHERIT_RC=0"') + $lines[$first..($lines.Count - 1)])
  $target = Join-Path $tmp ($names['CJK'] + '\bitcoin-datadir')
  $r = Invoke-Bat $readback @{ TEST_TARGET = $target }
  Test-Same 'the readback exits 0 for the restricted folder' '0' ([string]$r.Status)
  $null = & icacls.exe $target /grant '*S-1-1-0:(OI)(CI)R'
  $r = Invoke-Bat $readback @{ TEST_TARGET = $target }
  Test-Same "the readback exits 1 for another identity's ACE" '1' ([string]$r.Status)
  Test-Contain 'the readback names the other identity' $r.Text 'another identity'
  $null = & icacls.exe $target /remove '*S-1-1-0'
  # A folder that inherits its ACEs, the account's among them: none of them
  # is the explicit ACE the write leaves.
  $inheriting = (New-Item -ItemType Directory -Path (Join-Path $tmp 'inheriting')).FullName
  $r = Invoke-Bat $readback @{ TEST_TARGET = $inheriting }
  Test-Same 'the readback exits 1 for a folder that inherits its ACEs' '1' ([string]$r.Status)
  Test-Contain 'the readback says that folder carries no ACE granting the account' `
    $r.Text 'carry an ACE granting'
  $r = Invoke-Bat $readback @{ TEST_TARGET = (Join-Path $tmp 'absent') }
  Test-Same 'the readback exits 1 for a folder that does not exist' '1' ([string]$r.Status)
  Test-Contain 'the readback says the ACL could not be read back' $r.Text 'could not be read'

  # --- an account named in CJK letters ----------------------------------------
  # The readback runs on its own here, because the whole script, run by
  # another account, cannot reach the contents of a folder it has just
  # restricted to this one. The folder is restricted as set-permissions.bat
  # restricts it, by set-datadir-acl.ps1, and USERNAME names the account. Its
  # owner, the account running this, resets it before it is removed.
  $account = ([string][char]0x7528) + [char]0x6237
  $made = $false
  try {
    $password = New-Object Security.SecureString
    foreach ($c in ('Portanode-' + [guid]::NewGuid()).ToCharArray()) { $password.AppendChar($c) }
    New-LocalUser -Name $account -Password $password -ErrorAction Stop | Out-Null
    $made = $true
  } catch {
    Write-Output "# no local account could be made, so the CJK account cases are skipped: $($_.Exception.Message)"
  }
  if ($made) {
    $target = $null
    try {
      $target = (New-Item -ItemType Directory -Path (Join-Path $tmp ('account-' + $names['CJK']))).FullName
      $restrict = New-Driver 'restrict.bat' @(
        '@echo off',
        'powershell -NoProfile -ExecutionPolicy Bypass -File "%TEST_SCRIPT%" -Path "%TEST_TARGET%" -Account "%USERDOMAIN%\%USERNAME%"',
        'exit /b %errorlevel%')
      $acl = @{
        TEST_SCRIPT = (Join-Path $repo 'win\scripts\utilities\set-datadir-acl.ps1')
        TEST_TARGET = $target; USERNAME = $account
      }
      $r = Invoke-Bat $restrict $acl
      Test-Same 'set-datadir-acl.ps1 restricts the folder to an account named in CJK letters' '0' ([string]$r.Status)
      $r = Invoke-Bat $readback @{ TEST_TARGET = $target; USERNAME = $account }
      Test-Same 'the readback exits 0 for an account named in CJK letters' '0' ([string]$r.Status)
      Test-Contain 'the readback reports the restriction for an account named in CJK letters' `
        $r.Text 'permissions restricted to'
      $null = & icacls.exe $target /grant '*S-1-1-0:(OI)(CI)R'
      $r = Invoke-Bat $readback @{ TEST_TARGET = $target; USERNAME = $account }
      Test-Same "the readback exits 1 for another identity's ACE beside an account named in CJK letters" `
        '1' ([string]$r.Status)
    } finally {
      if ($target) { $null = & icacls.exe $target /reset /t /q }
      Remove-LocalUser -Name $account
    }
  }
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
