param(
  [Parameter(Mandatory = $true)]
  [string]$RootDir
)

$logFile = Join-Path $RootDir 'bitcoin-datadir\\debug.log'
$lastCheckFile = Join-Path $RootDir '.last_log_check'

if (-not (Test-Path $logFile)) {
  Write-Host "Log file not found: $logFile"
  exit 0
}

$lastLine = 0
if (Test-Path $lastCheckFile) {
  $value = Get-Content -Path $lastCheckFile -TotalCount 1
  if ($value) {
    $lastLine = [int]$value
  }
}

$currentLines = (Get-Content -Path $logFile -ReadCount 0).Count
if ($currentLines -le $lastLine) {
  exit 0
}

$start = $lastLine + 1
$end = $currentLines
$lines = Get-Content -Path $logFile |
  Select-Object -Skip ($start - 1) -First ($end - $start + 1)
$errors = $lines |
  Select-String -Pattern 'error|warning|failed' -CaseSensitive:$false |
  Select-Object -First 5

if ($errors) {
  Write-Host 'Bitcoin log errors detected:'
  $errors | ForEach-Object { Write-Host $_.Line }

  $toastShown = $false
  try {
    [Windows.UI.Notifications.ToastNotificationManager,
     Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
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

Set-Content -Path $lastCheckFile -Value $currentLines
