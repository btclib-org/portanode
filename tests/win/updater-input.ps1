# What the Windows updaters download and what they are told, fed to them
# malformed: a version string, the release index, SHA256SUMS and gpg's status
# output. Each is refused. tests/sh/updater-input.sh has the shell half and
# says why these cases stand in for a fuzzer.
#
# The parsers that live inside update-bitcoin.bat and lib.bat are PowerShell
# in a batch string, so the test reads that text from the file and runs it:
# what is tested is the text the updater runs. cmd.exe does not run here, so
# the batch around it is not tested; the cases run on any system with pwsh.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

$utilities = Join-Path $repo 'win\scripts\utilities'
$exe = (Get-Process -Id $PID).Path
$windows = $env:OS -eq 'Windows_NT'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-input-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName

# --- a version string -------------------------------------------------------
# compare-versions.ps1 runs in this process: its exit ends the script and
# not this one.
$compare = Join-Path $utilities 'compare-versions.ps1'
$badVersions = @(
  '27.0/../28.0', '..\..\x', '27.0;calc', '27.0 && id', ' 27.0', '27.0 ',
  "27.0`n", "27.0`n28.0", "27.0`r", '27.0rc1', 'v27.0', '27..0', '.27', '27.',
  '27.0%2f..', '$(id)', '-1', '27.0?x=1', '27.0#f', '27.0:80', 'unknown',
  ([string][char]0x0662 + [char]0x0667 + '.0'), ([string][char]0xFF12 + [char]0xFF17 + '.0'),
  '2 7.0', 'x')
foreach ($installed in 'unknown', '28.1') {
  foreach ($allow in '', '1') {
    foreach ($v in $badVersions) {
      $shown = ($v -replace "`r", '\r') -replace "`n", '\n'
      $verdict = & $compare -Installed $installed -Requested $v -Allow $allow
      Test-Same "compare-versions.ps1 refuses '$shown' (installed $installed, allow '$allow')" `
        'MALFORMED' ([string]$verdict)
    }
  }
}
Test-Same 'compare-versions.ps1 lets 29.0 over unknown pass' 'OK' `
  ([string](& $compare -Installed 'unknown' -Requested '29.0'))
Test-Same 'compare-versions.ps1 lets 29.0 over 28.1 pass' 'OK' `
  ([string](& $compare -Installed '28.1' -Requested '29.0'))
Test-Same 'compare-versions.ps1 refuses 27.0 over 28.1' 'OLDER' `
  ([string](& $compare -Installed '28.1' -Requested '27.0'))
Test-Same 'compare-versions.ps1 lets 27.0 over 28.1 pass with -Allow 1' 'OK' `
  ([string](& $compare -Installed '28.1' -Requested '27.0' -Allow '1'))

# --- the release index -------------------------------------------------------
# The scripts fetch with Invoke-WebRequest, which a function of the same name
# here stands in for: a function is found before the cmdlet, from inside the
# script as well. The index is in the environment, which the script sees where
# it would not see a variable of this file, and a HEAD probe succeeds.
$env:PORTANODE_TEST_INDEX = ''
function Invoke-WebRequest {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '')]
  param()
  if ($args -contains 'Head') { return $null }
  [pscustomobject]@{ Content = $env:PORTANODE_TEST_INDEX }
}
# The output of a script run against $Index, or 'threw' where it raised.
function Get-Latest {
  param([string]$Script, [string]$Index)
  $env:PORTANODE_TEST_INDEX = $Index
  try {
    $out = & (Join-Path $utilities $Script)
    (@($out) -join '|')
  } catch {
    'threw'
  }
}
$bitcoinBad = @(
  '<a href="bitcoin-core-99.0/../">x</a>', '<a href="bitcoin-core-98.0;x/">x</a>',
  '<a href="bitcoin-core-97.0.0.0/">x</a>', '<a href="../bitcoin-core-96.0/">x</a>',
  '<a href="bitcoin-core-0.21.0/">x</a>', '<a href="bitcoin-core-95.0\">x</a>',
  '<a href="bitcoin-core-94.0 /">x</a>',
  ('<a href="bitcoin-core-' + [char]0x0669 + [char]0x0668 + '.0/">x</a>'),
  ('<a href="bitcoin-core-' + [char]0xFF19 + [char]0xFF17 + '.0/">x</a>')) -join "`n"
$electrumBad = @(
  '<a href="9.9.9/../">x</a>', '<a href="8.8.8.8/">x</a>', '<a href="7.7/">x</a>',
  '<a href="v6.6.6/">x</a>', '<a href="5.5.5;x/">x</a>', '<a href="4.4.4\">x</a>',
  ('<a href="' + [char]0x0669 + '.9.9/">x</a>'), ('<a href="' + [char]0xFF19 + '.9.9/">x</a>')) -join "`n"
# Only the well-formed version reaches the caller. A number that does not fit
# [version] is no version: the script ends in an error and prints nothing.
$bitcoinOut = Get-Latest 'latest-bitcoin-version.ps1' ($bitcoinBad + "`n" + '<a href="bitcoin-core-29.0/">x</a>')
Test-Same 'latest-bitcoin-version.ps1 takes the one well-formed version of its index' '29.0' $bitcoinOut
$bitcoinOut = Get-Latest 'latest-bitcoin-version.ps1' $bitcoinBad
Test-Same 'latest-bitcoin-version.ps1 prints no version for an index of malformed ones' '' $bitcoinOut
$bitcoinOut = Get-Latest 'latest-bitcoin-version.ps1' '<a href="bitcoin-core-99999999999999999999.0/">x</a>'
Test-Same 'latest-bitcoin-version.ps1 prints no version for one too large for [version]' `
  $true ($bitcoinOut -eq '' -or $bitcoinOut -eq 'threw')
$electrumOut = Get-Latest 'latest-electrum-version.ps1' ($electrumBad + "`n" + '<a href="4.6.0/">x</a>')
Test-Same 'latest-electrum-version.ps1 takes the one well-formed version of its index' '4.6.0' $electrumOut
$electrumOut = Get-Latest 'latest-electrum-version.ps1' $electrumBad
Test-Same 'latest-electrum-version.ps1 prints no version for an index of malformed ones' '' $electrumOut
$electrumOut = Get-Latest 'latest-electrum-version.ps1' '<a href="99999999999999999999.0.0/">x</a>'
Test-Same 'latest-electrum-version.ps1 prints no version for one too large for [version]' `
  $true ($electrumOut -eq '' -or $electrumOut -eq 'threw')
Remove-Item Function:\Invoke-WebRequest
Remove-Item Env:PORTANODE_TEST_INDEX

# --- the PowerShell inside a batch file --------------------------------------
# The text of the one powershell -Command argument on the line of $Batch that
# holds $Marker. Where this is not Windows, the backslash that joins a path is
# a slash.
function Get-BatchPowerShell {
  param([string]$Batch, [string]$Marker)
  $line = Get-Content -LiteralPath (Join-Path $utilities $Batch) |
    Where-Object { $_.Contains($Marker) -and $_.Contains('-Command "') } |
    Select-Object -First 1
  $start = $line.IndexOf('-Command "') + 10
  $text = $line.Substring($start, $line.LastIndexOf('"') - $start)
  if (-not $windows) { $text = $text.Replace("'\", "'/") }
  $text
}

# --- SHA256SUMS ---------------------------------------------------------------
# update-bitcoin.bat reads TMPDIR\SHA256SUMS and checks TMPDIR\FILE against
# the entries for FILE.
$checksumPs = Get-BatchPowerShell 'update-bitcoin.bat' 'Checksum entry not found'
$file = 'bitcoin-29.0-win64.zip'
Set-Content -LiteralPath (Join-Path $tmp $file) -Value 'the archive' -NoNewline
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $tmp $file)).Hash.ToLower()
$other = (Get-FileHash -Algorithm SHA256 -InputStream ([IO.MemoryStream]::new([Text.Encoding]::ASCII.GetBytes('another file')))).Hash.ToLower()

# Runs the checksum check on $Sums as the content of SHA256SUMS, and returns
# 'accepted' for exit 0 and 'refused' otherwise.
function Test-Checksum {
  param([string]$Sums)
  [IO.File]::WriteAllText((Join-Path $tmp 'SHA256SUMS'), $Sums)
  $env:TMPDIR = $tmp
  $env:FILE = $file
  $null = & $exe -NoProfile -Command $checksumPs 2>&1
  if ($LASTEXITCODE -eq 0) { 'accepted' } else { 'refused' }
}
$good = "$hash  $file`n"
Test-Same 'the checksum check accepts a correct SHA256SUMS' 'accepted' (Test-Checksum $good)
Test-Same 'the checksum check accepts a binary-mode entry' 'accepted' (Test-Checksum "$hash *$file`n")
Test-Same 'the checksum check refuses an empty SHA256SUMS' 'refused' (Test-Checksum '')
Test-Same 'the checksum check refuses a hash cut short' 'refused' `
  (Test-Checksum ($hash.Substring(0, 40) + "  $file`n"))
Test-Same 'the checksum check refuses a file name cut short' 'refused' `
  (Test-Checksum "$hash  $($file.Substring(0, $file.Length - 1))`n")
Test-Same 'the checksum check refuses SHA256SUMS cut mid-line' 'refused' `
  (Test-Checksum $good.Substring(0, 70))
Test-Same 'the checksum check refuses a hash and no name' 'refused' (Test-Checksum "$hash`n")
Test-Same 'the checksum check refuses a line with two hashes' 'refused' `
  (Test-Checksum "$hash  $other  $file`n")
Test-Same 'the checksum check refuses a line with two hashes, the good one second' 'refused' `
  (Test-Checksum "$other  $hash  $file`n")
Test-Same 'the checksum check refuses a wrong hash before the right one' 'refused' `
  (Test-Checksum "$other  $file`n$good")
Test-Same 'the checksum check refuses a wrong hash after the right one' 'refused' `
  (Test-Checksum "$good$other  $file`n")
Test-Same 'the checksum check refuses the hash under another file name' 'refused' `
  (Test-Checksum "$hash  other-$file`n")
Test-Same 'the checksum check refuses another file''s hash under its name' 'refused' `
  (Test-Checksum "$other  $file`n")
Test-Same 'the checksum check refuses its name behind ./' 'refused' (Test-Checksum "$hash  ./$file`n")
Test-Same 'the checksum check refuses its name behind a directory' 'refused' `
  (Test-Checksum "$hash  sub/$file`n")
Test-Same 'the checksum check refuses its name in another case' 'refused' `
  (Test-Checksum "$hash  $($file.ToUpper())`n")
Remove-Item Env:TMPDIR, Env:FILE

# --- gpg's status output ---------------------------------------------------------
# :verify_pgp_signature in lib.bat counts the good signatures in the status
# file by the pins in the fingerprints file, with :load_pin_reader's text
# pasted in where it says %PIN_READER_PS%. The findstr lines before it, which
# refuse a BADSIG and a status without NEWSIG or GOODSIG, are batch and are not
# run here.
$lib = Join-Path $utilities 'lib.bat'
$pinLine = Get-Content -LiteralPath $lib |
  Where-Object { $_.StartsWith('set "PIN_READER_PS=') } | Select-Object -First 1
$pinReader = $pinLine.Substring(19, $pinLine.Length - 20)
$verifyPs = (Get-BatchPowerShell 'lib.bat' 'Write-Output ($env:LABEL + '': good signatures from ''').Replace('%PIN_READER_PS%', $pinReader)
$p1 = '1' * 40
$p2 = '2' * 40
$outsider = '3' * 40
$sub1 = '4' * 40

# One signature gpg accepts.
function Get-GoodStatus {
  param([string]$Signing, [string]$Primary)
  "[GNUPG:] NEWSIG`n[GNUPG:] GOODSIG $($Signing.Substring(24)) portanode test <t@example.invalid>`n" +
  "[GNUPG:] VALIDSIG $Signing 2026-10-22 1792000000 0 4 0 22 10 00 $Primary`n"
}
# 'accepted' or 'refused' for $Status as the status file, under pins $p1 and
# $p2 that ask for $Min signatures.
function Test-Status {
  param([string]$Status, [int]$Min = 1)
  $pins = Join-Path $tmp 'pins'
  [IO.File]::WriteAllText($pins, "$p1`n$p2`nmin-signatures=$Min`n")
  $statusFile = Join-Path $tmp 'status'
  [IO.File]::WriteAllText($statusFile, $Status)
  $env:FPR_FILE = $pins
  $env:STATUS_FILE = $statusFile
  $env:LABEL = 'test'
  $null = & $exe -NoProfile -Command $verifyPs 2>&1
  if ($LASTEXITCODE -eq 0) { 'accepted' } else { 'refused' }
}
Test-Same 'the signature check accepts a signature by a pinned key' 'accepted' `
  (Test-Status (Get-GoodStatus $p1 $p1))
Test-Same 'the signature check accepts a signature by a pinned key''s subkey' 'accepted' `
  (Test-Status (Get-GoodStatus $sub1 $p1))
Test-Same 'the signature check refuses empty gpg output' 'refused' (Test-Status '')
Test-Same 'the signature check refuses a NEWSIG alone' 'refused' (Test-Status "[GNUPG:] NEWSIG`n")
Test-Same 'the signature check refuses a good signature by a key that is not pinned' 'refused' `
  (Test-Status (Get-GoodStatus $outsider $outsider))
Test-Same 'the signature check refuses a GOODSIG with no VALIDSIG' 'refused' `
  (Test-Status (((Get-GoodStatus $p1 $p1) -split "`n" | Where-Object { $_ -notmatch 'VALIDSIG' }) -join "`n"))
Test-Same 'the signature check refuses a VALIDSIG with no GOODSIG' 'refused' `
  (Test-Status (((Get-GoodStatus $p1 $p1) -split "`n" | Where-Object { $_ -notmatch 'GOODSIG' }) -join "`n"))
$goodLines = (Get-GoodStatus $p1 $p1) -split "`n"
$outsiderLines = (Get-GoodStatus $outsider $outsider) -split "`n"
Test-Same 'the signature check refuses a GOODSIG and a VALIDSIG of two keys' 'refused' `
  (Test-Status ("[GNUPG:] NEWSIG`n" + $outsiderLines[1] + "`n" + $goodLines[2] + "`n"))
Test-Same 'the signature check refuses a GOODSIG and a VALIDSIG in two signatures' 'refused' `
  (Test-Status ($outsiderLines[0] + "`n" + $outsiderLines[1] + "`n" + $goodLines[0] + "`n" + $goodLines[2] + "`n"))
Test-Same 'the signature check refuses a pinned signing key under an unpinned primary' 'refused' `
  (Test-Status (Get-GoodStatus $p1 $outsider))
Test-Same 'the signature check refuses two GOODSIG lines in one signature' 'refused' `
  (Test-Status ((Get-GoodStatus $p1 $p1) + $outsiderLines[1] + "`n"))
Test-Same 'the signature check refuses a revoked key''s signature' 'refused' `
  (Test-Status ((Get-GoodStatus $p1 $p1) + "[GNUPG:] KEYREVOKED`n"))
Test-Same 'the signature check refuses a REVKEYSIG' 'refused' `
  (Test-Status ((Get-GoodStatus $p1 $p1).Replace('GOODSIG', 'REVKEYSIG')))
Test-Same 'the signature check refuses an expired key''s signature' 'refused' `
  (Test-Status ((Get-GoodStatus $p1 $p1).Replace('GOODSIG', 'EXPKEYSIG')))
Test-Same 'the signature check refuses a status line that does not start the line' 'refused' `
  (Test-Status ((Get-GoodStatus $p1 $p1).Replace('[GNUPG:]', ' [GNUPG:]')))
Test-Same 'the signature check refuses one of two required signatures' 'refused' `
  (Test-Status (Get-GoodStatus $p1 $p1) 2)
Test-Same 'the signature check refuses one key signing twice for two required signatures' 'refused' `
  (Test-Status ((Get-GoodStatus $p1 $p1) + (Get-GoodStatus $sub1 $p1)) 2)
Test-Same 'the signature check accepts two pinned keys for two required signatures' 'accepted' `
  (Test-Status ((Get-GoodStatus $p1 $p1) + (Get-GoodStatus $p2 $p2)) 2)
Test-Same 'the signature check refuses a pinned and an unpinned key for two required signatures' 'refused' `
  (Test-Status ((Get-GoodStatus $p1 $p1) + (Get-GoodStatus $outsider $outsider)) 2)
Remove-Item Env:FPR_FILE, Env:STATUS_FILE, Env:LABEL

Remove-Item -LiteralPath $tmp -Recurse -Force
Complete-Test
