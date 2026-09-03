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

  $start = (Resolve-Path -LiteralPath $StartDir).Path
  $dir = $start
  while ($true) {
    # A root is marked by VERSION plus one of macos/, win/ or linux/,
    # which is the marker resolve_root in shared/lib.sh looks for; the
    # comment at the head of that loop argues why any one of the three is
    # enough. -PathType Container is what makes the platform test a
    # directory test: without it a plain file named win answers here. The
    # VERSION test carries no -PathType, so a directory of that name
    # answers where resolve_root's own [ -f ] refuses it.
    $platform = $false
    foreach ($name in 'macos', 'win', 'linux') {
      if (Test-Path -LiteralPath (Join-Path $dir $name) -PathType Container) {
        $platform = $true
        break
      }
    }
    if ($platform -and (Test-Path -LiteralPath (Join-Path $dir 'VERSION'))) {
      return $dir
    }
    $parent = Split-Path -Parent $dir
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $dir) {
      # A walk that reaches the top of the drive without a match returns
      # the directory it started in rather than the drive root. Neither
      # names a real root, so what this settles is which directory a
      # failed walk hands back, and the drive root is also what a hit
      # returns for a folder unpacked at the top of a volume: a caller
      # handed that value cannot tell the two apart, where $start is the
      # argument it passed in.
      return $start
    }
    $dir = $parent
  }
}
