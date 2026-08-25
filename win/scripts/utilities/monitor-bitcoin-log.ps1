param(
  [Parameter(Mandatory = $true)]
  [string]$RootDir,
  [switch]$NoNotify
)

if (-not $NoNotify -and $env:PORTANODE_NO_NOTIFY -eq '1') {
  $NoNotify = $true
}

$logFile = Join-Path $RootDir 'bitcoin-datadir\debug.log'
$lastCheckFile = Join-Path $RootDir '.last_log_offset'

if (-not (Test-Path $logFile)) {
  Write-Host "Log file not found: $logFile"
  exit 0
}

$lastOffset = 0
if (Test-Path $lastCheckFile) {
  $value = Get-Content -Path $lastCheckFile -TotalCount 1
  if ($value -match '^\d+$') {
    $lastOffset = [int64]$value
  }
}

# Current size from the filesystem's own metadata rather than by reading the
# file -- debug.log reaches hundreds of megabytes during initial block
# download, and this runs every few minutes.
$currentSize = (Get-Item -Path $logFile).Length
if ($currentSize -lt $lastOffset) {
  $lastOffset = 0
  Set-Content -Path $lastCheckFile -Value 0
}

if ($currentSize -gt $lastOffset) {
  # Seek to the stored offset instead of reading the file from byte zero.
  $stream = [System.IO.File]::Open($logFile, [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
  try {
    $stream.Seek($lastOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
    $reader = New-Object System.IO.StreamReader($stream)
    $newText = $reader.ReadToEnd()
  } finally {
    $stream.Dispose()
  }
  $lines = $newText -split "`r?`n"
  $errors = $lines |
    Select-String -Pattern 'error|warning|failed' -CaseSensitive:$false |
    Select-Object -First 5

  if ($errors) {
    Write-Host 'Bitcoin log errors detected:'
    $errors | ForEach-Object { Write-Host $_.Line }

    if (-not $NoNotify) {
      $toastShown = $false
      try {
        # The type literal cannot wrap: PowerShell's tokenizer rejects an
        # assembly-qualified type name split across lines.
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        $template =
          [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
            [Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $text = $template.GetElementsByTagName('text')
        $text.Item(0).AppendChild(
          $template.CreateTextNode('PortaNode Alert')) | Out-Null
        $text.Item(1).AppendChild(
          $template.CreateTextNode(
            'Bitcoin log errors detected. Check debug.log.')) | Out-Null
        $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
        $notifier =
          [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(
            'PortaNode')
        $notifier.Show($toast)
        $toastShown = $true
      } catch {
      }

      if (-not $toastShown) {
        try {
          Add-Type -AssemblyName System.Windows.Forms
          [System.Windows.Forms.MessageBox]::Show(
            'Bitcoin log errors detected. Check debug.log for details.',
            'PortaNode Alert') | Out-Null
        } catch {
          Write-Host 'Warning: notification unavailable.'
        }
      }
    }
  }

  Set-Content -Path $lastCheckFile -Value $currentSize
}
