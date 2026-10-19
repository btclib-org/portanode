# Prints OK where -Installed is "unknown", OLDER where -Requested is older,
# UNCOMPARABLE where either is not digits and dots, and OK otherwise; exits 0.
#
# update-bitcoin.bat and update-electrum.bat refuse to install a version unless
# this script prints OK or --allow-downgrade is passed, so a run that prints
# nothing refuses too. The rule, and why it exists, is refuse_downgrade's in
# shared/utilities/lib.sh. "unknown" is :installed_version's answer where
# nothing is recorded. The answer is on stdout because the caller reads it
# through a for /f: latest-bitcoin-version.ps1's header says why.
param(
    [string]$Installed = '',
    [string]$Requested = ''
)
$ErrorActionPreference = 'Stop'

if ($Installed -ceq 'unknown') {
    Write-Output 'OK'
    exit 0
}
$pattern = '^[0-9]+(\.[0-9]+)*$'
if ($Installed -notmatch $pattern -or $Requested -notmatch $pattern) {
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
