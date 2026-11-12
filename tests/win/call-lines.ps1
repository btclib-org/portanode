# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# Every call of a file or a label in the .bat files writes its variables as
# %%NAME%%, as win\scripts\root.bat says at its head. The check reads a line as
# a call where "call" starts it or follows white space, "(", "&", "|" or "@",
# and is followed by white space or ":", with the lines a trailing "^" continues
# it onto. Past the word, it reads the line left to right, one token at a time,
# trying at each "%" in this order: "%%"; a parameter, %1, %*, or %~ with
# letters, an optional $NAME: (NAME being any characters but "%" and ":") and a
# digit; then %NAME%, NAME being any characters but "%", which covers
# %NAME:...%. A "%~" without the shape of a parameter can start a %NAME%. It
# also reads !NAME!, NAME being any characters but "!". It refuses a line
# holding %NAME% or !NAME!, quoted or not, whether or not NAME is defined. It
# skips a line whose first word starts with "::" or is "rem" or "@rem" followed
# by white space or the line's end, unless a trailing "^" continues a call onto
# it; it reads "@ rem" and "rem." as any other line. It skips a "call set",
# which builds a value rather than reaching a file or a label. launchers.ps1 and
# regtest-cli-command.ps1 beside this file run the launchers from a folder whose
# path holds a "^".

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try { . .\lib.ps1 } finally { Pop-Location }

$call = '(?i)(^|[\s(&|@])call(?>\s+|(?=:))(?!set\s)'
$ref = '%%|%~[A-Za-z]*(?:\$[^%:]+:)?[0-9]|%[0-9*]|(%[^%]+%)|(![^!]+!)'
$script:calls = 0

# Returns "<line>: <text>" for each line of $Path whose call holds a reference
# the check refuses.
function Find-EarlyExpansion {
  param([string]$Path)
  $n = 0
  $cont = $false
  foreach ($line in Get-Content -LiteralPath $Path) {
    $n++
    $m = [regex]::Match($line, $call)
    if ($cont) {
      $rest = $line
    } elseif ($line -match '^\s*(@?(?i:rem)(\s|$)|::)') {
      continue
    } elseif ($m.Success) {
      $script:calls++
      $rest = $line.Substring($m.Index + $m.Length)
    } else {
      continue
    }
    $refused = @([regex]::Matches($rest, $ref) |
        Where-Object { $_.Groups[1].Success -or $_.Groups[2].Success })
    if ($refused.Count) { "${n}: $($line.Trim())" }
    $cont = $line.EndsWith('^')
  }
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('portanode-tests-' + [guid]::NewGuid())
$tmp = (New-Item -ItemType Directory -Path $tmp).FullName
try {
  $control = Join-Path $tmp 'control.bat'
  Set-Content -LiteralPath $control -Encoding Ascii -Value @(
    'call "%SCRIPT_DIR%lib.bat" :label ^',
    '  "%ROOTDIR%\x"',
    'REM call "%SCRIPT_DIR%lib.bat"',
    'if errorlevel 1 call :label "%%ROOTDIR%%" %~nx0',
    'for %%E in (a b) do call "%%SCRIPT_DIR%%lib.bat" "%%E"',
    'echo "%ROOTDIR%"',
    '@call "%SCRIPT_DIR%lib.bat"',
    'call %LIB% :label',
    'call :label "!ROOTDIR!"',
    'call :label "%ROOTDIR:~0,-1%"',
    'call set "RR_PATH=%%RR_PATH:~%RR_LEN%%%"',
    'call:x "%ROOTDIR%"',
    'call "%SCRIPT_DIR%%NAME%.bat"',
    'call :l "%%X%%%Y%"',
    'call  set "X=%Y%"',
    'call :l "%ROOTDIR%%1"',
    'call "%SCRIPT_DIR%%~1.bat"',
    'call :l "%%A%B%%"',
    'call :l "%X%%~nx0"',
    'call :l %X%%*',
    'call :l "%B%%"',
    'call :l "%X%%%%Y%%%%"',
    'call :l %~dp$PATH:1 %* "%%%%"',
    'call "%ProgramFiles(x86)%\x\lib.bat"',
    'call :log "50% done %%X%%"',
    'call :l "a% b%%ROOTDIR%%"',
    'call :l "%A-B%%ROOTDIR%"',
    'call :l "!A-B!"',
    'call :l %~$MY_PATH:1 "%%X%%"',
    'call :l %~dp$Path_Ext:1 "%%X%%"',
    'call :l ^',
    'rem "%ROOTDIR%"',
    'call :l "%%X%%" ^',
    ':: "%ROOTDIR%"',
    '@rem call "%X%"',
    '@ rem call "%X%"',
    'rem. call "%X%"',
    'rem/ call "%X%"',
    'rem: call "%X%"')
  Test-Same 'control: the check names each early expansion in a call' `
    ("1: call `"%SCRIPT_DIR%lib.bat`" :label ^`n2: `"%ROOTDIR%\x`"`n" +
      "7: @call `"%SCRIPT_DIR%lib.bat`"`n8: call %LIB% :label`n" +
      "9: call :label `"!ROOTDIR!`"`n10: call :label `"%ROOTDIR:~0,-1%`"`n" +
      "12: call:x `"%ROOTDIR%`"`n13: call `"%SCRIPT_DIR%%NAME%.bat`"`n" +
      "14: call :l `"%%X%%%Y%`"`n16: call :l `"%ROOTDIR%%1`"`n" +
      "17: call `"%SCRIPT_DIR%%~1.bat`"`n18: call :l `"%%A%B%%`"`n" +
      "19: call :l `"%X%%~nx0`"`n20: call :l %X%%*`n21: call :l `"%B%%`"`n" +
      "22: call :l `"%X%%%%Y%%%%`"`n" +
      "24: call `"%ProgramFiles(x86)%\x\lib.bat`"`n" +
      "25: call :log `"50% done %%X%%`"`n26: call :l `"a% b%%ROOTDIR%%`"`n" +
      "27: call :l `"%A-B%%ROOTDIR%`"`n28: call :l `"!A-B!`"`n" +
      "32: rem `"%ROOTDIR%`"`n34: :: `"%ROOTDIR%`"`n" +
      "36: @ rem call `"%X%`"`n37: rem. call `"%X%`"`n38: rem/ call `"%X%`"`n" +
      "39: rem: call `"%X%`"") `
    ((Find-EarlyExpansion $control) -join "`n")
  $script:calls = 0

  $files = @(Get-ChildItem -LiteralPath $repo -Recurse -File -Filter '*.bat' |
      Sort-Object FullName)
  foreach ($file in $files) {
    $rel = $file.FullName.Substring($repo.Length + 1)
    Test-Same "no call in $rel holds a reference the check refuses" `
      '' ((Find-EarlyExpansion $file.FullName) -join "`n")
  }
  Test-Same 'the .bat files hold calls of a file or a label' 'True' "$($script:calls -gt 0)"
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

Complete-Test
