param(
  [Parameter(Mandatory = $true)]
  [string]$RootDir
)

$checksum = Join-Path $RootDir 'win/checksums.sha256'
# -LiteralPath on every path built from $RootDir: -Path reads a wildcard
# pattern, so under a root holding "[x]" it names another folder's file,
# or none.
if (-not (Test-Path -LiteralPath $checksum -PathType Leaf)) {
  Write-Host 'Error: win/checksums.sha256 not found, or not a file.'
  exit 1
}

$pattern = '^(?<hash>[0-9a-fA-F]{64})' +
  '\s+(?<path>.+?)(?:\s+version=(?<ver>.+))?$'

# -ErrorAction Stop: Get-Content's failure is otherwise non-terminating, and
# an unreadable file would leave $lines empty and end in "Nothing to verify"
# and exit 0, the answer a verified folder gives.
try {
  $lines = Get-Content -LiteralPath $checksum -ErrorAction Stop
} catch {
  Write-Host 'Error: win/checksums.sha256 could not be read.'
  exit 1
}
$map = @{}
foreach ($line in $lines) {
  if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\s*#') {
    continue
  }
  $m = [regex]::Match($line, $pattern)
  if (-not $m.Success) {
    Write-Host "Malformed line: $line"
    exit 1
  }
  $hash = $m.Groups['hash'].Value.ToLower()
$path = $m.Groups['path'].Value.Trim()
$path = $path -replace '\\', '/'
  if (-not $path.ToLower().StartsWith('win/')) {
    continue
  }
  $ver = $m.Groups['ver'].Value
  if ([string]::IsNullOrWhiteSpace($ver)) {
    $ver = 'unknown'
  }
  if (-not $map.ContainsKey($path)) {
    $map[$path] = @()
  }
  $map[$path] += [pscustomobject]@{
    Hash = $hash
    Version = $ver
  }
}

if ($map.Keys.Count -eq 0) {
  Write-Host 'Nothing to verify: no win/* entries in win/checksums.sha256.'
  exit 0
}

$fail = 0
foreach ($path in $map.Keys) {
  $relative = $path -replace '/', [IO.Path]::DirectorySeparatorChar
  $filePath = Join-Path $RootDir $relative
  # @(...): a pipeline that yields exactly one object is assigned as that
  # object rather than as a one-element array, and Windows PowerShell 5.1
  # -- what the .bat callers run this under -- gives a bare PSCustomObject
  # no .Count, so $hashMatches.Count -gt 0 below reads false for an
  # intact binary with one recorded version (issue #361). @(...) forces
  # the array even for one result. That was measured for $hashMatches,
  # whose pipeline yields one; the same wrap on $expectedVersions, whose
  # pipeline yields a string, is defensive rather than a repair, no 5.1
  # measurement of the string case having been made.
  $expectedVersions = @($map[$path] |
    Select-Object -ExpandProperty Version |
    Select-Object -Unique)
  $expectedText = ''
  if ($expectedVersions.Count -gt 0) {
    $expectedText = ($expectedVersions -join ', ')
  }
  if (-not (Test-Path -LiteralPath $filePath)) {
    if ($expectedText) {
      Write-Host "${path}: MISSING (expected versions: $expectedText)"
    } else {
      Write-Host "${path}: MISSING"
    }
    $fail++
    continue
  }
  $computed = (Get-FileHash -Algorithm SHA256 -LiteralPath $filePath).Hash
  $computed = $computed.ToLower()
  # @(...): see the comment on $expectedVersions above -- the same
  # single-result collapse applies to a Where-Object result.
  $hashMatches = @($map[$path] | Where-Object { $_.Hash -eq $computed })
  if ($hashMatches.Count -gt 0) {
    $versions = $hashMatches |
      Select-Object -ExpandProperty Version |
      Select-Object -Unique
    $versions = $versions -join ', '
    Write-Host "${path}: OK (version: $versions)"
  } else {
    if ($expectedText) {
      Write-Host "${path}: FAILED (expected versions: $expectedText)"
    } else {
      Write-Host "${path}: FAILED"
    }
    $fail++
  }
}

if ($fail -gt 0) {
  Write-Host "Verification failed: $fail file(s)."
  exit 1
}

Write-Host "Binaries verified."
