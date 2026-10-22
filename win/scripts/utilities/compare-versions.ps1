# Prints MALFORMED where -Requested is not digits and dots, whatever else is
# passed; then OK where -Allow is 1 or -Installed is "unknown", OLDER where
# -Requested is older, UNCOMPARABLE where -Installed is not digits and dots,
# and OK otherwise; exits 0. A requested version is built into a URL and a
# file name, so only digits and dots are let through.
#
# update-bitcoin.bat and update-electrum.bat refuse to install a version unless
# this script prints OK or --allow-downgrade is passed, so a run that prints
# nothing refuses too. The rule, and why it exists, is refuse_downgrade's in
# shared/utilities/lib.sh. "unknown" is :installed_version's answer where
# nothing is recorded. The answer is on stdout because the caller reads it
# through a for /f: latest-bitcoin-version.ps1's header says why.
param(
    [string]$Installed = '',
    [string]$Requested = '',
    [string]$Allow = ''
)
$ErrorActionPreference = 'Stop'

# \z rather than $, which also matches before a final newline.
$pattern = '^[0-9]+(\.[0-9]+)*\z'
if ($Requested -notmatch $pattern) {
    Write-Output 'MALFORMED'
    exit 0
}
if ($Allow -ceq '1' -or $Installed -ceq 'unknown') {
    Write-Output 'OK'
    exit 0
}
if ($Installed -notmatch $pattern) {
    Write-Output 'UNCOMPARABLE'
    exit 0
}

# Component by component, a missing one read as 0, the way refuse_downgrade
# reads them: [version] refuses a single component and more than four. Each
# is compared as a string, leading zeros stripped, the longer being the
# larger, so no component is too large to compare.
$a = $Installed.Split('.')
$b = $Requested.Split('.')
$n = [Math]::Max($a.Count, $b.Count)
for ($i = 0; $i -lt $n; $i++) {
    $x = if ($i -lt $a.Count) { $a[$i].TrimStart('0') } else { '' }
    $y = if ($i -lt $b.Count) { $b[$i].TrimStart('0') } else { '' }
    $c = if ($y.Length -ne $x.Length) { $y.Length - $x.Length } else { [string]::CompareOrdinal($y, $x) }
    if ($c -gt 0) {
        break
    }
    if ($c -lt 0) {
        Write-Output 'OLDER'
        exit 0
    }
}
Write-Output 'OK'
exit 0
