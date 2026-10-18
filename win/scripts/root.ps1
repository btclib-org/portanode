# True where Dir holds VERSION plus one of macos/, win/ or linux/, the
# marker resolve_root in shared/lib.sh looks for; the comment at the head
# of that loop argues why any one of the three is enough.
# -PathType Container is what makes the platform test a directory test:
# without it a plain file named win answers here. The VERSION test carries
# no -PathType, so a directory of that name answers where resolve_root's
# own [ -f ] refuses it. -LiteralPath: see Resolve-PortaNodeRoot below.
function Test-PortaNodeRoot {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Dir
  )

  if (-not (Test-Path -LiteralPath $Dir -PathType Container)) {
    return $false
  }
  foreach ($name in 'macos', 'win', 'linux') {
    if (Test-Path -LiteralPath (Join-Path $Dir $name) -PathType Container) {
      return (Test-Path -LiteralPath (Join-Path $Dir 'VERSION'))
    }
  }
  return $false
}

function Resolve-PortaNodeRoot {
  param(
    [Parameter(Mandatory = $true)]
    [string]$StartDir
  )

  # -LiteralPath throughout: Resolve-Path and Test-Path read -Path as a
  # wildcard pattern, so a mount point holding "[" and "]" answers not
  # found for a directory that is on disk, and the walk below then runs
  # past the root it is meant to stop at. Quoting the argument does not
  # reach it: the pattern is interpreted after the value is bound.
  #
  # Running a script by its path is the same trap under Windows PowerShell
  # 5.1, with no -LiteralPath to reach for: -File, the call operator and
  # dot-sourcing each resolve the path as a pattern there, so under a root
  # holding "[x]" beside a folder "x" they run x's copy of the script.
  # PowerShell 7 runs the one named. Escaping the pattern characters
  # satisfies 5.1 and sends 7 looking for a name that holds the escapes;
  # Set-Location -LiteralPath into the script's own directory and a run of
  # ".\<name>" holds under both, the name carrying no pattern character of
  # its own. The launchers reach this file and their menu scripts that
  # way, and a .bat starts a .ps1 that way through powershell -Command:
  # 5.1's -File resolves ".\<name>" against the current directory as a
  # pattern as well. Measured on windows-latest under both versions.
  #
  # A PORTANODE_ROOT that is not a root is an error: the message names the
  # variable and the function returns nothing, which a caller stops on
  # (`if (-not $Root) { exit 1 }`), there being no root to build paths on.
  if ($env:PORTANODE_ROOT) {
    if (Test-PortaNodeRoot -Dir $env:PORTANODE_ROOT) {
      return (Resolve-Path -LiteralPath $env:PORTANODE_ROOT).Path
    }
    $host.UI.WriteErrorLine("PORTANODE_ROOT is set to `"$env:PORTANODE_ROOT`", which is not a PortaNode folder: it holds no VERSION beside macos/, win/ or linux/. Unset PORTANODE_ROOT, or set it to the folder.")
    return $null
  }

  $start = (Resolve-Path -LiteralPath $StartDir).Path
  $dir = $start
  while ($true) {
    if (Test-PortaNodeRoot -Dir $dir) {
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
