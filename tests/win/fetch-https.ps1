# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# fetch-https.ps1 and the updaters' fetches through it: HTTPS on the request and
# on every redirect. A stand-in for Invoke-WebRequest answers as Windows
# PowerShell 5.1 answers under -MaximumRedirection 0, and a stand-in for
# save-response.ps1 beside a copy of fetch-https.ps1 answers from it, so the cases
# run on any system with pwsh. What the real cmdlet does was measured on
# windows-latest, as fetch-https.ps1's header says; tests/win/save-response.ps1
# tests the real save-response.ps1.

Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$utilities = Join-Path $repo 'win\scripts\utilities'
$exe = (Get-Process -Id $PID).Path
$windows = $env:OS -eq 'Windows_NT'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-fetch-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName
$here = (Get-Location).Path
$scripts = (New-Item -ItemType Directory -Path (Join-Path $tmp 'scripts')).FullName
Copy-Item -LiteralPath (Join-Path $utilities 'fetch-https.ps1') -Destination $scripts
Set-Content -LiteralPath (Join-Path $scripts 'save-response.ps1') -Value @'
param($Uri, $OutFile, $TimeoutSec)
$response = Invoke-WebRequest -Uri $Uri -Method Get -TimeoutSec $TimeoutSec -MaximumRedirection 0 -ErrorAction SilentlyContinue
if ([int]$response.StatusCode -ge 300) { return $response }
Set-Content -LiteralPath $OutFile -Value 'the body' -NoNewline
'@
$env:SCRIPT_DIR = $scripts
$env:PORTANODE_TEST_REQUESTS = Join-Path $tmp 'requests'
$https = 'https://example.invalid'

# The stand-in, as text: the batch cases run it in a powershell of their own,
# and it has no double quote, which 5.1 drops from a command line. The path of a
# request's URL picks its answer, unless it matches PORTANODE_TEST_REDIRECT; the
# URL and its arguments are recorded.
$stub = @'
function Invoke-WebRequest {
  [CmdletBinding()]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'A stand-in for the cmdlet, as the comment above says.')]
  param($Uri, $Method, $TimeoutSec, [switch]$UseBasicParsing, $MaximumRedirection)
  function Get-Redirect {
    param($Location, $Status = 302)
    if ($Status -in 301, 302) { Write-Error -Message 'too many' -ErrorId 'MaximumRedirectExceeded' }
    [pscustomobject]@{ StatusCode = $Status; Headers = $Location }
  }
  Add-Content -LiteralPath $env:PORTANODE_TEST_REQUESTS ($Uri + ' ' + $Method + ' ' + $TimeoutSec + ' ' + $MaximumRedirection)
  $redirects = @{
    '/to-http' = 'http://example.invalid/final'; '/to-http-upper' = 'HTTP://example.invalid/final';
    '/to-ftp' = 'ftp://example.invalid/final'; '/to-file' = 'file:///etc/hosts';
    '/to-https' = 'https://other.invalid/final'; '/to-https-upper' = 'HTTPS://example.invalid/final';
    '/relative' = '/final'; '/net-path' = '//other.invalid/final'; '/net-path-http' = 'http:/final';
    '/chain' = '/to-https'; '/chain-http' = '/to-http'; '/loop' = '/loop'; '/bad' = 'https://[' }
  if ($env:PORTANODE_TEST_REDIRECT -and $Uri -match $env:PORTANODE_TEST_REDIRECT) {
    return Get-Redirect @{ Location = 'http://example.invalid/final' }
  }
  $path = ([uri]$Uri).AbsolutePath -replace '[.]asc$', ''
  if ($path -eq '/no-answer') { return }
  if ($path -match '^/s(\d+)-(http|https)$') {
    return Get-Redirect @{ Location = ($Matches[2] + '://example.invalid/final') } ([int]$Matches[1])
  }
  if ($path -eq '/missing') { throw [Net.WebException]::new('404') }
  if ($path -eq '/no-location') { return Get-Redirect @{} }
  if ($redirects.ContainsKey($path)) { return Get-Redirect @{ Location = $redirects[$path] } }
  [pscustomobject]@{ StatusCode = 200; Content = $(if ($env:PORTANODE_TEST_INDEX) { $env:PORTANODE_TEST_INDEX } else { 'the body' }); Headers = @{ 'Content-Length' = '8' } }
}
'@
. ([scriptblock]::Create($stub))

# The URLs requested since the last call, joined by a space.
function Get-Requested {
  $file = $env:PORTANODE_TEST_REQUESTS
  if (-not (Test-Path -LiteralPath $file)) { return '' }
  $urls = @(Get-Content -LiteralPath $file | ForEach-Object { ($_ -split ' ')[0] })
  Remove-Item -LiteralPath $file
  $urls -join ' '
}
# The outcome of a fetch of $Uri, 'threw' or its content.
function Invoke-Fetch {
  param([string]$Uri)
  try {
    (& (Join-Path $scripts 'fetch-https.ps1') -Uri $Uri).Content
  } catch {
    'threw'
  }
}

# --- what is refused, and what never goes out -----------------------------------
foreach ($case in @(
    @('to plain HTTP', '/to-http', "$https/to-http"),
    @('to plain HTTP in capitals', '/to-http-upper', "$https/to-http-upper"),
    @('to FTP', '/to-ftp', "$https/to-ftp"),
    @('to a file', '/to-file', "$https/to-file"),
    @('to HTTP by a scheme and a path', '/net-path-http', "$https/net-path-http"),
    @('to HTTP on a later hop', '/chain-http', "$https/chain-http $https/to-http"),
    @('with no Location', '/no-location', "$https/no-location"),
    @('with a Location that is no URL', '/bad', "$https/bad"))) {
  Test-Same "a redirect $($case[0]) throws" 'threw' (Invoke-Fetch ($https + $case[1]))
  Test-Same "a redirect $($case[0]) requests only: $($case[2])" $case[2] (Get-Requested)
}
Test-Same 'a plain HTTP URL throws' 'threw' (Invoke-Fetch 'http://example.invalid/final')
Test-Same 'a plain HTTP URL requests nothing' '' (Get-Requested)
Test-Same 'a URL with no scheme throws' 'threw' (Invoke-Fetch '/final')
Test-Same 'a URL with no scheme requests nothing' '' (Get-Requested)
Test-Same 'a redirect loop throws' 'threw' (Invoke-Fetch "$https/loop")
Test-Same 'a redirect loop stops after six requests' 6 ((Get-Requested) -split ' ').Count
Test-Same 'a failed request throws' 'threw' (Invoke-Fetch "$https/missing")
$null = Get-Requested
Test-Same 'a request that answers nothing throws' 'threw' (Invoke-Fetch "$https/no-answer")
$null = Get-Requested

# --- what is followed --------------------------------------------------------
Test-Same 'a URL that does not redirect is fetched' 'the body' (Invoke-Fetch "$https/final")
Test-Same 'it is requested once' "$https/final" (Get-Requested)
foreach ($case in @(
    @('to HTTPS', '/to-https', 'https://other.invalid/final'),
    @('to HTTPS in capitals', '/to-https-upper', "$https/final"),
    @('to a path', '/relative', "$https/final"),
    @('to another host by //', '/net-path', 'https://other.invalid/final'))) {
  Test-Same "a redirect $($case[0]) is followed" 'the body' (Invoke-Fetch ($https + $case[1]))
  Test-Same "a redirect $($case[0]) ends at $($case[2])" "$https$($case[1]) $($case[2])" (Get-Requested)
}
Test-Same 'a chain of redirects is followed' 'the body' (Invoke-Fetch "$https/chain")
Test-Same 'a chain of redirects requests each hop' "$https/chain $https/to-https https://other.invalid/final" (Get-Requested)

# --- what each request is told -----------------------------------------------
$null = & (Join-Path $scripts 'fetch-https.ps1') -Uri "$https/relative" -Method Head -TimeoutSec 30
$lines = @(Get-Content -LiteralPath $env:PORTANODE_TEST_REQUESTS)
Remove-Item -LiteralPath $env:PORTANODE_TEST_REQUESTS
Test-Same 'each hop keeps -Method, -TimeoutSec and -MaximumRedirection 0' `
  "$https/relative Head 30 0|$https/final Head 30 0" ($lines -join '|')
$out = Join-Path $tmp 'out'
# A save needs the stand-in beside it, so it runs from that directory.
function Invoke-Save {
  param([string]$Uri)
  Push-Location -LiteralPath $scripts
  try {
    $printed = @(& .\fetch-https.ps1 -Uri $Uri -OutFile $out)
    if ($printed.Count) { "printed $($printed.Count)" } else { Get-Content -Raw -LiteralPath $out }
  } catch {
    'threw'
  } finally {
    Pop-Location
  }
}
Test-Same '-OutFile writes the final body and prints nothing' 'the body' (Invoke-Save "$https/relative")
Test-Same '-OutFile asks each hop once' "$https/relative $https/final" (Get-Requested)
Test-Same '-OutFile refuses a redirect to plain HTTP' 'threw' (Invoke-Save "$https/to-http")
Test-Same '-OutFile sends no plain request' "$https/to-http" (Get-Requested)

# --- each status -----------------------------------------------------------------
# Measured under 5.1: only a 301 and a 302 raise MaximumRedirectExceeded.
foreach ($code in 300, 301, 302, 303, 304, 305, 307, 308) {
  Test-Same "a $code to HTTP throws" 'threw' (Invoke-Fetch "$https/s$code-http")
  Test-Same "a $code to HTTP sends no plain request" "$https/s$code-http" (Get-Requested)
  Test-Same "a $code to HTTPS is followed" 'the body' (Invoke-Fetch "$https/s$code-https")
  $null = Get-Requested
  Remove-Item -LiteralPath $out
  Test-Same "-OutFile: a $code to HTTP throws" 'threw' (Invoke-Save "$https/s$code-http")
  Test-Same "-OutFile: a $code to HTTP writes no file" $false (Test-Path -LiteralPath $out)
  Test-Same "-OutFile: a $code to HTTP sends no plain request" "$https/s$code-http" (Get-Requested)
  Test-Same "-OutFile: a $code to HTTPS is followed" 'the body' (Invoke-Save "$https/s$code-https")
  $null = Get-Requested
}

# --- the updaters --------------------------------------------------------------
# The scripts, run here with the stand-in. Run by a relative name, they move this
# process into their own directory, so the test goes back.
function Get-LatestOver {
  param([string]$Script)
  try { (@(& (Join-Path $utilities $Script)) -join '|') } catch { 'threw' } finally { Set-Location -LiteralPath $here }
}
$env:PORTANODE_TEST_INDEX = '<a href="bitcoin-core-29.0/">x</a><a href="4.6.0/">x</a>'
$env:PORTANODE_TEST_REDIRECT = '/bin/$|org/$'
Test-Same 'latest-bitcoin-version.ps1 answers INDEX_UNREACHABLE where its index redirects to HTTP' `
  'INDEX_UNREACHABLE' (Get-LatestOver 'latest-bitcoin-version.ps1')
Test-Same 'latest-electrum-version.ps1 answers INDEX_UNREACHABLE where its index redirects to HTTP' `
  'INDEX_UNREACHABLE' (Get-LatestOver 'latest-electrum-version.ps1')
$env:PORTANODE_TEST_REDIRECT = 'zip$'
Test-Same 'latest-bitcoin-version.ps1 takes no version whose probe redirects to HTTP' `
  '' (Get-LatestOver 'latest-bitcoin-version.ps1')
Test-Same 'neither script requested a plain URL' 0 `
  @(Get-Content -LiteralPath $env:PORTANODE_TEST_REQUESTS | Where-Object { $_ -like 'http:*' }).Count
Remove-Item -LiteralPath $env:PORTANODE_TEST_REQUESTS
Remove-Item Env:PORTANODE_TEST_REDIRECT
Test-Same 'latest-bitcoin-version.ps1 still answers where nothing redirects' '29.0' (Get-LatestOver 'latest-bitcoin-version.ps1')
Remove-Item -LiteralPath $env:PORTANODE_TEST_REQUESTS
Remove-Item Env:PORTANODE_TEST_INDEX

# The powershell lines of the batch files, run with their real text and the
# stand-in, each URL pointing at a redirect to HTTP and then at a plain fetch.
# Where this is not Windows, the backslash that joins a path is a slash.
$env:TMPDIR = $tmp
$env:FILE = 'archive'
$env:SIG_FILE = 'archive.asc'
foreach ($fetches in @(@('update-bitcoin.bat', 4), @('update-electrum.bat', 3))) {
  $batch = $fetches[0]
  $texts = @(Get-Content -LiteralPath (Join-Path $utilities $batch) |
    Where-Object { $_.Contains('fetch-https.ps1 -Uri') -and $_.Contains('-Command "') } |
    ForEach-Object {
      $start = $_.IndexOf('-Command "') + 10
      $text = $_.Substring($start, $_.LastIndexOf('"') - $start)
      if (-not $windows) { $text = $text.Replace("'\", "'/").Replace(' .\', ' ./') }
      $text
    })
  Test-Same "$batch has the fetches this test reads" $fetches[1] $texts.Count
  $n = 0
  foreach ($text in $texts) {
    $n++
    $head = $text.Contains('-Method Head')
    foreach ($case in @(@('to-http', 1), @('final', 0))) {
      foreach ($name in 'URL', 'CHECKSUM_URL', 'CHECKSUM_SIG_URL') {
        Set-Item "Env:$name" "$https/$($case[0])"
      }
      $file = $env:PORTANODE_TEST_REQUESTS
      $out = @(& $exe -NoProfile -Command ($stub + "`n" + $text) 2>&1) -join ' '
      $status = $LASTEXITCODE
      $plain = @(Get-Content -LiteralPath $file | Where-Object { $_ -like 'http:*' }).Count
      Remove-Item -LiteralPath $file
      Test-Same "$batch fetch $n, $($case[0]): no plain request" 0 $plain
      if ($head) {
        $want = if ($case[1]) { '' } else { '8' }
        Test-Same "$batch size probe $n, $($case[0]): Content-Length" $want $out
      } else {
        Test-Same "$batch fetch $n, $($case[0]): exit code" $case[1] $status
      }
    }
  }
}
Remove-Item Env:TMPDIR, Env:FILE, Env:SIG_FILE, Env:URL, Env:CHECKSUM_URL, Env:CHECKSUM_SIG_URL

# --- no fetch goes around it -----------------------------------------------------
# Every script under win/ is read, comments and messages left out; the two that
# fetch are what prove the pattern.
$around = @(Get-ChildItem -LiteralPath (Join-Path $repo 'win') -Recurse -File -Include '*.ps1', '*.bat' |
    Select-String -Pattern '\b(Invoke-WebRequest|Invoke-RestMethod|iwr|irm|curl|wget|bitsadmin|certutil|Start-BitsTransfer)\b|WebClient|WebRequest\]|HttpWebRequest|HttpClient|save-response' |
    Where-Object { $_.Line -notmatch '^\s*(#|REM\b|echo\b)' } |
    ForEach-Object { Split-Path -Leaf $_.Path } | Sort-Object -Unique)
Test-Same 'under win/ only fetch-https.ps1 and save-response.ps1 fetch' 'fetch-https.ps1 save-response.ps1' ($around -join ' ')

Remove-Item Env:SCRIPT_DIR, Env:PORTANODE_TEST_REQUESTS
Remove-Item -LiteralPath $tmp -Recurse -Force
Complete-Test
