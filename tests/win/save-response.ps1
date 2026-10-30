# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# save-response.ps1 against a loopback server, plain HTTP because the script leaves
# the scheme to fetch-https.ps1: it runs without administrator rights and on any
# system with pwsh. The server answers what a request's path says.

Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

$script = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\win\scripts\utilities\save-response.ps1')).Path
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-save-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName
$log = Join-Path $tmp 'requests'
$exe = (Get-Process -Id $PID).Path

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$base = "http://127.0.0.1:$($listener.LocalEndpoint.Port)"
$server = [powershell]::Create()
$null = $server.AddScript({
    param($Listener, $Log)
    while ($true) {
      $client = $Listener.AcceptTcpClient()
      $stream = $client.GetStream()
      $reader = [IO.StreamReader]::new($stream)
      $first = $reader.ReadLine()
      while ($reader.ReadLine()) { }
      $path = ($first -split ' ')[1]
      [IO.File]::AppendAllText($Log, "$path`n")
      if ($path -eq '/slow') { Start-Sleep -Seconds 4 }
      $body = 'the body'
      $head = 'HTTP/1.1 200 OK'
      if ($path -match '^/s(\d+)$') {
        $head = "HTTP/1.1 $($Matches[1]) X"
        if ([int]$Matches[1] -lt 400) { $head += "`r`nLocation: https://example.invalid/next" }
        $body = 'not the body'
      }
      $text = "$head`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n$body"
      $bytes = [Text.Encoding]::ASCII.GetBytes($text)
      $stream.Write($bytes, 0, $bytes.Length)
      $stream.Flush()
      $client.Close()
    }
  }).AddArgument($listener).AddArgument($log)
$null = $server.BeginInvoke()

$out = Join-Path $tmp 'out'
$printed = @(& $script -Uri "$base/final" -OutFile $out)
Test-Same 'a 200 prints nothing' 0 $printed.Count
Test-Same 'a 200 writes the body' 'the body' (Get-Content -Raw -LiteralPath $out)
Remove-Item -LiteralPath $out

foreach ($code in 300, 301, 302, 303, 304, 305, 307, 308) {
  [IO.File]::WriteAllText($log, '')
  $answer = & $script -Uri "$base/s$code" -OutFile $out
  Test-Same "a $code prints its status" $code $answer.StatusCode
  Test-Same "a $code prints its Location" 'https://example.invalid/next' $answer.Headers['Location']
  Test-Same "a $code writes no file" $false (Test-Path -LiteralPath $out)
  Test-Same "a $code is not followed" "/s$code" (Get-Content -Raw -LiteralPath $log).Trim()
}

$threw = try { & $script -Uri "$base/s404" -OutFile $out; 'no' } catch { 'threw' }
Test-Same 'a 404 throws' 'threw' $threw
Test-Same 'a 404 writes no file' $false (Test-Path -LiteralPath $out)

$status = try { & $script -Uri "$base/slow" -OutFile $out -TimeoutSec 1; 'no' } catch { [string]$_.Exception.InnerException.Status }
Test-Same 'a timeout throws, with Status Timeout' 'Timeout' $status
Test-Same 'a timeout writes no file' $false (Test-Path -LiteralPath $out)

# A failure with no try around the call: the caller stops, and its exit code says so.
# The marker is built, because an error message quotes the command it came from.
function Invoke-NoTry {
  param([string]$Command)
  $text = @(& $exe -NoProfile -Command $Command 2>&1) -join ' '
  $status = $LASTEXITCODE
  if ($text.Contains('AFTER')) { 'went on' } else { "exit $status" }
}
$quoted = $script.Replace("'", "''")
$quotedOut = $out.Replace("'", "''")
Test-Same 'with no try, a 404 stops the caller' 'exit 1' `
  (Invoke-NoTry "& '$quoted' -Uri '$base/s404' -OutFile '$quotedOut'; 'AF' + 'TER'")
Test-Same 'with no try, a 404 writes no file' $false (Test-Path -LiteralPath $out)
$closed = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$closed.Start()
$closedPort = $closed.LocalEndpoint.Port
$closed.Stop()
$quotedDir = (Split-Path -Parent $script).Replace("'", "''")
Test-Same 'with no try, a failure stops fetch-https.ps1 and its caller' 'exit 1' `
  (Invoke-NoTry "Set-Location -LiteralPath '$quotedDir'; & .\fetch-https.ps1 -Uri 'https://127.0.0.1:$closedPort/x' -OutFile '$quotedOut'; 'AF' + 'TER'")
Test-Same 'with no try, that failure writes no file' $false (Test-Path -LiteralPath $out)

# In this order: Stop waits for the server, which waits in AcceptTcpClient until the
# listener stops.
$listener.Stop()
$server.Stop()
$server.Dispose()
Remove-Item -LiteralPath $tmp -Recurse -Force
Complete-Test
