param(
  [Parameter(Mandatory = $true)]
  [string]$RootDir
)

$checksum = Join-Path $RootDir 'win\\checksums.sha256'
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
  if (-not (Test-Path $path)) {
    Write-Host "$path : MISSING"
    continue
  }
  $computed = (Get-FileHash -Algorithm SHA256 $path).Hash
  $computed = $computed.ToLower()
  $matches = $map[$path] | Where-Object { $_.Hash -eq $computed }
  if ($matches.Count -gt 0) {
    $versions = $matches |
      Select-Object -ExpandProperty Version |
      Select-Object -Unique
    $versions = $versions -join ', '
    Write-Host "$path : OK (version: $versions)"
  } else {
    Write-Host "$path : FAILED"
    $fail++
  }
}

if ($fail -gt 0) {
  Write-Host "Verification failed: $fail file(s)."
  exit 1
}

Write-Host "Verification complete: all OK."
