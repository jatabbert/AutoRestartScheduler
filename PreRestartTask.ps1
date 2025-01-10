function MakeTheTask {
    param (
        [string]$taskName,
        [string]$eventTime
    )
    # Check if task exists
    $taskExists = Get-ScheduledTask -TaskName $taskname -ErrorAction SilentlyContinue

    if ($taskExists) {
        Unregister-ScheduledTask -taskname $taskname -confirm:$false
    }

    # Create a trigger for the scheduled task
    $trigger = New-ScheduledTaskTrigger -Once -At $eventTime

    # Create an action for the scheduled task
    $action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c shutdown /r /t 0"

    # additional task settings
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -StartWhenAvailable -DontStopIfGoingOnBatteries

    # Register the scheduled task
    Register-ScheduledTask -TaskName $taskname -Trigger $trigger -Action $action -RunLevel Highest -Description "Restart the computer" -user "NT AUTHORITY\SYSTEM" -Settings $settings
}

# Create task to delete the auto-restart task if the computer reboots or shuts down before the scheduled time <Author>FNB_DOMAIN\jtabbert1</Author>
function ScheduleCleanupTask {

    $xml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <RegistrationInfo>
    <Date>2024-05-17T12:24:40.532371</Date>
    <URI>\RemoveAutoRestartWhenDone</URI>
    </RegistrationInfo>
    <Principals>
    <Principal id="Author">
        <UserId>S-1-5-18</UserId>
        <RunLevel>HighestAvailable</RunLevel>
    </Principal>
    </Principals>
    <Settings>
    <AllowHardTerminate>false</AllowHardTerminate>
    <DeleteExpiredTaskAfter>PT0S</DeleteExpiredTaskAfter>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <StartWhenAvailable>true</StartWhenAvailable>
    <IdleSettings>
        <StopOnIdleEnd>true</StopOnIdleEnd>
        <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    </Settings>
    <Triggers>
    <EventTrigger>
        <EndBoundary>2039-11-30T12:33:12</EndBoundary>
        <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='User32'] and EventID=1074]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    </Triggers>
    <Actions Context="Author">
    <Exec>
        <Command>powershell.exe</Command>
        <Arguments>-NoProfile -Command "schtasks /Delete /TN 'AutoRestartForPatches' /F; schtasks /Delete /TN 'RemoveAutoRestartWhenDone' /F; schtasks /Delete /TN 'RestartReminder' /F"</Arguments>
    </Exec>
    </Actions>
</Task>    
'@

    # Check if task exists
    $taskExists = Get-ScheduledTask -TaskName "RemoveAutoRestartWhenDone" -ErrorAction SilentlyContinue

    if (-not($taskExists)) {
        Register-ScheduledTask -TaskName "RemoveAutoRestartWhenDone" -xml $xml
    }
}

function ScheduleReminderTask {
    param (
        [string]$warningTime,
        [string]$restartTime
    )

    $xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2025-01-08T12:05:46.0409901</Date>
    <URI>\RestartReminder</URI>
  </RegistrationInfo>
  <Triggers>
    <TimeTrigger>
      <Repetition>
        <Interval>PT5M</Interval>
        <Duration>PT15M</Duration>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>$warningTime</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>msg.exe</Command>
      <Arguments>* /time:295 "Your computer is scheduled to restart at $restartTime! Please save all open work now. You may restart your computer now if you do not want to wait."</Arguments>
    </Exec>
  </Actions>
</Task>
"@

    # Check if task exists
    $taskExists = Get-ScheduledTask -TaskName "RestartReminder" -ErrorAction SilentlyContinue

    if ($taskExists) {
        Unregister-ScheduledTask -TaskName "RestartReminder" -confirm:$false
        Register-ScheduledTask -TaskName "RestartReminder" -xml $xml
    }
    else {
        Register-ScheduledTask -TaskName "RestartReminder" -xml $xml
    }
}


# query for logged in users
$explorerProcesses = @(Get-WmiObject -Query "Select * FROM Win32_Process WHERE Name='explorer.exe'" -ErrorAction SilentlyContinue)

# if nobody is currently logged in then reboot immediately
if ($explorerProcesses.Count -eq 0) {
    Start-Process -FilePath "cmd.exe" -ArgumentList '/c "timeout /t 3 /nobreak && shutdown -r -f -t 0"' -WindowStyle Hidden
    Exit 555
}
else {
    # Create temp directory for information
    if (-not (Test-Path -Path "C:\temp")) {
        New-Item -Path "C:\temp" -ItemType Directory
    }

    # Get the datetime of the current/upcoming Friday
    $incrementer = 0
    do {
        $cutoffDay = (Get-Date).AddDays($incrementer).ToString("D")
        $incrementer++
    }
    while ($cutoffDay -notlike "Saturday*")

    # Add 5PM to the datetime retrieved above and convert string to actual datetime
    $cutoffDay = $cutoffDay + " 5:00 PM"
    [datetime]$theDate = Get-Date -Date $cutoffDay
    $warningDate = $theDate.AddMinutes(-20)
    $dateString = $warningDate.ToString("yyyy-MM-dd") + "T" + $warningDate.ToString("HH:mm:ss")
    $restartTime = $theDate.ToString("h:mm tt")

    # Schedule restart for Friday at 5pm
    MakeTheTask -taskName "AutoRestartForPatches" -eventTime $theDate
    # Schedule separate task that will delete "AutoRestartForPatches"
    ScheduleCleanupTask
    # schedule a 10 minute warning popup before the reboot
    ScheduleReminderTask -warningTime $dateString -restartTime $restartTime
}
