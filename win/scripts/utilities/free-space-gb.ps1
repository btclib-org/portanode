# Prints the whole gigabytes still writable on the volume holding -Path,
# then exits 0. Exits 1 (no output) where that volume cannot be read.
#
# The callers are .bat files, and cmd.exe's set /a is 32-bit signed: a
# free-byte count above 2147483647 wraps there, and every volume this
# folder is meant for is larger than that. So the division happens here,
# in 64-bit arithmetic, and what crosses back to cmd.exe is a figure that
# fits.
#
# GetDiskFreeSpaceEx takes the directory itself, so the volume answered for
# is the one holding -Path even where that directory is a Windows volume
# mount point. [System.IO.Path]::GetPathRoot hands back the drive letter's
# own root instead, and System.IO.DriveInfo answers for whatever volume the
# letter carries: measured on windows-latest against a 1GB exFAT VHD mounted
# with mountvol at a directory on a 200GB NTFS one, that pair reports the
# NTFS volume's free gigabytes for the mount point where the volume actually
# mounted there has none. win/scripts/utilities/validate-setup.bat refuses a
# folder reporting under 100 and exits 1, so the figure decides a refusal and
# not only a line of output; health-check.bat and the two updaters' --dry-run
# summaries print it and compare nothing.
#
# lpFreeBytesAvailableToCaller, not lpTotalNumberOfFreeBytes: the two differ
# where a disk quota applies, and the former is what says how much can still
# be written. It is the figure DriveInfo.AvailableFreeSpace carries --
# measured equal on windows-latest against NTFS, exFAT, FAT32 and ReFS
# volumes -- and what df -Pk reports to the macOS half.
#
# A path on a share is answered rather than refused, which is the decision
# #474 reserved for this comment. GetDiskFreeSpaceEx takes a UNC path where
# DriveInfo throws on one: measured on windows-latest against a share of a
# directory on C:, the share root with no trailing separator, the same with
# one, and a subdirectory under it each report the whole gigabytes C:\ itself
# reports, where GetPathRoot with DriveInfo exits without a figure for all
# three. The share root is measured beside the subdirectory because a folder
# mounted there reaches this script carrying no trailing separator --
# win/scripts/root.bat keeps one only where the last two characters are ":\"
# -- so the separator the call's own documentation asks for on a UNC name is
# the thing that would have been missing, and is not needed.
#
# What refusing would cost is the check itself: validate-setup.bat prints
# "Could not determine disk free space." and carries on to its next line, so
# a refusal removes the 100GB refusal on exactly the folders it would apply
# to. What lands on such a folder's volume is the chain data Bitcoin Core
# writes under bitcoin-datadir, which is what the 100GB and 700GB thresholds
# are about; the updaters' own downloads do not land there, unpacking under
# %TEMP% on the local disk instead. win/scripts/utilities/filesystem-type.ps1
# names a share's filesystem rather than declining it, so the two answer for
# the same folder rather than one of them alone.
#
# Add-Type compiles the declaration below and so needs a writable %TEMP%,
# which GetPathRoot does not. What that costs is the refusal: measured on
# windows-latest with %TEMP% on an unmapped drive letter, this script exits 1
# and validate-setup.bat prints "Could not determine disk free space." and
# carries on to exit 0, where GetPathRoot answers and its 100GB test runs.
# Falling back to GetPathRoot there is refused twice over. An Add-Type that
# does not compile leaves no call made at all, so there is nothing to fall
# back from, where filesystem-type.ps1's own fallback follows a call that ran
# and failed at a root it names. And the two roots are not the same root: for
# the subst target that fallback exists for, it answers the volume its
# accurate call would have, where GetPathRoot here answers a different one,
# so a folder at a mount point would be validated on the drive letter's
# figure rather than reported unknown.
param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

$ErrorActionPreference = 'Stop'

try {
    $full = (Resolve-Path -LiteralPath $Path).ProviderPath
    Add-Type -Namespace PortaNode -Name Disk -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool GetDiskFreeSpaceEx(string lpDirectoryName,
    out ulong lpFreeBytesAvailableToCaller,
    out ulong lpTotalNumberOfBytes,
    out ulong lpTotalNumberOfFreeBytes);
'@
    $available = [uint64]0
    $capacity = [uint64]0
    $free = [uint64]0
    if (-not [PortaNode.Disk]::GetDiskFreeSpaceEx($full, [ref]$available,
            [ref]$capacity, [ref]$free)) {
        exit 1
    }
    Write-Output ([int64][math]::Floor($available / 1GB))
} catch {
    exit 1
}
