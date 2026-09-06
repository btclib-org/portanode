# Prints the filesystem name (NTFS, exFAT, FAT32, ...) of the volume holding
# -Path, then exits 0. Exits 1 (no output) where that volume cannot be read.
#
# win/scripts/utilities/set-permissions.bat asks this after each data
# directory, and matches the answer against the volumes that hold no ACL --
# exFAT and FAT32 among them -- rather than against the ones that do. A name
# it does not recognise reaches its ACL readback instead, so whether the
# restriction is in force is that readback's answer rather than this one.
# What this answer decides is the explanation an unrestricted directory
# carries, and whether such a directory exits 2 or 1.
param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

$ErrorActionPreference = 'Stop'

try {
    $full = (Resolve-Path -LiteralPath $Path).ProviderPath
    $root = [System.IO.Path]::GetPathRoot($full)
    $drive = New-Object -TypeName System.IO.DriveInfo -ArgumentList $root
    Write-Output $drive.DriveFormat
} catch {
    exit 1
}
