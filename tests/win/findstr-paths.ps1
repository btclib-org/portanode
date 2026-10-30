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
# - :verify_pgp_signature, in win/scripts/utilities/lib.bat, with TEMP in the
#   folder, where it writes gpg's status file, and a throwaway key;
# - the search for prune= in validate-setup.bat, on a bitcoin.conf in the
#   folder.

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
# gpg runs for real, in a home of the tests' own with a throwaway key: it writes
# the status lines :verify_pgp_signature reads. The cases are skipped where no
# gpg is installed. Every gpg command runs in a batch file that sends its
# output away, and the one that starts gpg's agent stops it again, so that no
# agent outlives the test.
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
  # the path of a socket is limited to 108 bytes.
  $short = Join-Path ([IO.Path]::GetTempPath()) ('gh' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  $home1 = Get-GpgHome (New-Item -ItemType Directory -Path "$short-1").FullName
  $home2 = Get-GpgHome (New-Item -ItemType Directory -Path "$short-2").FullName
  $data = Join-Path $tmp 'data.txt'
  $tampered = Join-Path $tmp 'tampered.txt'
  $sig = Join-Path $tmp 'data.txt.sig'
  $keys = Join-Path $tmp 'keys.txt'
  [IO.File]::WriteAllText($data, "hello`n")
  [IO.File]::WriteAllText($tampered, "hullo`n")
  $setup = New-Driver 'gpg-setup.bat' @(
    '@echo off',
    'gpg --batch --pinentry-mode loopback --passphrase "" --quick-gen-key "portanode test <t@example.invalid>" ed25519 sign never > "%TEST_OUT%" 2>&1',
    'gpg --batch --yes --pinentry-mode loopback --passphrase "" --detach-sign --output "%TEST_SIG%" "%TEST_DATA%" >> "%TEST_OUT%" 2>&1',
    'gpg --batch --with-colons --list-keys > "%TEST_KEYS%" 2>nul',
    'gpgconf --kill gpg-agent >nul 2>&1')
  $setupOut = Join-Path $tmp 'gpg-setup.out'
  $null = Invoke-Bat $setup @{
    GNUPGHOME = $home1; TEST_SIG = $sig; TEST_DATA = $data; TEST_KEYS = $keys; TEST_OUT = $setupOut
  }
  $fpr = ''
  if (Test-Path -LiteralPath $keys) {
    $fpr = ((Get-Content -LiteralPath $keys | Where-Object { $_ -like 'fpr:*' } | Select-Object -First 1) -split ':')[9]
  }
  Write-TestResult -Name 'gpg makes the test key and signs with it' `
    -Passed ([bool]$fpr -and (Test-Path -LiteralPath $sig)) -Detail @(Get-Content -LiteralPath $setupOut -ErrorAction SilentlyContinue)
  $pins = Join-Path $tmp 'pins'
  [IO.File]::WriteAllText($pins, "$fpr`n")
  $verify = New-Driver 'verify.bat' @(
    '@echo off',
    'call "%TEST_LIB%" :verify_pgp_signature "%TEST_SIG%" "%TEST_DATA%" test "%TEST_FPR%" > "%TEST_OUT%" 2>&1',
    'set "TEST_RC=%errorlevel%"',
    'type "%TEST_OUT%"',
    'exit /b %TEST_RC%')
  foreach ($label in $names.Keys) {
    $temp = Join-Path $tmp ('temp-' + $names[$label])
    New-Item -ItemType Directory -Path $temp | Out-Null
    $run = {
      param($DataFile, $SigFile, $GpgHome)
      Invoke-Bat $verify @{
        TEST_LIB = $utilitiesLib; TEST_SIG = $SigFile; TEST_DATA = $DataFile; TEST_FPR = $pins
        TEST_OUT = (Join-Path $tmp 'verify.out'); GNUPGHOME = $GpgHome; TEMP = $temp; TMP = $temp
      }
    }
    $r = & $run $data $sig $home1
    Test-Same "the signature check accepts a good signature with TEMP in a $label folder" '0' ([string]$r.Status)
    Test-Contain "the signature check counts it with TEMP in a $label folder" $r.Text 'good signatures from 1 key(s)'
    $r = & $run $tampered $sig $home1
    Test-Same "the signature check refuses a bad signature with TEMP in a $label folder" '1' ([string]$r.Status)
    Test-Contain "the signature check calls it bad with TEMP in a $label folder" $r.Text 'BAD PGP signature'
    $r = & $run $data (Join-Path $tmp 'absent.sig') $home1
    Test-Contain "the signature check says gpg found none with TEMP in a $label folder" $r.Text 'found no PGP signature'
    $r = & $run $data $sig $home2
    Test-Contain "the signature check says the key is not imported with TEMP in a $label folder" $r.Text 'no valid PGP signature'
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

Remove-Item -LiteralPath $tmp -Recurse -Force
Complete-Test
