# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# Reads Bitcoin Core's network switches and data directory out of a Windows
# command line.
# lib.bat beside this file dot-sources it, and tests/win/node-args.ps1
# tests it.
#
# A switch counts only as a whole argument, so a path holding "-regtest" is
# not the switch. Bitcoin Core picks its network this way
# (src/common/args.cpp, src/common/settings.cpp and src/util/chaintype.cpp in
# bitcoin/bitcoin): on Windows "-name", "--name" and "/name" alike, the name in
# any case, and no switch after a lone "-". A boolean switch is true bare, with
# an empty value, or with a value whose leading integer is not zero:
# "-regtest=2" is true, "-regtest=0" and "-regtest=abc" are false. "-noregtest"
# is false, and "-noregtest=0" is true.
# A switch given more than once takes its last value, and so does "-chain".
# "-chain=<name>" selects a network by name, testnet3's being "test", and Core
# refuses to start on an unknown name or on more than one network.
#
# Get-NodeNetwork also reads the network from the configuration files, as
# Core does (src/common/config.cpp in bitcoin/bitcoin). It reads them as they
# are now, not as they were when the node started.
#
# Not read: a data directory a configuration file sets; a "chain" in the
# section of the network selected, which Core refuses on a later read as a
# second network: Test-NodeOnDatadir counts such a node where the rest
# selects $Chain, as regtest=1 with "chain=main" under [regtest] does, and
# not where it selects another, as testnet=1 with "chain=regtest" under
# [test] does, while Core runs neither; and an argument Core refuses as
# unknown, which stops it before it runs.

function Split-CommandLine {
  # The arguments of a command line, the program first, as Bitcoin Core on
  # Windows receives them: the argv its main() takes (MAIN_FUNCTION in
  # src/compat/compat.h of bitcoin/bitcoin), as Microsoft's C runtime splits
  # the line (Microsoft Learn, "Parsing C command-line arguments"). A space
  # or a tab outside double quotes separates arguments and the quotes are
  # dropped, so -datadir="D:\a b" is one argument. 2n backslashes before a
  # quote read as n and a quote that opens or closes a quoted run, 2n+1 as n
  # and a literal quote, and a backslash before anything else as itself. ""
  # inside a quoted run reads as a literal quote and stays inside the run.
  # The program's name ends at a space outside quotes. A line that ends
  # inside quotes ends its last argument.
  param([string]$CommandLine)
  $line = $CommandLine
  $i = 0
  $word = New-Object System.Text.StringBuilder
  $quoted = $false
  while ($i -lt $line.Length -and ($quoted -or $line[$i] -notmatch '[ \t]')) {
    if ($line[$i] -eq '"') { $quoted = -not $quoted } else { [void]$word.Append($line[$i]) }
    $i++
  }
  $word.ToString()
  while ($true) {
    while ($i -lt $line.Length -and $line[$i] -match '[ \t]') { $i++ }
    if ($i -ge $line.Length) { break }
    $word = New-Object System.Text.StringBuilder
    # 1 inside a quoted run, 0 outside it.
    $quoted = 0
    $escaped = $false
    while ($i -lt $line.Length -and ($quoted -eq 1 -or $line[$i] -notmatch '[ \t]')) {
      if ($line[$i] -eq '\') {
        $run = 0
        while ($i -lt $line.Length -and $line[$i] -eq '\') { $run++; $i++ }
        if ($i -lt $line.Length -and $line[$i] -eq '"') {
          [void]$word.Append([char]'\', ($run - $run % 2) / 2)
          $escaped = ($run % 2 -eq 1)
        } else {
          [void]$word.Append([char]'\', $run)
        }
      } elseif ($line[$i] -eq '"') {
        if ($escaped) {
          [void]$word.Append([char]'"')
        } elseif ($quoted -eq 1 -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '"') {
          [void]$word.Append([char]'"')
          $i++
        } else {
          $quoted = 1 - $quoted
        }
        $i++
        $escaped = $false
      } else {
        [void]$word.Append($line[$i])
        $i++
      }
    }
    $word.ToString()
  }
}

function Test-ValueReadsFalse {
  # True where Core reads a boolean switch's value as false: a value that is
  # not empty and whose leading integer, after white space and one sign, is
  # zero or absent. The white space is Core's alone: space, tab, vertical tab,
  # form feed, line feed and carriage return (TrimStringView in
  # src/util/string.h).
  param([string]$Value)
  if ($Value.Length -eq 0) { return $false }
  $v = $Value.Trim([char[]](32, 12, 10, 13, 9, 11))
  if ($v -match '^[+-]') { $v = $v.Substring(1) }
  return $v -match '^0*($|[^0-9])'
}

function Get-NodeSwitch {
  # The switches of a node's command line in order, as Core reads them: each
  # a Name, lower case and without its dashes, and a Value, null where none
  # is given. Core reads no switch after a lone "-".
  param([string]$CommandLine)
  foreach ($word in @(Split-CommandLine $CommandLine | Select-Object -Skip 1)) {
    if ($word -ceq '-') { break }
    if ($word -notmatch '^[-/]') { continue }
    $word = $word.Substring(1)
    if ($word.StartsWith('-')) { $word = $word.Substring(1) }
    $eq = $word.IndexOf('=')
    if ($eq -lt 0) {
      [pscustomobject]@{ Name = $word.ToLowerInvariant(); Value = $null }
    } else {
      [pscustomobject]@{ Name = $word.Substring(0, $eq).ToLowerInvariant(); Value = $word.Substring($eq + 1) }
    }
  }
}

function Get-SettingValue {
  # The values Core keeps for the setting $Name, in order, from $Setting: the
  # switches Get-NodeSwitch returns, or the entries Read-NodeConf returns. A
  # value is the string given, '' where none is; $false for a negation, as
  # "-noregtest"; $true for a double one, as "-noregtest=0".
  param([object[]]$Setting, [string]$Name)
  foreach ($s in $Setting) {
    if ([string]::Equals($s.Name, $Name, [StringComparison]::Ordinal)) {
      if ($null -eq $s.Value) { '' } else { "$($s.Value)" }
    } elseif ([string]::Equals($s.Name, "no$Name", [StringComparison]::Ordinal)) {
      $null -ne $s.Value -and (Test-ValueReadsFalse $s.Value)
    }
  }
}

function Test-SettingTrue {
  # True where Core reads the value Get-SettingValue returns as true.
  param($Value)
  if ($Value -is [bool]) { return $Value }
  return -not (Test-ValueReadsFalse $Value)
}

function Get-ChainSetting {
  # The network Core selects from the switches $Switch and the entries $Conf,
  # by the name "-chain" takes (GetChainArg in src/common/args.cpp): "main"
  # where no network is selected. Null where more than one is. An unknown
  # "-chain" name is returned as given.
  #
  # Only the entries above a file's first section count. A network switch
  # takes its last value on the command line, unless that value is a
  # negation, which Core skips; then its last value in the files. "-chain"
  # takes its last value on the command line, else its first value in the
  # files after their last negation of it.
  param([object[]]$Switch, [object[]]$Conf)
  $top = @($Conf | Where-Object { $_.Section.Length -eq 0 })
  $selected = @(foreach ($name in 'regtest', 'signet', 'testnet', 'testnet4') {
      $v = @(Get-SettingValue $Switch $name)
      if ($v.Count -eq 0 -or ($v[-1] -is [bool] -and -not $v[-1])) { $v = @(Get-SettingValue $top $name) }
      if ($v.Count -gt 0 -and (Test-SettingTrue $v[-1])) { $name }
    })
  $chain = $null
  $v = @(Get-SettingValue $Switch 'chain')
  if ($v.Count -gt 0) {
    $chain = $v[-1]
  } else {
    $v = @(Get-SettingValue $top 'chain')
    $first = 0
    for ($i = 0; $i -lt $v.Count; $i++) { if ($v[$i] -is [bool] -and -not $v[$i]) { $first = $i + 1 } }
    if ($first -lt $v.Count) { $chain = $v[$first] } elseif ($v.Count -gt 0) { $chain = $false }
  }
  # Core reads a negated -chain as "0" and a double one as "1", neither of
  # them a network.
  if ($chain -is [bool]) { $chain = if ($chain) { '1' } else { '0' } }
  if ($selected.Count + [int]($null -ne $chain) -gt 1) { return $null }
  if ($null -ne $chain) { return $chain }
  if ($selected.Count -eq 0) { return 'main' }
  if ($selected[0] -eq 'testnet') { return 'test' }
  return $selected[0]
}

function Get-NodeChain {
  # The network a node's command line selects, as Get-ChainSetting names it.
  param([string]$CommandLine)
  return Get-ChainSetting @(Get-NodeSwitch $CommandLine) @()
}

function Read-NodeConf {
  # The entries of the configuration file $Path, in order, as Core reads them
  # (GetConfigOptions in src/common/config.cpp): each a Section, '' above the
  # file's first section, a Name and a Value. A line ends at "#", and white
  # space is space, tab, carriage return and line feed. "[name]" starts a
  # section, and a name holding "." names its own, as "regtest.port". It
  # throws on a line Core does not parse: one that starts with "-", holds no
  # "=" and is no section, or sets rpcpassword and holds a "#". It throws on
  # a file holding a NUL byte too, which shared/lib.sh cannot read as Core
  # does, so that the two guards answer alike on such a file. Where the file
  # does not exist, it returns nothing if $Optional, and throws otherwise.
  param([string]$Path, [switch]$Optional)
  try {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
  } catch [System.IO.FileNotFoundException], [System.IO.DirectoryNotFoundException] {
    if ($Optional) { return }
    throw
  }
  if ([Array]::IndexOf($bytes, [byte]0) -ge 0) { throw "cannot read '$Path', which holds a NUL byte" }
  $space = [char[]](32, 9, 13, 10)
  $prefix = ''
  foreach ($line in [System.Text.Encoding]::UTF8.GetString($bytes).Split([char]10)) {
    $hash = $line.IndexOf([char]'#')
    if ($hash -ge 0) { $line = $line.Substring(0, $hash) }
    $line = $line.Trim($space)
    if ($line.Length -eq 0) { continue }
    if ($line[0] -ceq [char]'[' -and $line[-1] -ceq [char]']') {
      $prefix = $line.Substring(1, $line.Length - 2) + '.'
      continue
    }
    $eq = $line.IndexOf([char]'=')
    $key = $prefix + $line.Substring(0, [Math]::Max($eq, 0)).Trim($space)
    # The line may hold a secret, so the message does not quote it.
    if ($line[0] -ceq [char]'-' -or $eq -lt 0 -or ($hash -ge 0 -and $key.Contains('rpcpassword'))) {
      throw "cannot parse a line of '$Path'"
    }
    $dot = $key.IndexOf([char]'.')
    [pscustomobject]@{
      Section = if ($dot -ge 0) { $key.Substring(0, $dot) } else { '' }
      Name = $key.Substring($dot + 1)
      Value = $line.Substring($eq + 1).Trim($space)
    }
  }
}

function Join-ConfPath {
  # The file a configuration path names, a relative one under $Datadir, as
  # Core joins it to its data directory. On Windows it throws on a path that
  # is rooted and not absolute, as "\x" or "C:x".
  param([string]$Path, [string]$Datadir)
  if (-not [System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::Combine($Datadir, $Path) }
  if ($env:OS -eq 'Windows_NT' -and $Path -notmatch '^([A-Za-z]:[\\/]|[\\/][\\/])') {
    throw "cannot place the configuration file '$Path'"
  }
  return $Path
}

function Get-NodeNetwork {
  # The network a node selects, as Get-ChainSetting names it, from its
  # command line and its configuration files, read as Core reads them for a
  # node on $Datadir (ReadConfigFiles in src/common/config.cpp).
  #
  # The file is "-conf", or bitcoin.conf where it is absent or empty, and a
  # relative one is under $Datadir; "-noconf" reads none. A file that
  # "-conf" names has to exist, as Core requires. Unless the command line
  # holds "-includeconf" in any form, each "includeconf" of that file's
  # section named after the network it selects, then of its top, after the
  # last negation of it, names a file read after it; each of these has to
  # exist. It throws where a file is missing that has to exist, or cannot
  # be read or parsed (Read-NodeConf), and where Core would fail on a
  # double negation of "includeconf". Null where more than one network is
  # selected before or after the included files are read.
  param([string]$CommandLine, [string]$Datadir)
  $switch = @(Get-NodeSwitch $CommandLine)
  $v = @(Get-SettingValue $switch 'conf')
  $path = 'bitcoin.conf'
  if ($v.Count -gt 0 -and $v[-1] -is [bool]) {
    $path = if ($v[-1]) { '1' } else { $null }
  } elseif ($v.Count -gt 0 -and $v[-1].Length -gt 0) {
    $path = $v[-1]
  }
  $conf = @()
  if ($null -ne $path) { $conf = @(Read-NodeConf (Join-ConfPath $path $Datadir) -Optional:($v.Count -eq 0)) }
  if ($conf.Count -gt 0 -and @(Get-SettingValue $switch 'includeconf').Count -eq 0) {
    $chain = Get-ChainSetting $switch $conf
    if ($null -eq $chain) { return $null }
    $files = @(foreach ($section in $chain, '') {
        $v = @(Get-SettingValue @($conf | Where-Object { [string]::Equals($_.Section, $section, [StringComparison]::Ordinal) }) 'includeconf')
        $first = 0
        for ($i = 0; $i -lt $v.Count; $i++) { if ($v[$i] -is [bool] -and -not $v[$i]) { $first = $i + 1 } }
        for ($i = $first; $i -lt $v.Count; $i++) {
          if ($v[$i] -is [bool]) { throw 'Core fails on a double negation of includeconf' }
          $v[$i]
        }
      })
    foreach ($file in $files) { $conf += @(Read-NodeConf (Join-ConfPath $file $Datadir)) }
  }
  return Get-ChainSetting $switch $conf
}

function Get-NodeDatadir {
  # The data directory a node's command line names with "-datadir", the last
  # one where it names several, as Core reads it. Null where it names none.
  param([string]$CommandLine)
  $datadir = $null
  foreach ($switch in @(Get-NodeSwitch $CommandLine)) {
    if ([string]::Equals($switch.Name, 'datadir', [StringComparison]::Ordinal)) { $datadir = "$($switch.Value)" }
  }
  return $datadir
}

function ConvertTo-DatadirKey {
  # One form for the spellings of an absolute Windows path that Windows
  # normalizes alike, following the steps of Microsoft Learn's "File path
  # formats on Windows systems": "/" read as "\", runs of separators
  # collapsed, "." segments dropped and ".." segments taken back, never past
  # the root; then the period of a segment ending in a single one is dropped
  # and, where the path does not end in a separator, every trailing period
  # and space. A trailing separator is dropped last. Case is left as given,
  # for the caller to ignore.
  #
  # A device path names a drive as that page says: "\\.\C:\x" is read as
  # "C:\x" normalized, and "\\?\C:\x" as "C:\x" with nothing normalized but
  # its trailing separator, since Windows normalizes no "\\?\" path. Any
  # other device path, as a volume GUID's, is returned as given, and so
  # matches only itself.
  param([string]$Path)
  if ($Path -match '^\\\\\?\\[A-Za-z]:(\\|$)') { return $Path.Substring(4).TrimEnd([char]'\') }
  $p = $Path.Replace('/', '\')
  if ($p -match '^\\\\[.?]\\') {
    if ($p -notmatch '^\\\\\.\\[A-Za-z]:(\\|$)') { return $Path }
    $p = $p.Substring(4)
  }
  $lead = ''
  $root = 0
  if ($p.StartsWith('\\')) {
    $lead = '\\'
    $root = 2
  } elseif ($p.StartsWith('\')) {
    $lead = '\'
  } elseif ($p -match '^[A-Za-z]:') {
    $root = 1
  }
  $kept = New-Object System.Collections.Generic.List[string]
  foreach ($segment in $p.Split([char]'\')) {
    if ($segment -eq '' -or $segment -eq '.') { continue }
    if ($segment -eq '..') {
      if ($kept.Count -gt $root) { $kept.RemoveAt($kept.Count - 1) }
      continue
    }
    if ($segment -match '[^.]\.$') { $segment = $segment.Substring(0, $segment.Length - 1) }
    $kept.Add($segment)
  }
  $key = $lead + ($kept -join '\')
  if (-not $p.EndsWith('\')) { $key = $key.TrimEnd([char[]]'. ').TrimEnd([char]'\') }
  return $key
}

function Resolve-Datadir {
  # The file or directory $Path names, read through one handle. Path is its
  # final path, as GetFinalPathNameByHandle gives it, the volume named by its
  # NT device path: junctions, symbolic links, substituted drives and 8.3
  # names resolved. Volume and Index are its volume serial number and file
  # index, as GetFileInformationByHandle gives them. Null where Windows
  # answers that $Path does not exist, with ERROR_FILE_NOT_FOUND or
  # ERROR_PATH_NOT_FOUND; any other failure throws. A relative $Path is read
  # against this process's working directory. Off Windows, where only the
  # tests run this file, it resolves nothing.
  param([string]$Path)
  if ($env:OS -ne 'Windows_NT') { return $null }
  if (-not ('PortaNode.DatadirFile' -as [type])) {
    Add-Type -Namespace PortaNode -Name DatadirFile -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
private static extern Microsoft.Win32.SafeHandles.SafeFileHandle CreateFileW(
  string name, uint access, uint share, IntPtr security, uint disposition,
  uint flags, IntPtr template);
// CreateFileW with its error read before any other call can replace it. No
// access asked, every sharing mode, OPEN_EXISTING, and
// FILE_FLAG_BACKUP_SEMANTICS, without which a directory does not open.
public static Microsoft.Win32.SafeHandles.SafeFileHandle Open(string name, out int error) {
  Microsoft.Win32.SafeHandles.SafeFileHandle handle = CreateFileW(
    name, 0, 7, IntPtr.Zero, 3, 0x02000000, IntPtr.Zero);
  error = Marshal.GetLastWin32Error();
  return handle;
}
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern uint GetFinalPathNameByHandleW(
  Microsoft.Win32.SafeHandles.SafeFileHandle file, System.Text.StringBuilder path,
  uint size, uint flags);
// BY_HANDLE_FILE_INFORMATION, each FILETIME as its two halves.
[StructLayout(LayoutKind.Sequential)]
public struct FileInformation {
  public uint Attributes;
  public uint CreatedLow, CreatedHigh, AccessedLow, AccessedHigh, WrittenLow, WrittenHigh;
  public uint VolumeSerialNumber;
  public uint SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
}
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetFileInformationByHandle(
  Microsoft.Win32.SafeHandles.SafeFileHandle file, out FileInformation information);
'@
  }
  $err = 0
  $handle = [PortaNode.DatadirFile]::Open($Path, [ref]$err)
  try {
    if ($handle.IsInvalid) {
      if ($err -eq 2 -or $err -eq 3) { return $null }
      throw "cannot open '$Path': Windows error $err"
    }
    $size = 32768
    $final = New-Object System.Text.StringBuilder $size
    # 2 is VOLUME_NAME_NT.
    $length = [PortaNode.DatadirFile]::GetFinalPathNameByHandleW($handle, $final, $size, 2)
    if ($length -eq 0 -or $length -ge $size) { throw "cannot read the final path of '$Path'" }
    $info = New-Object PortaNode.DatadirFile+FileInformation
    if (-not [PortaNode.DatadirFile]::GetFileInformationByHandle($handle, [ref]$info)) {
      throw "cannot read the file index of '$Path'"
    }
    return [pscustomobject]@{
      Path = $final.ToString()
      Volume = $info.VolumeSerialNumber
      Index = ([uint64]$info.IndexHigh -shl 32) -bor $info.IndexLow
    }
  } finally {
    $handle.Dispose()
  }
}

function Test-DatadirMatch {
  # True where the data directory $NodeDatadir, as a node's -datadir names
  # it, is $Datadir.
  #
  # The two directories are compared through Resolve-Datadir: by final path,
  # with case ignored, and where those differ, by volume serial number and
  # file index. It throws where the caller cannot tell whether the node uses
  # $Datadir: the node's directory is not a full path, which Core reads
  # against the node's own working directory, or does not resolve; $Datadir
  # does not resolve and Windows does not answer that it is missing; or the
  # paths differ and a serial number or an index is zero. Core refuses a
  # -datadir that is not a directory, so where Windows answers that $Datadir
  # does not exist (ERROR_FILE_NOT_FOUND or ERROR_PATH_NOT_FOUND), the two
  # are compared by ConvertTo-DatadirKey alone.
  param([string]$NodeDatadir, [string]$Datadir)
  $d = $NodeDatadir
  if ([string]::Equals((ConvertTo-DatadirKey $d), (ConvertTo-DatadirKey $Datadir),
      [StringComparison]::OrdinalIgnoreCase)) { return $true }
  $own = Resolve-Datadir $Datadir
  if ($null -eq $own) { return $false }
  $node = $null
  if ($d -match '^([A-Za-z]:[\\/]|[\\/][\\/])') {
    $node = Resolve-Datadir $d
  }
  if ($null -eq $node) { throw "cannot resolve the data directory '$d' of a running node" }
  if ([string]::Equals($node.Path, $own.Path, [StringComparison]::OrdinalIgnoreCase)) { return $true }
  if ($node.Volume -eq 0 -or $node.Index -eq 0 -or $own.Volume -eq 0 -or $own.Index -eq 0) {
    throw "cannot identify the data directory '$d' of a running node"
  }
  return ($node.Volume -eq $own.Volume -and $node.Index -eq $own.Index)
}

function Test-NodeOnDatadir {
  # True where a node's command line names $Datadir as its data directory
  # (Test-DatadirMatch) and, where $Chain is not empty, the node selects the
  # network $Chain: Get-NodeNetwork names it, read with the configuration
  # files of $Datadir, or Get-NodeChain names it, or Get-NodeNetwork finds
  # more than one network, which Core refuses. The network is read first, so
  # a node that selects another one counts as on another data directory
  # whatever its -datadir. Where Get-NodeNetwork throws, it throws too,
  # unless the node's -datadir is known to name another directory.
  param([string]$CommandLine, [string]$Datadir, [string]$Chain)
  $d = Get-NodeDatadir $CommandLine
  if ($null -eq $d) { return $false }
  if ($Chain) {
    try {
      $network = Get-NodeNetwork $CommandLine $Datadir
    } catch {
      if (Test-DatadirMatch $d $Datadir) { throw }
      return $false
    }
    if ($null -ne $network -and -not [string]::Equals($network, $Chain, [StringComparison]::Ordinal) -and
      -not [string]::Equals((Get-NodeChain $CommandLine), $Chain, [StringComparison]::Ordinal)) { return $false }
  }
  return Test-DatadirMatch $d $Datadir
}

function Test-MainnetNode {
  # True where a node's command line selects mainnet.
  param([string]$CommandLine)
  return ((Get-NodeChain $CommandLine) -ceq 'main')
}
