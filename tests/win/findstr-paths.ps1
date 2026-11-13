# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# The reads of a file by findstr in the Windows scripts, on a path holding a
# letter outside the ANSI code page. win/scripts/electrum/lib.bat says why each
# script gives findstr the file on standard input. The reads in the lib.bat
# files run the label as it stands; the search for prune= runs statements
# copied out of its script, as its section says. Each runs in a folder named in
# ASCII, in Latin-1 letters, and in letters outside both, which are the folder
# names the measurements in ISS 740 cover:
#
# - :require_non_portable_build, in win/scripts/electrum/lib.bat, on a file in
#   the folder;
# - :verify_pgp_signature, in win/scripts/utilities/lib.bat, on a signature in
#   the folder, beside which it makes gpg's home, and a keyring of a throwaway
#   key;
# - the search for prune= in validate-setup.bat, on a bitcoin.conf in the
#   folder;
# - the test for the data directories in validate-setup.bat, which findstr
#   does not read but which runs copied out the same way, with both, either or
#   neither of them in the folder.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

$utilities = Join-Path $repo 'win\scripts\utilities'
$electrumLib = Join-Path $repo 'win\scripts\electrum\lib.bat'
$utilitiesLib = Join-Path $utilities 'lib.bat'

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('path-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName

# Folder names from code points, so that this file stays ASCII under every
# PowerShell that reads it.
$names = [ordered]@{
  'ASCII'      = 'plain'
  'Latin-1'    = 'Pi' + [char]0xE8 + 'ce'
  'U+0142'     = ([string][char]0x142) + [char]0xF3 + 'd' + [char]0x17A
  'CJK'        = ([string][char]0x65E5) + [char]0x672C + [char]0x8A9E
}

# Runs $Bat under cmd.exe with $Env set, and returns its output and exit status.
# The values reach cmd.exe through the environment, which spares quoting a path
# that holds a letter on a command line.
function Invoke-Bat {
  param([string]$Bat, [hashtable]$Env)
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

# --- :require_non_portable_build ----------------------------------------------
$electrum = New-Driver 'electrum.bat' @(
  '@echo off',
  'call "%TEST_LIB%" :require_non_portable_build "%TEST_EXE%"',
  'exit /b %errorlevel%')
foreach ($label in $names.Keys) {
  $dir = Join-Path $tmp ('electrum-' + $names[$label])
  New-Item -ItemType Directory -Path $dir | Out-Null
  $standalone = Join-Path $dir 'electrum.exe'
  $portable = Join-Path $dir 'portable.exe'
  $other = Join-Path $dir 'other.exe'
  [IO.File]::WriteAllText($standalone, "MZ`0`0run_electrum`0`0")
  [IO.File]::WriteAllText($portable, "MZ`0`0run_electrum`0`0is_portable`0`0")
  [IO.File]::WriteAllText($other, "MZ`0`0nothing here`0`0")
  $run = {
    param($Exe)
    Invoke-Bat $electrum @{ TEST_LIB = $electrumLib; TEST_EXE = $Exe }
  }
  $r = & $run $standalone
  Test-Same "electrum lib accepts a standalone build in a $label folder" '0' ([string]$r.Status)
  $r = & $run $portable
  Test-Same "electrum lib refuses a portable build in a $label folder, as portable" '1' ([string]$r.Status)
  Test-Contain "electrum lib names the portable build in a $label folder" $r.Text "portable Windows build"
  $r = & $run $other
  Test-Same "electrum lib refuses a file that is no Electrum build in a $label folder" '1' ([string]$r.Status)
  Test-Contain "electrum lib says it could not read that file in a $label folder" $r.Text 'could not be read as an Electrum build'
  $r = & $run (Join-Path $dir 'absent.exe')
  Test-Contain "electrum lib says it could not read an absent file in a $label folder" $r.Text 'could not be read as an Electrum build'
}

# --- :verify_pgp_signature ----------------------------------------------------
# gpg runs for real, against a keyring holding a throwaway key made in a home of
# the tests' own: it writes the status lines :verify_pgp_signature reads. The
# cases are skipped where no gpg is installed. Every gpg command runs in a batch
# file that sends its output away, and the one that starts gpg's agent stops it
# again, so that no agent outlives the test.
$gpg = Get-Command gpg -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $gpg) {
  Write-Output '# no gpg on PATH: the :verify_pgp_signature cases are skipped'
} else {
  # Git for Windows' gpg is an MSYS program and reads a home written as /c/...
  $cygpath = Join-Path (Split-Path $gpg.Source) 'cygpath.exe'
  function Get-GpgHome {
    param([string]$Path)
    if (Test-Path -LiteralPath $cygpath) { (& $cygpath -u $Path) } else { $Path }
  }
  # A home's path stays short: gpg's agent listens on a socket inside it, and
  # the path of a socket is limited to 108 bytes. It also stays outside TEMP:
  # cygpath can write a home inside TEMP as /tmp/..., which names another folder
  # once the cases below change TEMP.
  $short = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) ('gh' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  $home1 = Get-GpgHome (New-Item -ItemType Directory -Path "$short-1").FullName
  $home2 = Get-GpgHome (New-Item -ItemType Directory -Path "$short-2").FullName
  $data = Join-Path $tmp 'data.txt'
  $tampered = Join-Path $tmp 'tampered.txt'
  $sig = Join-Path $tmp 'data.txt.sig'
  # The keyring of the key that signs, and of a key that signs nothing.
  $keyring = Join-Path $tmp 'signer.gpg'
  $otherKeyring = Join-Path $tmp 'other.gpg'
  [IO.File]::WriteAllText($data, "hello`n")
  [IO.File]::WriteAllText($tampered, "hullo`n")
  $setup = New-Driver 'gpg-setup.bat' @(
    '@echo off',
    'gpg --batch --pinentry-mode loopback --passphrase "" --quick-gen-key "portanode test <t@example.invalid>" ed25519 sign never > "%TEST_OUT%" 2>&1',
    'if defined TEST_SIG gpg --batch --yes --pinentry-mode loopback --passphrase "" --detach-sign --output "%TEST_SIG%" "%TEST_DATA%" >> "%TEST_OUT%" 2>&1',
    'gpg --batch --export > "%TEST_KEYRING%" 2>nul',
    'gpgconf --kill gpg-agent >nul 2>&1')
  $setupOut = Join-Path $tmp 'gpg-setup.out'
  $null = Invoke-Bat $setup @{
    GNUPGHOME = $home1; TEST_SIG = $sig; TEST_DATA = $data; TEST_KEYRING = $keyring; TEST_OUT = $setupOut
  }
  $made = (Test-Path -LiteralPath $sig) -and (Test-Path -LiteralPath $keyring) -and
    ((Get-Item -LiteralPath $keyring).Length -gt 0)
  Write-TestResult -Name 'gpg makes the test key, signs with it and exports it' `
    -Passed $made -Detail @(Get-Content -LiteralPath $setupOut -ErrorAction SilentlyContinue)
  $null = Invoke-Bat $setup @{
    GNUPGHOME = $home2; TEST_SIG = $null; TEST_KEYRING = $otherKeyring; TEST_OUT = $setupOut
  }
  $made = (Test-Path -LiteralPath $otherKeyring) -and ((Get-Item -LiteralPath $otherKeyring).Length -gt 0)
  Write-TestResult -Name 'gpg makes a second key and exports it' `
    -Passed $made -Detail @(Get-Content -LiteralPath $setupOut -ErrorAction SilentlyContinue)
  $verify = New-Driver 'verify.bat' @(
    '@echo off',
    'call "%TEST_LIB%" :verify_pgp_signature "%TEST_SIG%" "%TEST_DATA%" test "%TEST_KEYRING%" 1 > "%TEST_OUT%" 2>&1',
    'set "TEST_RC=%errorlevel%"',
    'type "%TEST_OUT%"',
    'exit /b %TEST_RC%')
  foreach ($label in $names.Keys) {
    # Each case runs in a folder of its own inside the label's folder, as the
    # updaters' fresh TMPDIR holds the data and its signature, and
    # :verify_pgp_signature makes gpg's home beside them. A second call in one
    # folder can draw the name of the first one's home, which lib.bat says.
    $dir = Join-Path $tmp ('sig-' + $names[$label])
    New-Item -ItemType Directory -Path $dir | Out-Null
    $script:case = 0
    # GNUPGHOME is the home that made the signing key, so a check that read
    # the user's keyring would find the key there.
    $run = {
      param($DataFile, $SigFile, $Keyring)
      $script:case++
      $script:caseDir = Join-Path $dir ('case-' + $script:case)
      New-Item -ItemType Directory -Path $script:caseDir | Out-Null
      foreach ($f in $data, $tampered, $sig) { Copy-Item -LiteralPath $f -Destination $script:caseDir }
      Invoke-Bat $verify @{
        TEST_LIB = $utilitiesLib; TEST_SIG = (Join-Path $script:caseDir $SigFile)
        TEST_DATA = (Join-Path $script:caseDir $DataFile); TEST_KEYRING = $Keyring
        TEST_OUT = (Join-Path $tmp 'verify.out'); GNUPGHOME = $home1
      }
    }
    $dataName = Split-Path -Leaf $data
    $sigName = Split-Path -Leaf $sig
    $r = & $run $dataName $sigName $keyring
    Test-Same "the signature check accepts a good signature in a $label folder" '0' ([string]$r.Status)
    Test-Contain "the signature check counts it in a $label folder" $r.Text 'good signatures from 1 key(s)'
    $homes = @(Get-ChildItem -LiteralPath $script:caseDir -Directory -Filter 'gpg-home-*')
    Test-Same "the signature check makes gpg's home beside a signature in a $label folder" 1 $homes.Count
    $r = & $run (Split-Path -Leaf $tampered) $sigName $keyring
    Test-Same "the signature check refuses a bad signature in a $label folder" '1' ([string]$r.Status)
    Test-Contain "the signature check calls it bad in a $label folder" $r.Text 'BAD PGP signature'
    $r = & $run $dataName 'absent.sig' $keyring
    Test-Contain "the signature check says gpg found none in a $label folder" $r.Text 'found no PGP signature'
    $r = & $run $dataName $sigName $otherKeyring
    Test-Same "the signature check refuses a key the keyring does not hold in a $label folder" '1' ([string]$r.Status)
    Test-Contain "the signature check says no key of the keyring signed in a $label folder" $r.Text 'verifies against a key in'
    $r = & $run $dataName $sigName (Join-Path $dir 'absent.gpg')
    Test-Contain "the signature check refuses a keyring that does not exist in a $label folder" $r.Text 'missing, empty or unreadable'
    $r = & $run $dataName $sigName $dir
    Test-Contain "the signature check refuses a folder for a keyring in a $label folder" $r.Text 'missing, empty or unreadable'
  }
  Remove-Item -LiteralPath "$short-1", "$short-2" -Recurse -Force -ErrorAction SilentlyContinue
}

# --- validate-setup.bat -------------------------------------------------------
# The statements from "set PRUNED=0" to the parenthesis that closes the block,
# run as they stand with ROOTDIR set.
$lines = Get-Content -LiteralPath (Join-Path $utilities 'validate-setup.bat')
$first = [array]::IndexOf($lines, 'set PRUNED=0')
$last = $first
while ($lines[$last] -ne ')') { $last++ }
$prune = New-Driver 'prune.bat' (@('@echo off') + $lines[$first..$last] + @('echo PRUNED=%PRUNED%'))
foreach ($label in $names.Keys) {
  $root = Join-Path $tmp ('prune-' + $names[$label])
  New-Item -ItemType Directory -Path "$root\bitcoin-datadir" -Force | Out-Null
  $conf = Join-Path $root 'bitcoin-datadir\bitcoin.conf'
  foreach ($case in @(@('prune=1000', '1'), @('prune=0', '0'), @("`tprune`t=`t5", '1'))) {
    [IO.File]::WriteAllText($conf, $case[0] + "`r`ndbcache=5`r`n")
    $r = Invoke-Bat $prune @{ ROOTDIR = $root }
    $shown = $case[0].Replace("`t", '<tab>')
    Test-Contain "validate-setup.bat reads '$shown' as PRUNED=$($case[1]) in a $label folder" $r.Text "PRUNED=$($case[1])"
  }
  Remove-Item -LiteralPath $conf
  $r = Invoke-Bat $prune @{ ROOTDIR = $root }
  Test-Contain "validate-setup.bat reads no bitcoin.conf as PRUNED=0 in a $label folder" $r.Text 'PRUNED=0'
}

# The statements from "set DATADIRS=0" to the parenthesis that closes the
# else, run as they stand with ROOTDIR set.
$first = [array]::IndexOf($lines, 'set DATADIRS=0')
$last = $first
while ($lines[$last] -ne ')') { $last++ }
$datadirs = New-Driver 'datadirs.bat' (@('@echo off') + $lines[$first..$last])
$ok = 'OK: Data directories exist'
$warn = 'WARNING: Data directories not found'
foreach ($label in $names.Keys) {
  foreach ($case in @(
      @('both', @('bitcoin-datadir', 'electrum-datadir'), $ok),
      @('only bitcoin-datadir', @('bitcoin-datadir'), $warn),
      @('only electrum-datadir', @('electrum-datadir'), $warn),
      @('neither', @(), $warn))) {
    $root = Join-Path $tmp ('datadirs-' + $case[0].Replace(' ', '-') + '-' + $names[$label])
    New-Item -ItemType Directory -Path $root | Out-Null
    foreach ($dir in $case[1]) { New-Item -ItemType Directory -Path (Join-Path $root $dir) | Out-Null }
    $r = Invoke-Bat $datadirs @{ ROOTDIR = $root }
    Test-Same "validate-setup.bat prints '$($case[2])' with $($case[0]) in a $label folder" $case[2] $r.Text.Trim()
  }
}

Remove-Item -LiteralPath $tmp -Recurse -Force
Complete-Test
