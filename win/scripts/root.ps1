function Resolve-PortaNodeRoot {
  param(
    [Parameter(Mandatory = $true)]
    [string]$StartDir
  )

  # -LiteralPath throughout: Resolve-Path and Test-Path read -Path as a
  # wildcard pattern, so a mount point holding "[" and "]" answers not
  # found for a directory that is on disk, and the walk below then runs
  # past the root it is meant to stop at. Quoting the argument does not
  # reach it: the pattern is interpreted after the value is bound. The
  # call operator and dot-sourcing take a name rather than a pattern,
  # which is why a launcher reaches this file and its own menu scripts
  # without one.
  if ($env:PORTANODE_ROOT) {
    try {
      return (Resolve-Path -LiteralPath $env:PORTANODE_ROOT).Path
    } catch {
      return $env:PORTANODE_ROOT
    }
  }

  $dir = (Resolve-Path -LiteralPath $StartDir).Path
  while ($true) {
    if (Test-Path -LiteralPath (Join-Path $dir 'VERSION')) {
      return $dir
    }
    $parent = Split-Path -Parent $dir
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $dir) {
      return $dir
    }
    $dir = $parent
  }
}
