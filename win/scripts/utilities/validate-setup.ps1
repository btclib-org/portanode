param(
  [Parameter(Mandatory = $true)]
  [string]$RootDir
)

$checksum = Join-Path $RootDir 'win/checksums.sha256'
if (-not (Test-Path $checksum)) {
  Write-Host '- win/checksums.sha256: missing'
  exit 0
}

$lines = Get-Content $checksum |
  Where-Object { $_ -and ($_ -notmatch '^\s*#') }

$pattern = '^(?<hash>[0-9a-fA-F]{64})' +
  '\s+(?<path>.+?)(?:\s+version=(?<ver>.+))?$'

$map = @{}
foreach ($line in $lines) {
  $m = [regex]::Match($line, $pattern)
  if (-not $m.Success) {
    continue
  }
  $path = $m.Groups['path'].Value.Trim()
  $path = $path -replace '\\\\', '/'
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
    Hash = $m.Groups['hash'].Value.ToLower()
    Version = $ver
  }
}

foreach ($path in $map.Keys) {
  $relative = $path -replace '/', [IO.Path]::DirectorySeparatorChar
  $filePath = Join-Path $RootDir $relative
  if (-not (Test-Path $filePath)) {
    Write-Host "- $path: missing"
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
    Write-Host "- $path: $versions"
  } else {
    Write-Host "- $path: unknown"
  }
}
