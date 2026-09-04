# Prints the newest Bitcoin Core version on bitcoincore.org that actually ships
# a win64 archive, then exits 0.
#
# Two failures, told apart on stdout: the release index could not be read, where
# the word INDEX_UNREACHABLE is printed, and the index was read but names no
# release with a win64 archive, where nothing is printed. Both exit 1.
# update-bitcoin.bat reads this script through a for /f, which leaves errorlevel
# at whatever it held before the loop rather than at the exit code of the
# command inside it -- measured on windows-latest -- so stdout is the channel
# that reaches the caller; a version is digits and dots, so the word is not one.
#
# The release index can list version directories that are empty (a release not
# yet published) or that lack a Windows build, so we probe newest-first and skip
# any candidate whose win64 zip is missing. Legacy 0.x releases are excluded so
# the version sort picks a modern release.
$ErrorActionPreference = 'Stop'

# -TimeoutSec 300: the bound update-bitcoin.sh puts on this same index fetch,
# sized against the 135 s bitcoincore.org was measured answering it in (ISS
# 354), and its comment carries the reasoning. The candidate probe below keeps
# -TimeoutSec 30, that script's own bound on the same probe.
try {
    $index = (Invoke-WebRequest -Uri 'https://bitcoincore.org/bin/' `
        -UseBasicParsing -TimeoutSec 300).Content
} catch {
    Write-Output 'INDEX_UNREACHABLE'
    exit 1
}

$versions = [regex]::Matches($index, 'bitcoin-core-(\d+\.\d+(?:\.\d+)?)/') |
    ForEach-Object { $_.Groups[1].Value } |
    Where-Object { $_ -notmatch '^0\.' } |
    Sort-Object -Unique -Descending -Property { [version]$_ }

foreach ($v in $versions) {
    $url = "https://bitcoincore.org/bin/bitcoin-core-$v/bitcoin-$v-win64.zip"
    try {
        Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing `
            -TimeoutSec 30 | Out-Null
        Write-Output $v
        exit 0
    } catch {
        continue
    }
}

exit 1
