# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# Fetches one URL for the Windows updaters over HTTPS only, the request and every
# redirect, as curl_https does in shared/utilities/lib.sh. A failed request
# throws. With -OutFile, an absolute path, the body goes to that file and nothing is
# printed; without it the response is printed. Run it from its own directory:
# win/scripts/root.ps1 says why.
#
# Windows PowerShell 5.1 follows a redirect from HTTPS to plain HTTP (ISS 695),
# so this script follows them itself. Checking the final URL would come too late:
# the plain request has gone out by then, and one that redirects back to HTTPS
# ends on a URL that looks right.
#
# Measured on windows-latest against a local HTTPS listener. Under 5.1,
# -MaximumRedirection 0 returns any 3xx as a response, adding
# MaximumRedirectExceeded for a 301 or a 302 as a non-terminating error that
# -ErrorAction SilentlyContinue quiets, and a 404 and a timeout still throw. pwsh
# throws on every 3xx instead, so there a redirect fails unless -OutFile is given;
# the updaters run under powershell. save-response.ps1 says why -OutFile goes there.
param(
    [Parameter(Mandatory = $true)]
    [string]$Uri,
    [string]$OutFile,
    [string]$Method = 'Get',
    [int]$TimeoutSec = 0
)

$options = @{
    Method             = $Method
    TimeoutSec         = $TimeoutSec
    UseBasicParsing    = $true
    MaximumRedirection = 0
    ErrorAction        = 'SilentlyContinue'
}
$target = [uri]::new($Uri, [UriKind]::Absolute)
for ($hop = 0; $hop -le 5; $hop++) {
    if ($target.Scheme -ne 'https') {
        throw "Refused to fetch $target`: not HTTPS."
    }
    if ($OutFile) {
        $response = & .\save-response.ps1 -Uri $target.AbsoluteUri -OutFile $OutFile -TimeoutSec $TimeoutSec
        if ($null -eq $response) {
            exit 0
        }
    } else {
        $response = Invoke-WebRequest -Uri $target.AbsoluteUri @options
        # -ErrorAction SilentlyContinue must not turn a failure into a success.
        if ($null -eq $response) {
            throw "No response from $target."
        }
        if ([int]$response.StatusCode -lt 300) {
            $response
            exit 0
        }
    }
    $location = [string]$response.Headers['Location']
    if (-not $location) {
        throw "Status $($response.StatusCode) from $target, with no Location."
    }
    $target = [uri]::new($target, $location)
}
throw "Too many redirects, ending at $target."
