param(
  [Parameter(Mandatory = $true)]
  [string]$RootDir
)

$checksum = Join-Path $RootDir 'win/checksums.sha256'
if (-not (Test-Path $checksum)) {
  Write-Host "Error: $checksum not found."
  exit 1
}

$pattern = '^(?<hash>[0-9a-fA-F]{64})' +
  '\s+(?<path>.+?)(?:\s+version=(?<ver>.+))?$'

$lines = Get-Content $checksum
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

$fail = 0
foreach ($path in $map.Keys) {
  $relative = $path -replace '/', [IO.Path]::DirectorySeparatorChar
  $filePath = Join-Path $RootDir $relative
  $expectedVersions = $map[$path] |
    Select-Object -ExpandProperty Version |
    Select-Object -Unique
  $expectedText = ''
  if ($expectedVersions.Count -gt 0) {
    $expectedText = ($expectedVersions -join ', ')
  }
  if (-not (Test-Path $filePath)) {
    if ($expectedText) {
      Write-Host "$path: MISSING (expected versions: $expectedText)"
    } else {
      Write-Host "$path: MISSING"
    }
    continue
  }
  $computed = (Get-FileHash -Algorithm SHA256 $filePath).Hash
  $computed = $computed.ToLower()
  $matches = $map[$path] | Where-Object { $_.Hash -eq $computed }
  if ($matches.Count -gt 0) {
    $versions = $matches |
      Select-Object -ExpandProperty Version |
      Select-Object -Unique
    $versions = $versions -join ', '
    Write-Host "$path: OK (version: $versions)"
  } else {
    if ($expectedText) {
      Write-Host "$path: FAILED (expected versions: $expectedText)"
    } else {
      Write-Host "$path: FAILED"
    }
    $fail++
  }
}

if ($fail -gt 0) {
  Write-Host "Verification failed: $fail file(s)."
  exit 1
}

Write-Host "Binaries verified."
