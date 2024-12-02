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

# Make sure the file exists and is accessible, otherwise return error
if (Test-Path -Path "C:\temp\arestarter.txt") {
    $scheduledTime = Get-Content -Path "C:\temp\arestarter.txt"

    # if user wants to restart now, remove scheduled tasks and temp file then reboot
    if ($scheduledTime -eq "restartNow") {
        Unregister-ScheduledTask -TaskName "AutoRestartForPatches" -confirm:$false
        Unregister-ScheduledTask -TaskName "RemoveAutoRestartWhenDone" -Confirm:$false
        Remove-Item -Path "C:\temp\arestarter.txt" -Force
        Restart-Computer -Force
    }
    # Recreate the scheduled task using the user picked time then remove temp file
    else {
        MakeTheTask -taskName "AutoRestartForPatches" -eventTime $scheduledTime
        Remove-Item -Path "C:\temp\arestarter.txt" -Force
    }
}
else {
    # error code in case the temp file doesn't exist for some reason
    return 666
}