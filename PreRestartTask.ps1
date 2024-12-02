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

# Create task to delete the auto-restart task if the computer reboots or shuts down before the scheduled time
function ScheduleCleanupTask {

    $xml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <RegistrationInfo>
    <Date>2024-05-17T12:24:40.532371</Date>
    <Author>CHANGE_AS_NEEDED</Author>
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
        <Command>cmd.exe</Command>
        <Arguments>/c schtasks /Delete /TN "AutoRestartForPatches" /F</Arguments>
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

# Create temp directory for information
if (-not (Test-Path -Path "C:\temp")) {
    New-Item -Path "C:\temp" -ItemType Directory
}

# Get the datetime of the current/upcoming Friday
$incrementer = 0
do {
    $friday = (Get-Date).AddDays($incrementer).ToString("D")
    $incrementer++
}
while ($friday -notlike "Friday*")

# Add 5PM to the datetime retrieved above and convert string to actual datetime
$friday = $friday + " 5:00 PM"
[datetime]$theDate = Get-Date -Date $friday

# Schedule restart for Friday at 5pm
MakeTheTask -taskName "AutoRestartForPatches" -eventTime $theDate
# Schedule separate task that will delete "AutoRestartForPatches"
ScheduleCleanupTask