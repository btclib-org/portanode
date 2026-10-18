# Prints OLDER where -Requested is older than -Installed, UNCOMPARABLE where
# either is not digits and dots, and OK otherwise; exits 0.
#
# update-bitcoin.bat and update-electrum.bat refuse to install a version unless
# this script prints OK or --allow-downgrade is passed, so a run that prints
# nothing refuses too. The rule, and why it exists, is refuse_downgrade's in
# shared/utilities/lib.sh. An -Installed of "unknown", :installed_version's
# answer where nothing is recorded, prints OK. The answer is on stdout because
# the caller reads it through a for /f: latest-bitcoin-version.ps1's header
# says why.
param(
    [string]$Installed = '',
    [string]$Requested = ''
)
$ErrorActionPreference = 'Stop'

if ($Installed -eq 'unknown') {
    Write-Output 'OK'
    exit 0
}
$pattern = '^[0-9]+(\.[0-9]+)*$'
if ($Installed -notmatch $pattern -or $Requested -notmatch $pattern) {
    Write-Output 'UNCOMPARABLE'
    exit 0
}

# Component by component, a missing one read as 0, the way refuse_downgrade
# reads them: [version] refuses a single component and more than four.
$a = $Installed.Split('.')
$b = $Requested.Split('.')
$n = [Math]::Max($a.Count, $b.Count)
for ($i = 0; $i -lt $n; $i++) {
    $x = if ($i -lt $a.Count) { [decimal]$a[$i] } else { [decimal]0 }
    $y = if ($i -lt $b.Count) { [decimal]$b[$i] } else { [decimal]0 }
    if ($y -gt $x) {
        break
    }
    if ($y -lt $x) {
        Write-Output 'OLDER'
        exit 0
    }
}
Write-Output 'OK'
exit 0
