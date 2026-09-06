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
#
# The volume asked for is the one GetVolumePathName finds, not the one
# [System.IO.Path]::GetPathRoot names: GetPathRoot reads the path string and
# hands back the drive letter's own root, so a data directory that is itself
# a volume mount point is answered for by whatever volume the drive letter
# carries. Measured on windows-latest against an exFAT VHD mounted with
# mountvol at a directory on an NTFS one, GetPathRoot's root answers NTFS
# where GetVolumePathName's mount point answers exFAT, and set-permissions.bat
# reports that directory restricted to the account and exits 0 on the first,
# against the volume's own warning and the 2 it earns on the second. Its
# readback does not catch what the name gets wrong there: icacls reads the
# granted ACE off the mount point, where a file inside the same directory
# answers "No permissions are set. All users have full control." Only that
# direction is reachable -- an NTFS volume at a directory on the exFAT one is
# refused with "Incorrect function." and exit 1, mountvol's own usage naming
# an NTFS directory as where a mount point resides.
#
# GetPathRoot is asked second rather than not at all, because there are paths
# GetVolumePathName leads away from a volume that can be named. A drive letter
# made by subst is one, measured on windows-latest with subst S: C:\shr:
# GetVolumePathName("S:\sub") answers "S:\sub\", the subst target reading as a
# mount point, and GetVolumeInformation refuses that with error 144, where
# GetPathRoot's "S:\" reads NTFS -- which is the answer a folder run from such
# a letter has.
#
# 144 is ERROR_DIRECTORY_NOT_ROOT, the answer for a path that is not a volume
# root, and it is that code the second root is conditioned on rather than the
# first call having failed at all. A genuine mount point can fail for a
# reason that leaves the drive letter's volume the wrong answer: measured on
# the same runner against a VHD partitioned and left unformatted, mounted at
# a directory on C:, GetVolumePathName answers the mount point and
# GetVolumeInformation refuses it with 1005, ERROR_UNRECOGNIZED_VOLUME, where
# GetPathRoot's "C:\" reads NTFS. Conditioned on the failure alone that NTFS
# is what such a directory is named at exit 0, which is the answer this file
# exists to avoid; conditioned on 144 it is named nothing and exits 1. Only
# the subst target answered 144, measured across an ordinary directory, a
# drive root, an exFAT volume mounted at a directory and a directory inside
# it, the unformatted mount point, a subst letter's root and a path under it,
# a UNC share root and a path under it, and a mapped drive letter and a path
# under it.
#
# Where GetVolumePathName itself fails the second root is still tried, which
# is a case rather than an oversight: measured on the same runner, the subst
# letter's own root "S:\" answers false with error 87 there, and GetPathRoot's
# "S:\" is what names NTFS for it. So a mount point whose path does not fit
# the buffer is still answered by its drive letter, which is what the buffer
# below is sized against.
#
# GetVolumeInformation rather than System.IO.DriveInfo for the name, because
# handing DriveInfo the mount point GetVolumePathName returns changes nothing:
# DriveInfo answers for the drive letter of whatever path it is given, and for
# nothing else. Measured on windows-latest against the exFAT volume mounted at
# Y:\root\bitcoin-datadir, DriveInfo of that path reads Name "Y:\" and
# DriveFormat NTFS, and the volume's own GUID path throws "Object must be a
# root directory ("C:\") or a drive letter ("C")." Where DriveInfo can be asked
# at all the two answer one string: measured against VHDs formatted NTFS,
# exFAT, FAT32 and ReFS, DriveInfo.DriveFormat and this call agree on each, so
# which volume is asked is what changes here and not what a volume is called.
# A UNC path is where DriveInfo cannot be asked and this call can, so a folder
# on a share is named here where it was reported unknown.
#
# Get-Volume -FilePath reaches the same volume in one line and needs no
# compile, and is not used: measured on windows-latest it takes several times
# as long as the pair below, once per data directory. What the pair costs in
# its place is Add-Type's need for a writable %TEMP% to compile in, and on the
# filesystem this folder is meant for that cost is not offset. Measured with
# %TEMP% on an unmapped drive letter, against data directories on an exFAT
# volume: set-permissions.bat answers exFAT and prints the volume's own
# warning at exit 2 where it runs GetPathRoot, and reports the filesystem as
# undetermined at exit 1 where it runs this. An exFAT directory never reaches
# that script's own ACL readback -- its exFAT arm exits ahead of the line
# naming the readback's !TEMP! file -- so there is no second %TEMP% failure
# underneath to make the two alike. Warning to warning and non-zero to
# non-zero, so a run under that %TEMP% never claims a restriction it lacks.
#
# The buffer is MAX_PATH + 1, and what it has to hold is the mount point
# rather than -Path. Measured on windows-latest: an input of 362 characters
# under Y:\ answers Y:\ with a buffer of 4, and against the mount point
# Y:\root\bitcoin-datadir\ a buffer of 4 returns false with GetLastError 206
# while a buffer of 24, one short, returns true with the trailing separator
# gone. So a mount point deeper than this buffer is what would want it raised,
# and a long -Path is not; either way GetPathRoot is what answers below.
param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

$ErrorActionPreference = 'Stop'

try {
    $full = (Resolve-Path -LiteralPath $Path).ProviderPath
    Add-Type -Namespace PortaNode -Name Volume -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool GetVolumePathName(string lpszFileName,
    System.Text.StringBuilder lpszVolumePathName, uint cchBufferLength);

[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool GetVolumeInformation(string lpRootPathName,
    System.Text.StringBuilder lpVolumeNameBuffer, uint nVolumeNameSize,
    out uint lpVolumeSerialNumber, out uint lpMaximumComponentLength,
    out uint lpFileSystemFlags,
    System.Text.StringBuilder lpFileSystemNameBuffer,
    uint nFileSystemNameSize);
'@
    $size = 261
    $name = New-Object -TypeName System.Text.StringBuilder -ArgumentList $size
    $serial = 0
    $components = 0
    $flags = 0
    $mount = New-Object -TypeName System.Text.StringBuilder -ArgumentList $size
    if ([PortaNode.Volume]::GetVolumePathName($full, $mount, $size)) {
        $m = $mount.ToString()
        $ok = [PortaNode.Volume]::GetVolumeInformation($m, $null, 0,
            [ref]$serial, [ref]$components, [ref]$flags, $name, $size)
        # Marshal::GetLastWin32Error reads a value the runtime caches at each
        # P/Invoke declared SetLastError, so nothing goes between it and the
        # call above. Measured under pwsh against a failing libc open, the
        # runtime being what caches this rather than the platform: read on the
        # next line it answers that call's own error, and with a Test-Path
        # between the two -- a statement that makes a P/Invoke without looking
        # like one -- it answers 0.
        $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        if ($ok) {
            Write-Output $name.ToString()
            exit 0
        }
        if ($err -ne 144) {
            exit 1
        }
    }
    $root = [System.IO.Path]::GetPathRoot($full)
    if ([PortaNode.Volume]::GetVolumeInformation($root, $null, 0,
            [ref]$serial, [ref]$components, [ref]$flags, $name, $size)) {
        Write-Output $name.ToString()
        exit 0
    }
    exit 1
} catch {
    exit 1
}
