# Prints the whole gigabytes still writable on the volume holding -Path,
# then exits 0. Exits 1 (no output) where that volume cannot be read.
#
# The callers are .bat files, and cmd.exe's set /a is 32-bit signed: a
# free-byte count above 2147483647 wraps there, and every volume this
# folder is meant for is larger than that. So the division happens here,
# in 64-bit arithmetic, and what crosses back to cmd.exe is a figure that
# fits.
#
# AvailableFreeSpace, not TotalFreeSpace: the two differ where a disk
# quota applies, and the former is what says how much can still be
# written. It is also what df -Pk reports to the macOS half.
#
# DriveInfo takes a drive root, so a UNC path throws here and the callers
# report the space as unknown -- which is what they should say about a
# folder reached over a share, rather than reporting it as zero.
param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

$ErrorActionPreference = 'Stop'

try {
    $full = (Resolve-Path -LiteralPath $Path).ProviderPath
    $root = [System.IO.Path]::GetPathRoot($full)
    $drive = New-Object -TypeName System.IO.DriveInfo -ArgumentList $root
    Write-Output ([int64][math]::Floor($drive.AvailableFreeSpace / 1GB))
} catch {
    exit 1
}
