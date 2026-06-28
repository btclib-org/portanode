# Prints the newest Bitcoin Core version on bitcoincore.org that actually ships
# a win64 archive, then exits 0. Exits 1 (no output) if none can be determined.
#
# The release index can list version directories that are empty (a release not
# yet published) or that lack a Windows build, so we probe newest-first and skip
# any candidate whose win64 zip is missing. Legacy 0.x releases are excluded so
# the version sort picks a modern release.
$ErrorActionPreference = 'Stop'

try {
    $index = (Invoke-WebRequest -Uri 'https://bitcoincore.org/bin/' `
        -UseBasicParsing -TimeoutSec 30).Content
} catch {
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
