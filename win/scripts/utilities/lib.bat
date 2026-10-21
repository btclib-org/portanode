@echo off
REM Shared helpers for Windows utility scripts.

set "ACTION=%~1"
if "%ACTION%"=="" goto :eof
shift
goto %ACTION%

REM :warn_if_no_pubkeys
REM Reports on the local keyring and never fails the caller: both
REM --dry-run, the side-effect-free preview, and :verify_pgp_signature
REM call it, and neither wants that question answered by an error.
REM Measured on windows-latest (#382), against the keyring directory
REM gpg creates on its own first run: a for /f over gpg piped into
REM findstr does not return, where the same listing redirected to a
REM file returns in about a second. The wait is the pipe rather than
REM gpg, so the listing goes to a file and nothing here reads a
REM running command's output.
REM The bound is Start-Process with WaitForExit, at the value the
REM archive-size request in the same --dry-run block passes as
REM -TimeoutSec 30, rather than a second number to defend. It covers
REM a gpg slow for its own reasons, which is not the case measured
REM above.
REM gpg runs under a hidden cmd.exe, which redirects its output and
REM reads WNP_ANSWER_FILE from its own environment rather than having
REM the path spliced in. gpg can start keyboxd, which outlives this
REM script. Where Start-Process redirects gpg's output itself, keyboxd
REM holds the caller's output pipe, and a caller reading it never
REM returns (windows-latest run 39181636990); under the hidden window
REM it does not (run 39182563899). taskkill /t ends gpg along with
REM that cmd.exe.
REM An empty answer file is not a keyring holding no key, so the two
REM print different warnings and neither ends the run: --dry-run
REM reaches its free-space line and exits 0 either way (#327, #336).
REM That warning names the absence rather than a cause, as the
REM archive-size line in the same block does and for the same reason:
REM the bound firing, a gpg that is not on PATH and a probe that could
REM not run all reach it alike.
REM The powershell argument below is one physical line for the reason
REM :update_checksum's comment gives.
REM WNP_ANSWER_FILE is TEMP-derived, and TEMP is the caller's to set,
REM not this file's: an account name or a redirected TEMP holding an
REM unmatched "!" is legal on Windows. It is read with "%...%"
REM because every caller reaches this label with delayed expansion
REM disabled, which is what leaves the character standing: with it
REM on, the pass that would substitute a "!VAR!" strips an
REM unmatched "!" out of what "%TEMP%" expanded to (#393). A "!"
REM in the mount path is a separate source with a separate owner,
REM and it is stripped a second time out of the caller's own
REM "call" line, which is #411 and is measured at
REM update-bitcoin.bat's comment on its own second line. Neither
REM source implies the other: a plain mount path with a bangy TEMP
REM reaches this label with a working call target. The state at
REM each call is checked by a hook in .pre-commit-config.yaml (#448).
:warn_if_no_pubkeys
set "WNP_ANSWER_FILE=%TEMP%\pn_pubkeys_%RANDOM%%RANDOM%.txt"
type nul > "%WNP_ANSWER_FILE%"
powershell -NoProfile -Command "& { $out = $env:WNP_ANSWER_FILE + '.out'; $err = $env:WNP_ANSWER_FILE + '.err'; $q = [char]34; $p = Start-Process -FilePath 'cmd.exe' -ArgumentList ('/d /v:off /c gpg --batch --list-keys --with-colons > ' + $q + '%%WNP_ANSWER_FILE%%.out' + $q + ' 2> ' + $q + '%%WNP_ANSWER_FILE%%.err' + $q) -WindowStyle Hidden -PassThru; if ($p.WaitForExit(30000)) { $a = 'no'; if (Select-String -Path $out -Pattern '^pub' -Quiet) { $a = 'yes' }; Set-Content -Path $env:WNP_ANSWER_FILE -Value $a } else { taskkill.exe /pid $p.Id /t /f }; Remove-Item $out, $err -Force -ErrorAction SilentlyContinue }" >nul 2>&1
set "WNP_ANSWER="
set /p WNP_ANSWER=<"%WNP_ANSWER_FILE%"
del "%WNP_ANSWER_FILE%" >nul 2>&1
if "%WNP_ANSWER%"=="yes" exit /b 0
if "%WNP_ANSWER%"=="no" echo Warning: no public keys found in local keyring.
if "%WNP_ANSWER%"=="" (
    echo Warning: the local keyring was not read; whether a public key
    echo is imported is unknown.
)
exit /b 0

REM :verify_pgp_signature SIG DATA LABEL FPR_FILE
REM Fails CLOSED (exit /b 1) unless SIG carries good signatures from as many
REM distinct keys pinned in FPR_FILE as its min-signatures asks for, the
REM rule shared/utilities/lib.sh's pgp_verify_or_fail states. A file that
REM pins no key refuses.
REM Written flat (no %var% set-and-read inside a ( ) block) because a
REM read of that shape inside one answers with the value the variable
REM held when cmd.exe parsed the block. Delayed expansion is the other
REM way of fixing that, and lib.bat cannot turn it on for itself: the
REM local scoping it comes with would confine the variables its labels
REM set for their callers, :installed_version's OUTVAR among them.
REM Written flat, neither STATUS_FILE nor
REM the caller's own SIG_FILE and DATA_FILE needs it -- each is read
REM at a line that runs after the line setting it -- and the callers
REM reach this label with delayed expansion disabled, which is what
REM lets a "!" in TEMP or in the mount path survive as far as here
REM (#393, #411). The construct is named rather than spelled, because
REM spelled out it reads to the batch linter as this file asking for
REM what the paragraph forbids, and it then prints that advice against
REM exit points throughout the file.
:verify_pgp_signature
set "SIG_FILE=%~1"
set "DATA_FILE=%~2"
set "LABEL=%~3"
set "FPR_FILE=%~4"

where gpg >nul 2>&1
if not %errorlevel%==0 (
    echo Error: gpg not found; cannot verify %LABEL%.
    echo Install gpg and import the signing key.
    exit /b 1
)

call :warn_if_no_pubkeys
echo Verifying %LABEL% signature...
REM STATUS_FILE is TEMP-derived: see the comment above
REM :warn_if_no_pubkeys's own WNP_ANSWER_FILE on why that makes the
REM caller's delayed-expansion state the thing it depends on (#393,
REM #411). "%SIG_FILE%"/"%DATA_FILE%" are the caller's own paths rather
REM than this file's, and depend on it the same way.
set "STATUS_FILE=%TEMP%\pgp_status_%RANDOM%%RANDOM%.txt"
gpg --status-fd 1 --verify "%SIG_FILE%" "%DATA_FILE%" 1> "%STATUS_FILE%" 2>nul

REM A status file that is absent or empty is gpg's answer lost rather
REM than a signature refused, and the findstr below cannot separate
REM the two: measured on windows-latest, it exits 1 on a file that is
REM not there exactly as it does on one holding no GOODSIG.
REM The exit code of the line above separates them the wrong way
REM round, so it is not read at all: a redirection cmd.exe cannot open
REM leaves errorlevel 0, which is what a good signature leaves, where
REM a bad signature leaves 1 and a key not imported leaves 2.
REM The test is on size rather than existence, an empty file answering
REM no more than a missing one; no case measured here separates the
REM two.
REM What reaches this line is a %TEMP% under which cmd.exe cannot
REM create the file at all: one that is missing (windows-latest runs
REM 39182563899 and 39182668674 leave it missing after
REM :warn_if_no_pubkeys), a drive letter that is not mapped, a path
REM whose own directory component is a file.
REM An unset %TEMP%, whose path resolves to the
REM current drive's root, does not reach it, nor does one whose ACL
REM grants the account read and execute alone, an Administrators entry
REM beside it still granting a group the account is in full control.
REM The message names the absence rather than a cause, for the reason
REM :warn_if_no_pubkeys's comment gives of its own unknown branch.
set "STATUS_OK=0"
if exist "%STATUS_FILE%" for %%S in ("%STATUS_FILE%") do if %%~zS GTR 0 set "STATUS_OK=1"
if "%STATUS_OK%"=="0" (
    echo Error: gpg's status output for %LABEL% was not read; whether the
    echo signature is good is unknown.
    del "%STATUS_FILE%" >nul 2>&1
    exit /b 1
)

findstr /c:"[GNUPG:] BADSIG" "%STATUS_FILE%" >nul 2>&1
if %errorlevel%==0 (
    echo Error: BAD PGP signature on %LABEL%.
    del "%STATUS_FILE%" >nul 2>&1
    exit /b 1
)

REM gpg's own doc/DETAILS gives NEWSIG as issued right before a
REM signature verification starts, so a status file holding none is
REM gpg reporting that it never reached one.
REM The GOODSIG test below cannot separate that from a signature
REM gpg read and could not validate, and names the keyring for both.
REM DETAILS says under GOODSIG that the per-signature codes "were
REM used as a marker for a new signature; new code should use the
REM NEWSIG status instead", so the dependence is the one upstream
REM asks for; nothing in this tree states a minimum gpg, and the
REM oldest measured against it is 2.4.4.
REM gpg's own exit status does not separate them either: a key that
REM is not imported and a signature file that cannot be opened both
REM leave errorlevel 2. Nor does the FAILURE line, which reads
REM "verify" for a signature file that is missing or empty and
REM "gpg-exit" for one holding something that is not a signature and
REM for a file to check that is missing; a test on it would leave
REM those last two on the keyring message.
REM Measured with gpg 2.4.9 on windows-latest: NEWSIG is present for
REM a good signature, for a tampered one and for a key that is not
REM imported, and absent where the signature file is missing, empty
REM or not a signature and where the file it signs is missing. A file
REM the account is denied by ACL is not among them: icacls granting
REM the runner no access at all left gpg reading it, so an unreadable
REM file is measured on the POSIX half alone.
REM The message names what gpg did not do rather than a cause,
REM several reaching it alike, as :warn_if_no_pubkeys does of its own
REM unknown branch. A signature file that is present and readable and
REM merely not a signature is one of them -- the shape a download
REM answering 200 with an error page leaves -- so advice to check
REM presence and readability would send that reader to confirm two
REM things already true.
findstr /c:"[GNUPG:] NEWSIG" "%STATUS_FILE%" >nul 2>&1
if not %errorlevel%==0 (
    echo Error: gpg found no PGP signature to check on %LABEL%.
    echo Check the signature file and the file it signs.
    del "%STATUS_FILE%" >nul 2>&1
    exit /b 1
)

findstr /c:"[GNUPG:] GOODSIG" "%STATUS_FILE%" >nul 2>&1
if not %errorlevel%==0 (
    echo Error: no valid PGP signature on %LABEL% ^(is the signer's key imported?^).
    echo Import the signing key.
    del "%STATUS_FILE%" >nul 2>&1
    exit /b 1
)

REM Pinning: FPR_FILE is read by the PowerShell :load_pin_reader holds, by
REM shared/utilities/lib.sh's pinned_fingerprints rule, and the status file
REM counted by pgp_verify_or_fail's, each as that function's comment states.
REM A PowerShell that exits non-zero for any reason, including not
REM running at all, refuses. The catch makes an error that does not stop
REM the block one of those reasons: measured on windows-latest with
REM FPR_FILE naming a directory, the read threw and the block ran on.
REM The powershell argument below is one physical line for the reason
REM :update_checksum's comment gives.
call :load_pin_reader
powershell -NoProfile -Command "& { try { if ([string]::IsNullOrEmpty($env:FPR_FILE)) { Write-Output ('Error: no file of pinned fingerprints given, so ' + $env:LABEL + ' is refused.'); exit 1 }; $file = $env:FPR_FILE; %PIN_READER_PS%; if ($pins.Count -eq 0) { Write-Output ('Error: ' + $name + ' pins no key, so ' + $env:LABEL + ' is refused.'); Write-Output 'Add to it the fingerprints of the signers you trust.'; exit 1 }; if ($min.Length -gt 9 -or $pins.Count -lt [int]$min) { Write-Output ('Error: ' + $name + ' pins ' + $pins.Count + ' key(s), fewer than the ' + $min + ' signatures it asks for, so ' + $env:LABEL + ' is refused.'); exit 1 }; $sigs = New-Object System.Collections.ArrayList; foreach ($line in [IO.File]::ReadAllLines($env:STATUS_FILE)) { $w = $line.Split(' '); if ($w.Count -lt 2 -or $w[0] -cne '[GNUPG:]') { continue }; if ($w[1] -ceq 'NEWSIG') { [void]$sigs.Add(@{ goods = 0; valids = 0; revoked = $false; gid = ''; sfpr = ''; primary = '' }); continue }; if ($sigs.Count -eq 0) { continue }; $s = $sigs[$sigs.Count - 1]; if ($w[1] -ceq 'GOODSIG') { $s['goods'] += 1; $s['gid'] = $w[2].ToUpperInvariant() } elseif ($w[1] -ceq 'VALIDSIG') { $s['valids'] += 1; $s['sfpr'] = $w[2].ToUpperInvariant(); if ($w.Count -gt 11) { $s['primary'] = $w[11].ToUpperInvariant() } } elseif ($w[1] -ceq 'REVKEYSIG' -or $w[1] -ceq 'KEYREVOKED') { $s['revoked'] = $true } }; $counted = @{}; foreach ($s in $sigs) { if ($s['goods'] -eq 1 -and $s['valids'] -eq 1 -and -not $s['revoked'] -and $s['gid'].Length -ge 16 -and $s['sfpr'].EndsWith($s['gid'], [StringComparison]::Ordinal) -and $pins.ContainsKey($s['primary'])) { $counted[$s['primary']] = $true } }; if ($counted.Count -lt [int]$min) { Write-Output ('Error: ' + $env:LABEL + ' carries good signatures from ' + $counted.Count + ' key(s) pinned in ' + $name + '; it asks for ' + $min + '.'); Write-Output 'A key counts once, and not at all where it is expired or revoked.'; exit 1 }; Write-Output ($env:LABEL + ': good signatures from ' + $counted.Count + ' key(s) pinned in ' + $name + '; ' + $min + ' required.') } catch { Write-Output ('Error: ' + $_.Exception.Message); exit 1 }; exit 0 }"
if not %errorlevel%==0 (
    echo Error: %LABEL% is refused.
    del "%STATUS_FILE%" >nul 2>&1
    exit /b 1
)

del "%STATUS_FILE%" >nul 2>&1
exit /b 0

REM :load_pin_reader
REM Sets PIN_READER_PS to the PowerShell that reads a file of pinned
REM fingerprints, named by the $file variable the caller's block sets first,
REM and leaves $name (the file's own name), $pins (the pinned keys, upper
REM case, each once) and $min (the signatures asked for, 1 where the file
REM sets none). :verify_pgp_signature and :preview_pinned_keys both paste it
REM into their powershell argument, so that the preview reports the pins the
REM verification enforces. A file it does not accept prints the reason and
REM exits 1; a path that does not exist pins nothing.
REM The bytes are decoded as Latin-1, one character per byte, so no
REM decoder turns a byte PowerShell cannot read into one the rule accepts,
REM and -creplace and -cnotmatch name their characters rather than \s,
REM which matches U+00A0 as well.
REM A line is tested for emptiness by its Length and for # by an ordinal
REM StartsWith, because -eq '' and StartsWith's default compare by culture,
REM which ignores some characters: measured with the line
REM U+00AD followed by #, both Windows PowerShell 5.1 on windows-latest
REM and pwsh 7 read it as a comment and skipped it, and pwsh 7 also read
REM U+0001 alone as empty, where shared/utilities/lib.sh refuses both.
REM PowerShell applies the rule rather than findstr: measured on
REM windows-latest, findstr /i /r "^[0-9A-F][0-9A-F]*$" matched a
REM CRLF-ended fingerprint line and not the same line LF-ended, and
REM .gitattributes checks keys\*.fingerprints out LF-only.
REM The text holds no double quote and no percent sign, so pasted into the
REM caller's double-quoted -Command argument it stays one argument.
:load_pin_reader
set "PIN_READER_PS=$name = [IO.Path]::GetFileName($file); $pins = @{}; $min = '1'; $minSet = $false; if (Test-Path -LiteralPath $file) { $bytes = [IO.File]::ReadAllBytes($file); if ($bytes -contains 0) { Write-Output ('Error: ' + $name + ' holds a NUL byte, as a UTF-16 file does.'); exit 1 }; $text = [Text.Encoding]::GetEncoding(28591).GetString($bytes); if ($text.StartsWith([string][char]0xEF + [char]0xBB + [char]0xBF, [StringComparison]::Ordinal)) { $text = $text.Substring(3) }; $n = 0; foreach ($l in ($text -split '\r\n|\r|\n')) { $n++; $f = $l -creplace '[ \t\v\f]', ''; if ($f.Length -eq 0 -or $f.StartsWith('#', [StringComparison]::Ordinal)) { continue }; if ($f.StartsWith('min-signatures=', [StringComparison]::Ordinal)) { if ($minSet) { Write-Output ('Error: line ' + $n + ' of ' + $name + ' sets min-signatures a second time.'); exit 1 }; $min = $f.Substring(15); $minSet = $true; if ($min -cnotmatch '^[1-9][0-9]*$') { Write-Output ('Error: line ' + $n + ' of ' + $name + ' does not set min-signatures to a whole number from 1: ' + $f); exit 1 }; continue }; if ($f -cnotmatch '^[0-9A-Fa-f]{40}$') { Write-Output ('Error: line ' + $n + ' of ' + $name + ' is not a 40-hex fingerprint: ' + $f); exit 1 }; $pins[$f.ToUpperInvariant()] = $true } }"
exit /b 0

REM :preview_pinned_keys FPR_FILE NAME WHAT
REM For an updater's --dry-run, with gpg found: prints what
REM :verify_pgp_signature would make of FPR_FILE. It reads the file with the
REM PowerShell :load_pin_reader holds, and reports the cases that routine
REM refuses: a file it does not accept, a file that pins no key, and a file
REM that pins fewer keys than its min-signatures asks for. Otherwise it
REM prints the pinned keys and the signatures asked for. NAME is the file as
REM the user knows it and WHAT is what a refusal would stop. Always exits 0:
REM a preview reports and does not end the run. The powershell argument is
REM one physical line for the reason :update_checksum's comment gives.
REM The values reach PowerShell through the environment, for the reason
REM :install_verified's comment gives.
:preview_pinned_keys
set "PPK_FILE=%~1"
set "PPK_NAME=%~2"
set "PPK_WHAT=%~3"
call :load_pin_reader
powershell -NoProfile -Command "& { try { $file = $env:PPK_FILE; %PIN_READER_PS%; if ($pins.Count -eq 0) { Write-Output ('gpg: found, but ' + $env:PPK_NAME + ' pins no key -- verification would refuse ' + $env:PPK_WHAT + '.'); exit 0 }; if ($min.Length -gt 9 -or $pins.Count -lt [int]$min) { Write-Output ('gpg: found, but ' + $env:PPK_NAME + ' pins ' + $pins.Count + ' key(s), fewer than the ' + $min + ' signatures it asks for -- verification would refuse ' + $env:PPK_WHAT + '.'); exit 0 }; foreach ($p in ($pins.Keys | Sort-Object)) { Write-Output ('Pinned key ' + $p + ' in ' + $env:PPK_NAME + '.') }; Write-Output ('Verification asks for ' + $min + ' good signature(s) from distinct pinned keys.') } catch { Write-Output ('Error: ' + $_.Exception.Message); exit 1 }; exit 0 }"
if not %errorlevel%==0 (
    echo gpg: found, but %PPK_NAME% was not accepted as a list of pinned
    echo fingerprints -- verification would refuse %PPK_WHAT%.
)
exit /b 0

REM :update_checksum FILE ENTRY_PATH VERSION
REM Appends FILE's hash to CHECKSUM_FILE under ENTRY_PATH. The updaters
REM pass the verified file they install from, not the copy under
REM win\bin, and then check that copy against the entry: an entry hashed
REM from the copy records whatever the write left there, and the check
REM then compares the copy with itself (#568). Every value reaches
REM PowerShell through the environment, for the reason
REM :install_verified's comment gives.
:update_checksum
set "FILEPATH_RAW=%~1"
set "ENTRY_RAW=%~2"
set "VERSION_LABEL=%~3"
call :normalize_fs_path "%FILEPATH_RAW%" FILEPATH_FS
call :normalize_entry_path "%ENTRY_RAW%" FILEPATH_ENTRY
if not exist "%FILEPATH_FS%" exit /b 0
if "%CHECKSUM_FILE%"=="" exit /b 0
REM Appends the one new entry with Add-Content rather than rewriting the file
REM with Set-Content, matching what README.md documents this file as:
REM append-only. A rewrite of every line on each call -- and Select-Object
REM -Unique silently dropping any repeated one, comments included -- is what
REM Add-Content avoids.
REM Measured on windows-latest (#144): a "^" at end of line continues a
REM batch file's line only while cmd's quote state is closed at that point;
REM inside the double-quoted -Command argument below, "^" is a literal
REM character rather than a continuation, which is why that argument is
REM one physical line. $entry is built
REM with single-quoted concatenation rather than a double-quoted
REM interpolated string: measured on windows-latest, a double quote nested
REM inside the one that already wraps this whole -Command argument is not
REM passed through to powershell.exe -- it is consumed while the argument
REM is split into argv, along with the space either side of it, turning
REM "$hash  ...  $version" into three bare, unquoted tokens and a parse
REM error. Every other quoted PowerShell string in this file is already
REM single-quoted for the same reason.
REM "-not" rather than PowerShell's own negation operator, which is
REM the character cmd.exe's delayed-expansion pass consumes:
REM "!(Test-Path $checksum)" would reach PowerShell as
REM "(Test-Path $checksum)", the test inverted, wherever delayed
REM expansion is on (#360). "-not" carries nothing for cmd.exe's
REM parser to strip under either state, so this line holds whichever
REM one a caller leaves (#374, #411).
REM Get-FileHash's own failure is non-terminating, returning nothing so
REM ".Hash" on that empty result is $null and it is ".ToLower()" -- a
REM method call on that $null -- that throws "You cannot call a method
REM on a null-valued expression": that is the unreadable-file arm. The
REM cmdlet itself failing to resolve (Windows PowerShell 5.1 failing to
REM autoload Microsoft.PowerShell.Utility, #420) raises instead, at
REM command resolution, before ".Hash" is ever reached. Neither throw
REM aborts more than the one assignment, so without a guard $hash stays
REM unset either way, coerces to an empty string in $entry, and
REM Add-Content still appends an entry whose hash field is empty into
REM the append-only checksums.sha256. $fh is checked before ".Hash" is
REM read, so either failure leaves it unset and exits 1 with nothing
REM appended. :verify_checksum and :installed_version below test the
REM same way.
powershell -NoProfile -Command "& { $file = $env:FILEPATH_FS; $version = $env:VERSION_LABEL; $checksum = $env:CHECKSUM_FILE; if (-not (Test-Path -LiteralPath $checksum)) { Write-Host 'Warning: win/checksums.sha256 not found; skipping.'; exit 0 } $fh = Get-FileHash -Algorithm SHA256 -LiteralPath $file; if (-not $fh) { Write-Host ('Error: could not hash the source of ' + $env:FILEPATH_ENTRY + '; not appending to win/checksums.sha256.'); exit 1 } $hash = $fh.Hash.ToLower(); $entry = $hash + '  ' + $env:FILEPATH_ENTRY + '  version=' + $version; $existing = Get-Content -LiteralPath $checksum; if ($existing -notcontains $entry) { Add-Content -Encoding ASCII -LiteralPath $checksum -Value $entry } }"
if errorlevel 1 exit /b 1
exit /b 0

:verify_checksum
set "FILEPATH_RAW=%~1"
set "CHECKPATH_RAW=%~2"
call :normalize_fs_path "%FILEPATH_RAW%" FILEPATH_FS
call :normalize_entry_path "%CHECKPATH_RAW%" CHECKPATH_ENTRY
REM A relative FILE is taken against ROOTDIR, not against the current
REM directory, which the updaters keep outside the folder (#656).
if not "%FILEPATH_FS:~1,1%"==":" if not "%FILEPATH_FS:~0,1%"=="\" set "FILEPATH_FS=%ROOTDIR%\%FILEPATH_FS%"
REM Fails CLOSED on a missing file, converging on
REM shared/utilities/lib.sh's verify_checksum_entry, which returns
REM non-zero on the same case.
if exist "%FILEPATH_FS%" goto :verify_checksum_found
call :rootdir_relative "%FILEPATH_FS%" FILEPATH_REL
echo Error: %FILEPATH_REL% not found.
exit /b 1
:verify_checksum_found
if "%CHECKSUM_FILE%"=="" exit /b 1
call :rootdir_relative "%FILEPATH_FS%" FILEPATH_REL
REM Built as one physical line: see :update_checksum's comment above on
REM why a "^" split across this block's open quote is not a continuation.
REM "-not" rather than "!" for the reason :update_checksum's comment
REM above gives. Values reach PowerShell as $env: reads, for the reason
REM :install_verified's comment below gives.
REM A file Get-FileHash cannot read is refused by name, as
REM :update_checksum refuses it (#652). A line matches where its first
REM field is the hash and its second the entry path, each compared whole,
REM as shared/utilities/lib.sh's verify_checksum_entry compares them: a
REM substring test reads a line as naming any path its own text holds
REM (#657). The path is compared without regard to case, as Windows
REM resolves one. '\s+' carries one backslash, for the reason
REM latest-electrum-version.ps1's header gives.
powershell -NoProfile -Command "& { $path = $env:CHECKPATH_ENTRY; $checksum = $env:CHECKSUM_FILE; if (-not (Test-Path -LiteralPath $checksum)) { exit 1 } $fh = Get-FileHash -Algorithm SHA256 -LiteralPath $env:FILEPATH_FS; if (-not $fh) { Write-Host ('Error: could not hash ' + $env:FILEPATH_REL + '.'); exit 1 } $found = $false; foreach ($l in (Get-Content -LiteralPath $checksum)) { $w = $l.Trim() -split '\s+'; if ($w.Count -ge 2 -and $w[0] -ieq $fh.Hash -and $w[1].Replace('\','/') -ieq $path) { $found = $true; break } } if (-not $found) { exit 1 } }"
if errorlevel 1 exit /b 1
exit /b 0

REM :install_verified SRC DEST
REM Copies SRC over DEST, reads DEST back and compares its SHA-256 with
REM SRC's, copying again on a mismatch and failing once every attempt
REM has mismatched: shared/utilities/lib.sh's install_verified, for the
REM same removable volume. A DEST that cannot be hashed counts as a
REM mismatch. A copy that fails outright is reported and not retried,
REM being an error the copy itself raises rather than a silent one.
REM One physical line, for the reason :update_checksum's comment gives.
REM The paths reach PowerShell through the environment, as
REM :warn_if_no_pubkeys's WNP_ANSWER_FILE does, rather than spliced
REM between single quotes in the command text: a path holding an
REM apostrophe ends such a string early, and PowerShell then refuses the
REM whole command as a parse error (#578). Where a cmdlet takes
REM -LiteralPath the path goes there, so a "[" in it is not read as a
REM wildcard. The other calls that hand PowerShell a value this way
REM point here.
:install_verified
set "INS_SRC=%~1"
set "INS_DEST=%~2"
powershell -NoProfile -Command "& { $src = $env:INS_SRC; $dest = $env:INS_DEST; $name = Split-Path -Leaf $dest; $want = Get-FileHash -Algorithm SHA256 -LiteralPath $src; if (-not $want) { Write-Host ('Error: cannot hash the source of ' + $name + '.'); exit 1 } foreach ($i in 1..5) { try { Copy-Item -LiteralPath $src -Destination $dest -Force -ErrorAction Stop } catch { Write-Host ('Error: copying ' + $name + ' failed: ' + $_.Exception.Message); exit 1 } $got = Get-FileHash -Algorithm SHA256 -LiteralPath $dest -ErrorAction SilentlyContinue; if ($got -and $got.Hash -eq $want.Hash) { exit 0 } Write-Host ('Warning: ' + $name + ' corrupted on write (attempt ' + $i + '/5); retrying...') } Write-Host ('Error: ' + $name + ' still corrupt after 5 attempts.'); Write-Host 'The destination filesystem may be unreliable.'; exit 1 }"
if errorlevel 1 exit /b 1
exit /b 0

REM :installed_version FILE ENTRY_PATH CHECKSUM_FILE OUTVAR
REM Sets OUTVAR to the "version=" label of the checksum entry matching
REM FILE's current hash, or "unknown". It never fails the caller. Its
REM answer is a --dry-run plan's "currently installed" line, a
REM rollback's version lines, and what compare-versions.ps1 compares
REM before an update: "unknown" there
REM means nothing is refused.
:installed_version
set "IV_FILE_RAW=%~1"
set "IV_ENTRY_RAW=%~2"
set "IV_CHECKSUM=%~3"
set "IV_OUTVAR=%~4"
call :normalize_fs_path "%IV_FILE_RAW%" IV_FILE_FS
call :normalize_entry_path "%IV_ENTRY_RAW%" IV_ENTRY_ENTRY
set "%IV_OUTVAR%=unknown"
if not exist "%IV_FILE_FS%" exit /b 0
if not exist "%IV_CHECKSUM%" exit /b 0
REM Built as one physical line: see :update_checksum's comment above on
REM why a "^" split across this block's open quote is not a continuation.
REM Values reach PowerShell as $env: reads, for the reason
REM :install_verified's comment above gives. The entry is matched as
REM :verify_checksum matches it, its '\s+' included, and a file
REM Get-FileHash cannot read leaves OUTVAR "unknown".
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "& { $fh = Get-FileHash -Algorithm SHA256 -LiteralPath $env:IV_FILE_FS -ErrorAction SilentlyContinue; if (-not $fh) { exit 0 } foreach ($l in (Get-Content -LiteralPath $env:IV_CHECKSUM)) { $w = $l.Trim() -split '\s+'; if ($w.Count -ge 2 -and $w[0] -ieq $fh.Hash -and $w[1].Replace('\','/') -ieq $env:IV_ENTRY_ENTRY) { if ($l -match 'version=(\S+)') { Write-Output $matches[1] } break } } }"`) do set "%IV_OUTVAR%=%%V"
exit /b 0

REM :rootdir_relative PATH OUTVAR
REM PATH with the ROOTDIR prefix removed, for a message: the folder is
REM mounted at a different point on every machine it is plugged into, so a
REM message quoting the mount point tells the reader where this run
REM happened rather than which file in the folder is meant. A path outside
REM the folder carries no such prefix and comes back unchanged. ROOTDIR is
REM stripped only from paths inside the folder.
REM "call set" is what expands ROOTDIR inside the pattern: cmd reads the
REM percent signs of "%PATH:%ROOTDIR%\=%" as three pairs and substitutes
REM nothing, where the second parse a "call" adds sees one pair around an
REM already-expanded ROOTDIR. The guard is for an unset ROOTDIR, which
REM would leave the pattern a bare backslash and strip every separator in
REM the path.
:rootdir_relative
set "RR_PATH=%~1"
set "RR_OUTVAR=%~2"
if defined ROOTDIR call set "RR_PATH=%%RR_PATH:%ROOTDIR%\=%%"
set "%RR_OUTVAR%=%RR_PATH%"
exit /b 0

:normalize_fs_path
set "RAW=%~1"
set "OUTVAR=%~2"
set "VAL=%RAW:/=\%"
set "%OUTVAR%=%VAL%"
exit /b 0

:normalize_entry_path
set "RAW=%~1"
set "OUTVAR=%~2"
set "VAL=%RAW:\=/%"
set "%OUTVAR%=%VAL%"
exit /b 0
