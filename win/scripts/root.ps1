function Resolve-PortaNodeRoot {
  param(
    [Parameter(Mandatory = $true)]
    [string]$StartDir
  )

  if ($env:PORTANODE_ROOT) {
    try {
      return (Resolve-Path $env:PORTANODE_ROOT).Path
    } catch {
      return $env:PORTANODE_ROOT
    }
  }

  $dir = (Resolve-Path $StartDir).Path
  while ($true) {
    if (Test-Path (Join-Path $dir 'VERSION')) {
      return $dir
    }
    $parent = Split-Path -Parent $dir
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $dir) {
      return $dir
    }
    $dir = $parent
  }
}
