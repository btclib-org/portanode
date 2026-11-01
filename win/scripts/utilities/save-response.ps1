# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# One GET for fetch-https.ps1, which checks the URL: it follows no redirect. Under
# 300 the body goes to -OutFile, an absolute path, and nothing is printed. Any other
# status below 400 prints an object with StatusCode and Headers['Location'], and the
# file is not written. A failed request throws a MethodInvocationException, the
# WebException its InnerException.
# -TimeoutSec bounds the wait for the response and not a stalled body, measured on
# windows-latest under both PowerShells; no updater passes it with -OutFile.
#
# Invoke-WebRequest cannot do this under Windows PowerShell 5.1, measured on
# windows-latest: at -MaximumRedirection 0 with -OutFile it reports only a 301 or a
# 302, and saves the body of a 303, 307 or 308 as the file; -PassThru shows the
# status, but holds the whole body in memory.
param(
    [Parameter(Mandatory = $true)]
    [string]$Uri,
    [Parameter(Mandatory = $true)]
    [string]$OutFile,
    [int]$TimeoutSec = 0
)

# A .NET exception otherwise stops only its statement, and the caller reads no
# output as success. $ErrorActionPreference = 'Stop' stops this script and not its
# caller, measured under pwsh. A throw stops both.
try {
    $request = [Net.HttpWebRequest][Net.WebRequest]::Create($Uri)
    $request.AllowAutoRedirect = $false
    $request.UserAgent = 'portanode'
    # 0 is no bound, as it is for Invoke-WebRequest. HttpWebRequest's own default is 100 s.
    $request.Timeout = if ($TimeoutSec -gt 0) { $TimeoutSec * 1000 } else { [Threading.Timeout]::Infinite }
    $response = $request.GetResponse()
    try {
        if ([int]$response.StatusCode -ge 300) {
            return [pscustomobject]@{
                StatusCode = [int]$response.StatusCode
                Headers    = @{ Location = $response.Headers['Location'] }
            }
        }
        $body = $response.GetResponseStream()
        $file = [IO.File]::Create($OutFile)
        try {
            $body.CopyTo($file)
        } finally {
            $file.Dispose()
        }
    } finally {
        $response.Close()
    }
} catch {
    throw
}
