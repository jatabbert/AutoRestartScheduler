This is used to enforce computer restarts, but also allow end users some flexibility on when they restart. This runs as three separate powershell scripts. It has a timeout of 10 hours, so nobody should miss it over lunch or something like that.

	1. PreRestartTask.ps1 - Runs first
		a. This runs as local system on their computer and creates a task in Task Scheduler named AutoRestartForPatches that runs the bat cmd "/c shutdown /r /t 0" which triggers the upcoming Friday at 5pm
		b. It then creates another scheduled task called RemoveAutoRestartWhenDone which triggers upon the event of their computer restarting or shutting down which deletes the AutoRestartForPatches task. This is here in case they manually restart before the scheduled task.
    c. NOTE: the function "ScheduleCleanupTask" has <Author>CHANGE_AS_NEEDED</Author> hardcoded in the XML, that you may or may not need to set to something valid in order for it to function properly.
    
	2. RestartDropDownMenu.ps1
		a. This runs as the logged on user and creates a popup requesting user input on when they want to schedule an automatic restart.
		b. They cannot close the window without selecting an option.
		c. It stays on top of all other windows.
		d. And will not accept dropdown values that are before the current computer time OR later than Friday at 5pm.
			i. If they attempt to confirm a time outside of that window, it will redraw the window and waits for them to select a valid time.
		e. The day dropdown will give options for each day between "today" and Friday.
		f. Once they click Confirm Time or Restart NOW it will write that full Date/Time or "restartNow" to C:\temp\arestarter.txt, respectively.
  
	3. PostRestartTask.ps1
		a. The last one will run as local system and read the contents of C:\temp\arestarter.txt and act upon it as follows:
		b. restartNow - It will delete the two scheduled tasks created in PreRestartTask.ps1, then delete the arestarter.txt file, then immediately force restart their computer.
		c. Date/Time - It will delete the AutoRestartForPatches task from the first step then recreate it with the trigger time set to the Date/Time value the user selected, then delete the arestarter.txt file.
  	
   	NOTE: Changing cutoff days/time requires modifying both PreRestartTask.ps1 and RestartDropDownMenu.ps1. 
        PreRestartTask.ps1: 	 while ($friday -notlike "Friday*") # Need to change "Friday*" to whichever day you'd want to set as a cutoff
                            	 $friday = $friday + " 5:00 PM" # Need to change that time to whatever default restart time you'd want
        RestartDropDownMenu.ps1: Change the verbiage on the popup label.
				 Edit while loop as above when populating the hash table.
     				 Edit other while loop as mentioned in the line above.

        
