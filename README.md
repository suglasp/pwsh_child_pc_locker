

## Child PC Locker utility
##  for Windows
==========================

**What it does**

Prevents children to game for long hours, utility acts as a safeguard.

When the time has been reached (configured in the json config file), it shows a full screen Winform convering all open screens behind it.
It will showing a text that the time has been reached. And it will also show two blue buttons "Defer (+5m)" and "Unlock".
The child can click "Defer (+5m)" to defer the time for +5 minutes for a number of times.
This is also configurable, so it's not endless they can defer. Default is 2 times they can click the button (for up to 10min total).
Parents can click the "Unlock" button, to do a few options after entering the correct PIN code:
- "Reset", rest the timer (reloads to the json config settings) + restart timing.
- "Defer (+1h)", defers time for +1h (60min), the defer button turns Orange and as a parent, the defer count will NOT increase.
- "Lock", exit the Parents mode and return to the "Defer (+5m)" and "Unlock" buttons.
- "Shutdown", force the PC to shutdown. Killing all app's (this function needs Administator rights, otherwise it will be grayed out!)
- "Disable Guard", this just quits the Child PC Locker utility.

ALT+F4 is intercepted, so the Winform can not be closed by pressing this key combination.


**Needed Sub-Folder**

.\Logs							->	log files will be written here. The current log files is a .log and the previous one is a .bck


**Needed Files**

child_pc_locker.cmd				->	Run child_pc_locker.ps1	in normal mode.
child_pc_locker.json			->	Configuration file in json format.
child_pc_locker.ps1				->	The actual utility or script.
child_pc_locker_debug.cmd		->	Run child_pc_locker.ps1	in Verbose + Debug mode. In Debug mode, you can press ESC to exit.
child_pc_locker_install.reg		->	Registry file to install the tool under the current user (copy all files under "C:\Program Files\pclocker\")
child_pc_locker_uninstall.reg	->	Registry file to uninstall the tool under the current user
README							->	This file
LICENSE							->	Software license


**Structure of the 'child_pc_locker.json'**

- Script.Verbose                 : "true" or "" to enable/disable Console output
- Script.Debug                   : "true" or "false" to enable/disable developer mode (Allows ESC to quit without questions asked!)
- Locker.ParentalPIN             : enter a PIN code of max 8 numbers
- Locker.NotifyKidsBeforeExpire  : "true" or "false" to enable/disable child upfront message (10 min before expire of play time)
- KidsSafeGuardAfter.Hours       : number from 0-24 (hours)
- KidsSafeGuardAfter.Minutes     : number from 0-60 (minutes)
- KidsSafeGuardAfter.DeferCount  : number that allows number of defers (+5m extend) a child can request

**Known issues**
- One can still ALT+TAB and try to close the WinForm (or Powershell cmd window in Debug mode)
