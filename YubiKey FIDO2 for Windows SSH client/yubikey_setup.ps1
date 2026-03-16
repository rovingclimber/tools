# ==============================================================================
# YubiKey Switchboard Autostart Setup (Filtered & Silent Version)
# Registers a Windows Task to launch the GUI ONLY when a YubiKey is configured.
# Also ensures the Windows SSH Agent service is enabled and running.
# ==============================================================================

# 1. Ensure SSH Agent service is enabled and running
Write-Host "Ensuring SSH Agent service is active..." -ForegroundColor Gray
try {
    Set-Service -Name ssh-agent -StartupType Automatic
    Start-Service -Name ssh-agent -ErrorAction SilentlyContinue
    Write-Host "SSH Agent is now set to Automatic and Started." -ForegroundColor Green
} catch {
    Write-Host "Warning: Could not configure SSH Agent. Ensure you are running as Administrator." -ForegroundColor Yellow
}

$taskName = "LaunchYubiKeySwitchboard"
$scriptPath = Join-Path $HOME ".ssh\yubikey_switchboard.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "Error: Could not find switchboard script at $scriptPath" -ForegroundColor Red
    return
}

# 2. Generate the Task XML
$userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value

# Simplified EventQuery to ensure XML validity for Task Scheduler.
# Filtering for 'Yubi' is handled in the Command Arguments below.
$eventQuery = "*[System[EventID=400]]"

$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Launches YubiKey Switchboard silently when a YubiKey is configured.</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>$userSid</UserId>
    </LogonTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id='0' Path='Microsoft-Windows-Kernel-PnP/Configuration'&gt;&lt;Select Path='Microsoft-Windows-Kernel-PnP/Configuration'&gt;$eventQuery&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$userSid</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -Command "if (Get-WinEvent -LogName 'Microsoft-Windows-Kernel-PnP/Configuration' -MaxEvents 1 | Where-Object { `$_.Message -match 'Yubi' }) { &amp; '$scriptPath' }"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# 3. Register the Task
try {
    Register-ScheduledTask -Xml $taskXml -TaskName $taskName -Force
    Write-Host "`n--- YubiKey Automation Registered ---" -ForegroundColor Green
    Write-Host "Triggered by: Kernel-PnP Event 400" -ForegroundColor White
    Write-Host "Logic: Filters for 'Yubi' in background and launches silently." -ForegroundColor Gray
} catch {
    Write-Host "`nFailed to register task: $($_.Exception.Message)" -ForegroundColor Red
}