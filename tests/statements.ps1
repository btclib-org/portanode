# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# Run by the Windows job of coverage.yml. It copies the checkout, and in the
# copy inserts before each statement of each .ps1 outside tests/ a call that
# writes where that statement is to a log of the process running it. It runs
# the copy's tests/run.ps1, then prints the share of those statements the
# suite ran, in total and per file, and lists each .bat as unmeasured. It
# exits as the suite does, and 1 where the suite passed and the share is
# under the floor it is given, a percentage:
#
#   pwsh -NoProfile -File tests\statements.ps1 -Floor <floor>
#
# A log per process, because the launchers run the .ps1 files as processes
# of their own, which a profiler in this one does not see: Pester's covers
# its own process only.

param([Parameter(Mandatory = $true)][double]$Floor)

$ErrorActionPreference = 'Stop'
if (-not $env:RUNNER_TEMP) {
  Write-Output 'tests\statements.ps1 runs in the Windows job of coverage.yml only.'
  exit 1
}

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$tree = Join-Path $env:RUNNER_TEMP 'statements-tree'
$hits = Join-Path $env:RUNNER_TEMP 'statements-hits'
Copy-Item -LiteralPath $repo -Destination $tree -Recurse -Force
New-Item -ItemType Directory -Path $hits | Out-Null

# Each statement is named by its file and the line and column it starts at.
$statements = [ordered]@{}
$files = @(git -C $repo ls-files '*.ps1' | Where-Object { $_ -notlike 'tests/*' })
foreach ($rel in $files) {
  $path = Join-Path $tree $rel
  $bytes = [IO.File]::ReadAllBytes($path)
  $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
  $text = [IO.File]::ReadAllText($path)
  $tokens = $null
  $errors = $null
  $ast = [Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$errors)
  if ($errors.Count) { throw "$rel does not parse: $($errors[0].Message)" }
  $blocks = $ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.NamedBlockAst] -or
      $node -is [Management.Automation.Language.StatementBlockAst]
    }, $true)
  $inserts = foreach ($block in $blocks) {
    foreach ($statement in $block.Statements) {
      $id = "${rel}:$($statement.Extent.StartLineNumber):$($statement.Extent.StartColumnNumber)"
      $statements[$id] = $rel
      [pscustomobject]@{
        Offset = $statement.Extent.StartOffset
        Text   = "try{[IO.File]::AppendAllText('$hits/'+`$PID+'.log','$id'+[char]10)}catch{};"
      }
    }
  }
  # From the end, so that each offset still holds when it is used.
  foreach ($insert in ($inserts | Sort-Object Offset -Descending)) {
    $text = $text.Insert($insert.Offset, $insert.Text)
  }
  [Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count) { throw "$rel does not parse once logged: $($errors[0].Message)" }
  [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($bom))
}

$exe = (Get-Process -Id $PID).Path
& $exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tree 'tests\run.ps1')
$status = $LASTEXITCODE

$ran = @{}
foreach ($log in Get-ChildItem -LiteralPath $hits -Filter '*.log') {
  foreach ($line in [IO.File]::ReadAllLines($log.FullName)) { $ran[$line] = $true }
}

$inv = [Globalization.CultureInfo]::InvariantCulture
$covered = @($statements.Keys | Where-Object { $ran.ContainsKey($_) }).Count
$total = $statements.Count
# Cut at two decimals rather than rounded, so that it never reads above the
# share: tests/README.md raises a floor to the whole percent at or under it.
$rem = [long]0
$cut = [Math]::DivRem([long](10000 * $covered), [long]$total, [ref]$rem)
Write-Output ([string]::Format($inv, '{0}.{1:00}% of {2} statements', ($cut - $cut % 100) / 100, $cut % 100, $total))
foreach ($rel in ($files | Sort-Object)) {
  $ids = @($statements.Keys | Where-Object { $statements[$_] -eq $rel })
  $hit = @($ids | Where-Object { $ran.ContainsKey($_) }).Count
  $share = if ($ids.Count) { 100 * $hit / $ids.Count } else { 100 }
  Write-Output ([string]::Format($inv, '{0,7:0.00}% {1,5} {2}', $share, $ids.Count, $rel))
}
# No tool counts the statements of a .bat (btclib-org/portanode#784).
foreach ($rel in (git -C $repo ls-files '*.bat' | Sort-Object)) {
  Write-Output ('unmeasured       {0}' -f $rel)
}

if ($status -ne 0) { exit $status }
if (100 * $covered -lt $Floor * $total) {
  Write-Output ([string]::Format($inv, 'under the floor of {0}%', $Floor))
  exit 1
}
Write-Output ([string]::Format($inv, 'at or over the floor of {0}%', $Floor))
exit 0
