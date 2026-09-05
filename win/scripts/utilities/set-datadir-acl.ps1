# Replaces -Path's DACL with a protected one granting -Account full control
# and nothing else, then exits 0. Exits 1, with a message on stderr, where
# the account cannot be resolved or the DACL cannot be written.
#
# win/scripts/utilities/set-permissions.bat is the caller, and the comment
# above its call carries what was measured about the result: the DACL this
# leaves, what a reader sees while it is written, what an unresolvable
# account leaves behind, and what a volume storing no ACL does with it.
param(
  [Parameter(Mandatory = $true)]
  [string]$Path,
  [Parameter(Mandatory = $true)]
  [string]$Account
)

$ErrorActionPreference = 'Stop'

try {
    $full = (Resolve-Path -LiteralPath $Path).ProviderPath

    # The descriptor is built rather than read back: a new DirectorySecurity
    # carries no rule, so the granted one is the whole of the DACL written
    # and an ACE another identity held on the directory survives none of it.
    # Get-Acl and AddAccessRule would keep those, which is what the caller
    # is removing. Only the access rules of this object are set, so the
    # owner, the group and the SACL are left as they are found.
    $security = New-Object -TypeName System.Security.AccessControl.DirectorySecurity

    # The first argument protects the DACL from its parent's inheritable
    # ACEs and the second declines to copy them in as explicit ones on the
    # way, which together are icacls's /inheritance:r rather than its
    # /inheritance:d.
    $security.SetAccessRuleProtection($true, $false)

    # ContainerInherit and ObjectInherit are icacls's (OI)(CI), and
    # FullControl its F.
    $inheritance = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor `
        [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList @(
        $Account,
        [System.Security.AccessControl.FileSystemRights]::FullControl,
        $inheritance,
        [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow)

    # The name is translated to a SID here rather than by the constructor
    # above, so an account that does not resolve throws on this line and
    # Set-Acl is never reached. Measured on windows-latest against an
    # account that does not exist: the constructor returned, this call
    # raised "Some or all identity references could not be translated",
    # and the directory's DACL compared equal before and after.
    $security.AddAccessRule($rule)

    Set-Acl -LiteralPath $full -AclObject $security
} catch {
    # The account and the path are named because the exception text does
    # not carry either: an unresolvable account reports "Some or all
    # identity references could not be translated", which says nothing
    # about which account or which directory the caller was working on.
    [Console]::Error.WriteLine("Could not restrict $Path to ${Account}: $($_.Exception.Message)")
    exit 1
}
