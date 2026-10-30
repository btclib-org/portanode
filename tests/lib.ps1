# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# Assertions for the test files under tests/win/. tests/README.md says how a
# test file uses them.

$script:TestsFailed = 0

# Reports one case, passed where $Passed is true. $Detail is printed under a
# failed case.
function Write-TestResult {
  param([string]$Name, [bool]$Passed, [string[]]$Detail = @())
  if ($Passed) {
    Write-Output "ok - $Name"
  } else {
    Write-Output "not ok - $Name"
    foreach ($line in $Detail) { Write-Output "  $line" }
    $script:TestsFailed++
  }
}

# Passes where $Actual equals $Expected, case included.
function Test-Same {
  param([string]$Name, [string]$Expected, [string]$Actual)
  Write-TestResult -Name $Name -Passed ($Expected -ceq $Actual) -Detail @(
    "expected: $Expected", "actual:   $Actual")
}

# Passes where $Part occurs in $Text, case included.
function Test-Contain {
  param([string]$Name, [string]$Text, [string]$Part)
  Write-TestResult -Name $Name -Passed ($Text.Contains($Part)) -Detail @(
    "wanted:   $Part", "in:       $Text")
}

# Exits 0 where every case passed, 1 otherwise.
function Complete-Test {
  if ($script:TestsFailed -gt 0) { exit 1 }
  exit 0
}
