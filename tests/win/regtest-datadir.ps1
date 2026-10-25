# The regtest launchers for Bob and Carol, under a root where their data
# directory cannot be created: each stops with an error before it starts
# a node. A file named bitcoin-datadir stands where the folder goes, and
# the binaries are empty files, which only the launchers' existence checks
# read.

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

# :pause_if_own_console in win\scripts\root.bat waits 30 seconds in a
# console opened for the script, and returns at once where this is set.
$env:PORTANODE_LAUNCHER = '1'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName

try {
  New-Item -ItemType Directory -Path (Join-Path $tmp 'win\bin') | Out-Null
  foreach ($name in 'VERSION', 'bitcoin-datadir', 'win\bin\bitcoind.exe',
    'win\bin\bitcoin-cli.exe', 'win\bin\bitcoin-qt.exe') {
    New-Item -ItemType File -Path (Join-Path $tmp $name) | Out-Null
  }
  $env:PORTANODE_ROOT = $tmp

  foreach ($node in 'regtest-18555-Bob', 'regtest-18666-Carol') {
    $dir = 'bitcoin-datadir\regtest_' + $node.Split('-')[2].ToLower()
    foreach ($kind in 'cli', 'cli-clean', 'qt', 'qt-clean') {
      $bat = "$node-$kind.bat"
      Push-Location -LiteralPath $repo
      try {
        # The line answers the clean variants' pause.
        $out = @('') | & cmd.exe /d /c ('.\win\scripts\bitcoin\' + $bat) 2>&1
        $status = $LASTEXITCODE
      } finally {
        Pop-Location
      }
      Test-Contain "$bat names the data directory it could not create" `
        ($out | Out-String) "Error: could not create `"$dir`"."
      Test-Same "$bat exits 1" '1' "$status"
    }
  }
} finally {
  Remove-Item Env:PORTANODE_ROOT -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
