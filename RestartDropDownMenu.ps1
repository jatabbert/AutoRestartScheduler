Add-Type -AssemblyName System.Windows.Forms

# Create a new form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Restart Time Selection"
$form.Size = New-Object System.Drawing.Size(670, 240)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.ControlBox = $false  # Hide the control box so they can't minimize/close
$form.TopMost = $true # forces popup to stay on top of everything else
$form.ShowInTaskbar = $false # hide this popup from the windows taskbar

# Create labels
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10, 10)
$label.Size = New-Object System.Drawing.Size(660, 100)
$label.Font = New-Object System.Drawing.Font('Times New Roman',13)
$label.Text = "Windows Updates requires a restart of your computer to finish.
If you do not select a time your computer will automatically restart Saturday at 5PM.
If your computer is sleeping at the scheduled time, it WILL restart as soon as it wakes up.

Select a time, between now and Saturday at 5PM, that you want to schedule your restart:"
$form.Controls.Add($label)

# Populate a hash table used to fill in Day dropdown and for later date string building
$dayTable = @{}
$increment = 0
do {
    $fullDay = (Get-Date).AddDays($increment).ToString("dddd, MMMM dd, yyyy")
    $dayTable.Add($increment, $fullDay)
    $increment++
} while ($fullDay -notlike "Saturday*")

# Create Day dropdown
$dayDropDown = New-Object System.Windows.Forms.ComboBox
$dayDropDown.Location = New-Object System.Drawing.Point(10, 125)
$dayDropDown.Size = New-Object System.Drawing.Size(160, 20)
for ($i = 0; $i -lt $dayTable.Count; $i++) {
    $retrieved = $dayTable[$i]
    $retrieved = $retrieved.Substring(0, $retrieved.Length - 6)
    $dayDropDown.Items.Add($retrieved) | Out-Null
}
$dayDropDown.SelectedIndex = 0
$dayDropDown.DropDownHeight = 100
$form.Controls.Add($dayDropDown)

# Create @ symbol
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(175, 125)
$label.Size = New-Object System.Drawing.Size(20, 20)
$label.Font = New-Object System.Drawing.Font('Times New Roman',13)
$label.Text = "at"
$form.Controls.Add($label)

# Create hour dropdown
$hourDropDown = New-Object System.Windows.Forms.ComboBox
$hourDropDown.Location = New-Object System.Drawing.Point(200, 125)
$hourDropDown.Size = New-Object System.Drawing.Size(40, 20)
$hours = ("1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12")
foreach ($hour in $hours) {
    $hourDropDown.Items.Add($hour) | Out-Null
}
$hourDropDown.SelectedIndex = 4
$hourDropDown.DropDownHeight = 300
$form.Controls.Add($hourDropDown)

# Create minute dropdown
$minuteDropDown = New-Object System.Windows.Forms.ComboBox
$minuteDropDown.Location = New-Object System.Drawing.Point(245, 125)
$minuteDropDown.Size = New-Object System.Drawing.Size(40, 20)
$minutes = ("00", "05", "10", "15", "20", "25", "30", "35", "40", "45", "50", "55")
foreach ($minute in $minutes) {
    $minuteDropDown.Items.Add($minute) | Out-Null
}
$minuteDropDown.SelectedIndex = 0
$minuteDropDown.DropDownHeight = 300
$form.Controls.Add($minuteDropDown)

# Create AM/PM dropdown
$ampmDropDown = New-Object System.Windows.Forms.ComboBox
$ampmDropDown.Location = New-Object System.Drawing.Point(290, 125)
$ampmDropDown.Size = New-Object System.Drawing.Size(40, 20)
$ampmDropDown.Items.Add("AM") | Out-Null
$ampmDropDown.Items.Add("PM") | Out-Null
$ampmDropDown.SelectedIndex = 1
$form.Controls.Add($ampmDropDown)

# Create OK button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(10, 170)
$okButton.Size = New-Object System.Drawing.Size(100, 23)
$okButton.Text = "Confirm Time"
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($okButton)

# Create NOW button
$YesButton = New-Object System.Windows.Forms.Button
$YesButton.Location = New-Object System.Drawing.Point(555, 170)
$YesButton.Size = New-Object System.Drawing.Size(90, 23)
$YesButton.Text = "Restart NOW"
$YesButton.DialogResult = [System.Windows.Forms.DialogResult]::Yes
$form.Controls.Add($YesButton)

$form.AcceptButton = $okButton

# get the datetime for this upcoming cutoffday at X time
$incrementer = 0
do {
    $friday = (Get-Date).AddDays($incrementer).ToString("D")
    $incrementer++
}
while ($friday -notlike "Saturday*")

$friday = $friday + " 5:00 PM"
[datetime]$theDate = Get-Date -Date $friday

# Retrieve values
do {
    $result = $form.ShowDialog()
    [datetime]$currentTime = Get-Date

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        # OK button clicked
        $selectedDay = $dayTable.($dayDropDown.SelectedIndex)
        $selectedHour = $hourDropDown.SelectedItem
        $selectedMinute = $minuteDropDown.SelectedItem
        $selectedAMPM = $ampmDropDown.SelectedItem
        $roughtime = "$selectedDay $selectedHour`:$selectedMinute $selectedAMPM"
        [datetime]$convertedTime = Get-Date -Date $roughtime -Format F
    }
    else {
        # Restart NOW button clicked
        $restartNow = "restartNow"
        $restartNow | Out-File -FilePath "C:\temp\arestarter.txt" -Force
        Exit
    }
}
while (($convertedTime -lt $currentTime) -or ($convertedTime -gt $theDate))

($convertedTime).ToString("f") | Out-File -FilePath "C:\temp\arestarter.txt" -Force
