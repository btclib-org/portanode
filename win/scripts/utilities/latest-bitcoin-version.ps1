# Prints the newest Bitcoin Core version on bitcoincore.org that actually ships
# a win64 archive, then exits 0.
#
# Three failures, told apart on stdout: the release index could not be read,
# where the word INDEX_UNREACHABLE is printed; the -TimeoutSec 30 archive HEAD
# probe expired on at least one candidate and no candidate's archive was found
# either way, where the word PROBE_TIMEOUT is printed; and the index was read,
# every candidate's probe answered, and none names a win64 archive, where
# nothing is printed. All three exit 1.
# update-bitcoin.bat reads this script through a for /f, which leaves errorlevel
# at whatever it held before the loop rather than at the exit code of the
# command inside it -- measured on windows-latest -- so stdout is the channel
# that reaches the caller; a version is digits and dots, so neither word is one.
#
# The release index can list version directories that are empty (a release not
# yet published) or that lack a Windows build, so we probe newest-first and skip
# any candidate whose win64 zip is missing. Legacy 0.x releases are excluded so
# the version sort picks a modern release.
$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1 takes its protocols from ServicePointManager. At 0,
# SystemDefault, the operating system chooses, offering TLS 1.2 or later on
# Windows 10 and 11, and an explicit value would drop what it offers. Any other
# value gets TLS 1.2 ORed in and keeps what it held. PowerShell 7's HttpClient
# does not read this setting.
if ([int][Net.ServicePointManager]::SecurityProtocol -ne 0) {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

# Run by a relative name from its own directory: win/scripts/root.ps1 says why.
Set-Location -LiteralPath $PSScriptRoot -ErrorAction Stop

# -TimeoutSec 300: the bound update-bitcoin.sh puts on this same index fetch,
# sized against the 135 s bitcoincore.org was measured answering it in (ISS
# 354), and its comment carries the reasoning. The candidate probe below keeps
# -TimeoutSec 30, that script's own bound on the same probe.
try {
    $index = (& .\fetch-https.ps1 -Uri 'https://bitcoincore.org/bin/' -TimeoutSec 300).Content
} catch {
    Write-Output 'INDEX_UNREACHABLE'
    exit 1
}

# [0-9] and not \d, which .NET also reads as a digit of any script, and the
# directory name closed by a slash and a quote, as update-bitcoin.sh reads it.
$versions = [regex]::Matches($index, 'href="bitcoin-core-([0-9]+\.[0-9]+(?:\.[0-9]+)?)/"') |
    ForEach-Object { $_.Groups[1].Value } |
    Where-Object { $_ -notmatch '^0\.' } |
    Sort-Object -Unique -Descending -Property { [version]$_ }

# A candidate's probe is told a timeout from a genuine 404 by its exception's
# own shape: Windows PowerShell 5.1 -- the interpreter update-bitcoin.bat
# actually invokes -- throws System.Net.WebException with a Status of
# Timeout, where PowerShell 7's HttpClient-backed Invoke-WebRequest throws
# System.Threading.Tasks.TaskCanceledException instead; a 404 throws neither
# on either runtime. Measured on windows-latest against a listener that
# sleeps past -TimeoutSec 2 and one that answers 404 immediately, for both
# powershell.exe and pwsh.exe.
# A redirect fetch-https.ps1 refuses throws neither, so it reads as a 404.
$sawTimeout = $false
foreach ($v in $versions) {
    $url = "https://bitcoincore.org/bin/bitcoin-core-$v/bitcoin-$v-win64.zip"
    try {
        & .\fetch-https.ps1 -Uri $url -Method Head -TimeoutSec 30 | Out-Null
        Write-Output $v
        exit 0
    } catch {
        if (($_.Exception -is [System.Net.WebException] -and
             $_.Exception.Status -eq [System.Net.WebExceptionStatus]::Timeout) -or
            $_.Exception -is [System.Threading.Tasks.TaskCanceledException]) {
            $sawTimeout = $true
        }
        continue
    }
}

if ($sawTimeout) {
    Write-Output 'PROBE_TIMEOUT'
}
exit 1
