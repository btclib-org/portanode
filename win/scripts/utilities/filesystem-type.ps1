# Prints the filesystem name (NTFS, exFAT, FAT32, ...) of the volume holding
# -Path, then exits 0. Exits 1 (no output) where that volume cannot be read.
#
# Windows stores an ACL only on NTFS; exFAT and FAT32 hold no ACL at all, so a
# caller that just wrote one needs to know which case it is in before
# claiming the ACL restricted anything -- it is what
# win/scripts/utilities/set-permissions.bat asks after each data directory.
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
