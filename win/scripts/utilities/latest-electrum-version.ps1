# Prints the newest version listed on download.electrum.org, then exits 0.
#
# Two failures, told apart on stdout the way latest-bitcoin-version.ps1's own
# header describes: the release index could not be read, where the word
# INDEX_UNREACHABLE is printed, and the index was read but lists no version,
# where nothing is printed. Both exit 1.
#
# A -File script rather than a regex inlined into powershell -Command: an
# inline command line is split by the Windows argument rules before
# PowerShell parses it, and a backslash there is literal unless it
# precedes a double quote, so a pattern written inline has to be escaped
# for one reader and not the other. Nothing re-reads this file, so the
# regex below is the regex the engine gets.
#
# The index lists one directory per release, so the version is captured
# from the href and sorted as a [version] -- an ordinary string sort puts
# 4.5.8 after 4.10.0.
$ErrorActionPreference = 'Stop'

# -TimeoutSec 300: the bound latest-bitcoin-version.ps1 explains, and the one
# update-electrum.sh puts on this same index fetch. download.electrum.org has
# not been measured slow; the bound is applied here too rather than left below
# the figure the other publisher this tree fetches from answered in.
try {
    $index = (Invoke-WebRequest -Uri 'https://download.electrum.org/' `
        -UseBasicParsing -TimeoutSec 300).Content
} catch {
    Write-Output 'INDEX_UNREACHABLE'
    exit 1
}

$version = [regex]::Matches($index, 'href="(\d+\.\d+\.\d+)/"') |
    ForEach-Object { $_.Groups[1].Value } |
    Sort-Object -Unique -Descending -Property { [version]$_ } |
    Select-Object -First 1

if (-not $version) {
    exit 1
}

Write-Output $version
exit 0
