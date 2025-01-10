# Creates a task scheduler task to force reboot the computer at a specified time of that day
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

# Make sure the file exists and is accessible, otherwise return error
if (Test-Path -Path "C:\temp\arestarter.txt") {
    $scheduledTime = Get-Content -Path "C:\temp\arestarter.txt"

    # if user wants to restart now, remove scheduled tasks and temp file then reboot
    if ($scheduledTime -eq "restartNow") {
        Unregister-ScheduledTask -TaskName "AutoRestartForPatches" -confirm:$false
        Unregister-ScheduledTask -TaskName "RemoveAutoRestartWhenDone" -Confirm:$false
        Unregister-ScheduledTask -TaskName "RestartReminder" -Confirm:$false
        Remove-Item -Path "C:\temp\arestarter.txt" -Force
        Start-Process -FilePath "cmd.exe" -ArgumentList '/c "timeout /t 3 /nobreak && shutdown -r -f -t 0"' -WindowStyle Hidden
        Exit
    }
    # Recreate the scheduled task using the user picked time then remove temp file
    else {
        [datetime]$theDate = Get-Date -Date $scheduledTime
        $restartTime = $theDate.ToString("h:mm tt")
        $theDate = $theDate.AddMinutes(-20)
        $datestring = $theDate.ToString("yyyy-MM-dd") + "T" + $theDate.ToString("HH:mm:ss")
        
        ScheduleReminderTask -warningTime $datestring -restartTime $restartTime
        MakeTheTask -taskName "AutoRestartForPatches" -eventTime $scheduledTime
        Remove-Item -Path "C:\temp\arestarter.txt" -Force
    }
}
else {
    # error code in case the temp file doesn't exist for some reason
    return 666
}
