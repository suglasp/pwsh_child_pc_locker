#
# Child PC Locker utility
# Pieter De Ridder
#
# Script or tool that can lock a Windows machine after a certain amount of time.
# The idea was for my kids, to safeguard gaming or play time on a Windows PC.
#
# Created : 01/10/2023
# Changed : 03/10/2023
#
# Use the child_pc_locker.json to configure the basic settings:
# Script.Verbose                 : true or false to enable/disable Console output
# Script.Debug                   : true or false to enable/disable developer mode (Allows ESC to quit without questions asked!)
# Locker.ParentalPIN             : enter a PIN code of max 8 numbers
# Locker.NotifyKidsBeforeExpire  : true or false to enable/disable child upfront message (10 min before expire of play time)
# KidsSafeGuardAfter.Hours       : number from 0-24 (hours)
# KidsSafeGuardAfter.Minutes     : number from 0-60 (minutes)
# KidsSafeGuardAfter.DeferCount  : number that allows number of defers (+5m extend) a child can request
#
# Notes :
# - The utility/script has been tested with a single screen/monitor
# - Works with Powershell 7.3
#


# Import .NET Windows Forms Assembly
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework

# Import .NET Libraries and functions for Console window
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'


#Region Global Variables
# Global scope general app vars
[String]$Global:WorkDir			        = "$($PSScriptRoot)"
[String]$Global:ScriptName		        = $($MyInvocation.MyCommand.Name.Substring(0, $MyInvocation.MyCommand.Name.Length -4))
[Bool]$Global:VerboseMode		        = $False
[Bool]$Global:DebugMode		            = $False
[String]$Global:ConfigPath		        = "$($Global:WorkDir)\$($Global:ScriptName).json"
[PSObject]$Global:Config		        = $Null
[String]$Global:Logs			        = "$($PSScriptRoot)\Logs"
[String]$Global:LogFile			        = "$($Global:Logs)\$($Global:ScriptName).log"
[Bool]$Global:ConsoleWndHidden	        = $False
[System.Windows.Forms.Form]$Global:Form = $null
[DateTime]$Global:TimeBegin             = (Get-Date)
[Bool]$Global:Active                    = $True
[Bool]$Global:FormShown                 = $False
[UInt32]$Global:TimesDefer              = 0           # nr of times the child pressed "Defer (+5m)" button

# Script scope general app vars
[Bool]$Script:AltF4Pressed              = $False
#EndRegion



#Region Logging
#
# Function : Write-Log
#
Function Global:Write-Log {
    Param (
		[Parameter(Mandatory=$True)]
		[AllowEmptyString()]
        [String]$Msg
    )

    # format message with time stamp
    [String]$sMessage = "[$(Get-Date -Format "dd-MM-yy HH:mm:ss")] $($Msg)"

	# create log file if needed
    If (-Not (Test-Path -Path $(Split-Path $Global:LogFile -Parent))) {
        New-Item -Path $(Split-Path $Global:LogFile -Parent) -ItemType Directory
    }
 
    # write UTF content
	Add-Content -Path $Global:LogFile -Value $sMessage -Encoding UTF8 -Force

    # write same msg to stdout
	If ($Global:VerboseMode) {
		Write-Host $sMessage
	}
}
#EndRegion


#Region Configuration
#
# Function : Load-ScriptConfig
#
Function Load-ScriptConfig {
    Write-Log -Msg "Config : $($Global:ConfigPath)"

    If (Test-Path -Path $Global:ConfigPath) {
	    $Global:Config = @(Get-Content -Raw -Path $Global:ConfigPath | ConvertFrom-Json)

        If ($Null -ne $Global:Config) {
            Write-Log -Msg "[i] Loaded config"
        } Else {
            Write-Log -Msg "[!] Error loading configuration data"
            Exit(-1)
        }
    } Else {
        Write-Log -Msg "[!] Error loading config file, not present"
        Exit(-1)
    }
}


#
# Function : Is-Admin
# Local Admin user?
# 
Function Is-Admin {
    Return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}
#EndRegion


#Region Console Window
#
# Function : Hide-Console
#
Function Hide-Console
{
    # Hide = 0,
    # ShowNormal = 1,
    # ShowMinimized = 2,
    # ShowMaximized = 3,
    # Maximize = 3,
    # ShowNormalNoActivate = 4,
    # Show = 5,
    # Minimize = 6,
    # ShowMinNoActivate = 7,
    # ShowNoActivate = 8,
    # Restore = 9,
    # ShowDefault = 10,
    # ForceMinimized = 11

    If (-Not ($Global:ConsoleWndHidden)) {
        $consolePtr = [Console.Window]::GetConsoleWindow()
        [void][Console.Window]::ShowWindow($consolePtr, 0)
        $Global:ConsoleWndHidden = $True
    }
}

#
# Function : Show-Console
#
Function Show-Console
{
    # Hide = 0,
    # ShowNormal = 1,
    # ShowMinimized = 2,
    # ShowMaximized = 3,
    # Maximize = 3,
    # ShowNormalNoActivate = 4,
    # Show = 5,
    # Minimize = 6,
    # ShowMinNoActivate = 7,
    # ShowNoActivate = 8,
    # Restore = 9,
    # ShowDefault = 10,
    # ForceMinimized = 11

    If ($Global:ConsoleWndHidden) {
        $consolePtr = [Console.Window]::GetConsoleWindow()
        [void][Console.Window]::ShowWindow($consolePtr, 4)
        $Global:ConsoleWndHidden = $False
    }
}


#
# Function : Minimize-Console
# Minimize console window
#
Function Minimize-Console
{
    # Hide = 0,
    # ShowNormal = 1,
    # ShowMinimized = 2,
    # ShowMaximized = 3,
    # Maximize = 3,
    # ShowNormalNoActivate = 4,
    # Show = 5,
    # Minimize = 6,
    # ShowMinNoActivate = 7,
    # ShowNoActivate = 8,
    # Restore = 9,
    # ShowDefault = 10,
    # ForceMinimized = 11

    If (-Not ($Global:ConsoleWndHidden)) {      
        $consolePtr = [Console.Window]::GetConsoleWindow()
        [void][Console.Window]::ShowWindow($consolePtr, 2)
        #[void][Console.Window]::ShowWindow($consolePtr, 6)
        $Global:ConsoleWndHidden = $True
    }
}
#EndRegion


#Region Form handling
#
# Function : Show-BusyDlg
# Show a GUI Windows Form with a provided message
#
Function Show-BusyDlg {
    Param(
		[Parameter(Mandatory=$False)]
        [String]$Message = "Working..."
    )

	# example code to show the "Busy Form" :
	#[System.Windows.Forms.Form]$busyFrm = Show-BusyDlg -Message "Some Busy Form Demo..."
    #If ($busyFrm) {
    #    $busyFrm.Close()
    #    $busyFrm.Dispose()
    #    $busyFrm = $Null
    #}
	
	[System.Drawing.Rectangle]$screenSize = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
	
    # Create a Windows WinForm
    $busyForm = New-Object -TypeName System.Windows.Forms.Form
    [System.Windows.Forms.Application]::EnableVisualStyles() 
    $busyForm.Text = $Message
    #$busyForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
	$busyForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
	#$busyForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
	$busyForm.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $busyForm.ControlBox = $False
    #$busyForm.MaximizeBox = $False
    #$busyForm.MinimizeBox = $False    
    #$busyForm.KeyPreview = $True
	$busyForm.Width = 550
    $busyForm.Height = 60
	$busyForm.Top = $screenSize.Height - $busyForm.Height - 50
    $busyForm.Left = $screenSize.Width - $busyForm.Width - 50
    $busyForm.TopLevel = $True
	$busyForm.BackColor = [System.Drawing.Color]::BlueViolet

    # Message Label
    $lblMsg = New-Object System.Windows.Forms.Label
    $lblMsg.AutoSize = $False
    $lblMsg.Width = $busyForm.ClientSize.Width - 5
    $lblMsg.Height = 24
    #$lblMsg.Location = New-Object System.Drawing.Point(5, ($busyForm.Height / 2) - ($lblMsg.Height / 2))
    $lblMsg.Left = 5
    $lblMsg.Top = (($busyForm.ClientSize.Height / 2) - ($lblMsg.Height / 2))
    $lblMsg.Font = New-Object System.Drawing.Font('Verdana', 10, [System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
    $lblMsg.ForeColor = [System.Drawing.Color]::Yellow
    $lblMsg.Text = $Message
    $busyForm.Controls.Add($lblMsg)

    # Busy Form Event(s)
    $busyForm.Add_Shown({ $lblMsg.Text = $Message })
	$busyForm.Add_Close({ $lblMsg.Dispose() })

    # Show the Busy Form
    $busyForm.Show()

    # Force redraw of Busy Form
    $busyForm.Refresh()
    #$busyForm.Invalidate()
    #$lblMsg.Invalidate()

    # wait a moment to give time for GDI+ to refresh the Windows Form drawing process
    Start-Sleep -Milliseconds 10

    Return $busyForm
}


#
# Function : Show-Form
# Show Form object
#
Function Show-Form {
	Param(
		[Parameter(Mandatory=$True)]
		[System.Windows.Forms.Form]$FormObject
	)
		
	If ($Null -ne $FormObject) {
		If (-Not ($Global:FormShown)) {
			Try {
				Rng-Title
				
				$Global:FormShown = $True
				[void]$FormObject.ShowDialog()
				#[void]$FormObject.Show()
			
				# This makes the form pop up
				[void]$FormObject.Activate()				
			} Catch {
			}
		}
	}
}


#
# Function : Hide-Form
# Hide Form object
#
Function Hide-Form {
	Param(
		[Parameter(Mandatory=$True)]
		[System.Windows.Forms.Form]$FormObject
	)
		
	If ($Null -ne $FormObject) {
		If ($Global:FormShown) {
			[void]$FormObject.Hide()
			$Global:FormShown = $False
		}
	}
}


#
# Function : Exit-Form
# Close Form object
#
Function Exit-Form {
	Param(
		[Parameter(Mandatory=$True)]
		[System.Windows.Forms.Form]$FormObject
	)
		
	If ($Null -ne $FormObject) {
		If ($Global:FormShown) {
			[void]$FormObject.Close()
			$Global:FormShown = $False
		}		
	}
}


#
# Function : Exit-App
# Quit the main loop
#
Function Exit-App {
	$Global:Active = $False
}
#EndRegion



#Region Graphics
#
# Function : Rng-Color
# Generates random RGB Color object
#
Function Rng-Color {
    [Byte]$r = [Byte](Get-Random -Minimum 0 -Maximum 255)
    [Byte]$g = [Byte](Get-Random -Minimum 0 -Maximum 255)
    [Byte]$b = [Byte](Get-Random -Minimum 0 -Maximum 255)
	[System.Drawing.Color]$rngColor = [System.Drawing.Color]::FromArgb($r, $g, $b)
	Return $rngColor
}
#EndRegion


#Region Time Calulations
#
# Global Function : Reset-GameTime
# Reset the loop
#
Function Reset-GameTime {
	$Global:TimeBegin = (Get-Date)
}


#
# Global Function : Get-GameTimeElapsed
# Get Game Time Elapsed in Minutes
#
Function Get-GameTimeElapsed {
	Return ([Math]::Round((New-TimeSpan -Start $Global:TimeBegin -End (Get-Date)).TotalMinutes, 0))
}


#
# Global Function : Calc-GameTimeExpired
# Calc if game time has Expired
#
Function Calc-GameTimeExpired {
	If ($Null -ne $Global:Config) {
		[UInt32]$hours = ([UInt32]($Global:Config.KidsSafeGuardAfter.Hours)) * 60
		[UInt32]$minutes = ([UInt32]($Global:Config.KidsSafeGuardAfter.Minutes))

		# 15 min up-front notification that game time will expire soon
		If ( ($(Get-GameTimeElapsed) -ge 10) -And ($Global:Config.Locker.NotifyKidsBeforeExpire) ){
			[System.Windows.Forms.Form]$gametimeWarnFrm = Show-BusyDlg -Message "  Game time will almost expire!"
			Start-Sleep -Seconds 10
			If ($gametimeWarnFrm) {
			    $gametimeWarnFrm.Close()
			    $gametimeWarnFrm.Dispose()
			    $gametimeWarnFrm = $Null
			}
		}
		
		# Game time expired?
		If ($(Get-GameTimeElapsed) -ge ($hours + $minutes)) {
			Write-Log -Msg "Elapsed : True"
			Write-Log -Msg "Config  - Min : $(($hours + $minutes).ToString())"
			Write-Log -Msg "Elapsed - Min : $((Get-GameTimeElapsed).ToString())"
		
			# Game time has expired!
			Show-Form -FormObject $Global:Form
		} Else {
			#Write-Log -Msg "Elapsed : False"
		}
	}
}


#
# Global Function : TimerAction
# Timer loop
#
Function Global:TimerAction {
	If ($Null -ne $Global:Form) {
		If ($Global:FormShown) {
			$lblTitle = $Global:Form.Controls | Where-Object {$_.Name -like "lblTitle"}

			# Change text color
			If ($Null -ne $lblTitle) {
				$lblTitle.ForeColor = Rng-Color
			}
		} Else {
			# Calc Time expired
			Calc-GameTimeExpired
		}
	}
}
#EndRegion


#Region Button Events
#
# Function : Defer-GameTime
# A child can press a number of times the "Defer (+5m)" button.
# This way, they can extend the time they need.
#
Function Defer-GameTime {
	Param(
		[Parameter(Mandatory=$False)]
		[UInt32]$Minutes = 5
	)
	
	Write-Log -Msg "Pressed button to defer +$($Minutes)m."
	Write-Log -Msg "Number of defer times : $(($Global:TimesDefer).ToString())"
	
	# First, reset timer, or it will expire immediately!
	Reset-GameTime
	
	# (default) Give 5 minutes extra time
	$Global:Config.KidsSafeGuardAfter.Hours = 0
	$Global:Config.KidsSafeGuardAfter.Minutes = $Minutes
	
	# Increase defer counter
	$Global:TimesDefer += (1)
	
	# Hide form
	Hide-Form -FormObject $Global:Form
	
	# remove Defer button after n-times presses
	If ($Global:TimesDefer -ge $Global:Config.KidsSafeGuardAfter.DeferCount) {
		Write-Log -Msg "Reached defer limit, remove button."
		$btnDefer = $Global:Form.Controls | Where-Object {$_.Name -like "btnDefer"}

		# Hide Defer button
		If ($Null -ne $btnDefer) {
			$btnDefer.Visible = $False
		}
	}
	
	# sync and make timer 'accurate'
	Reset-GameTime
}


#
# Function : SuperDefer-GameTime
# A parent can press "Defer (+1h)" button.
# This is a "super defer" that gives +1h.
#
Function SuperDefer-GameTime {
	Defer-GameTime -Minutes 60
	Lock-PINCode
	
	# we reset the defer count :)
	$Global:TimesDefer -= (1)
	
	# Hide form
	Hide-Form -FormObject $Global:Form
}

#
# Function : Show-PINCode
#
Function Show-PINCode {
	Write-Log -Msg "Pressed button to try unlocking."
	$txtPINCode = $Global:Form.Controls | Where-Object {$_.Name -like "txtPINCode"}

	If ($Null -ne $txtPINCode) {
		If (-Not ($txtPINCode.Visible)) {
			$txtPINCode.Visible = $True
			$txtPINCode.Focus()
		}
	}
}


#
# Function : Verify-PINCode
#
Function Verify-PINCode {	
	$txtPINCode = $Global:Form.Controls | Where-Object {$_.Name -like "txtPINCode"}

	If ($Null -ne $txtPINCode) {
		If ($txtPINCode.Text.Count -gt 0) {
			If ($txtPINCode.Text -eq $Global:Config.Locker.ParentalPIN) {
				Write-Log -Msg "Verify PIN : SUCCESS"
				$txtPINCode.Visible = $False
				
				# Switch Unlock to Lock and Defer to SuperDefer buttons.
				# Show Shutdown and Exit (Disable Guard) buttons.
				$btnUnlock = $Global:Form.Controls | Where-Object {$_.Name -like "btnUnlock"}
				$btnLock = $Global:Form.Controls | Where-Object {$_.Name -like "btnLock"}
				$btnDefer = $Global:Form.Controls | Where-Object {$_.Name -like "btnDefer"}
				$btnDefer = $Global:Form.Controls | Where-Object {$_.Name -like "btnDefer"}
				$btnSuperDefer = $Global:Form.Controls | Where-Object {$_.Name -like "btnSuperDefer"}
				$btnShutdown = $Global:Form.Controls | Where-Object {$_.Name -like "btnShutdown"}
				$btnExit = $Global:Form.Controls | Where-Object {$_.Name -like "btnExit"}
				$btnReset = $Global:Form.Controls | Where-Object {$_.Name -like "btnReset"}
				
				$btnUnlock.Visible = $False
				$btnLock.Visible = $True
				$btnDefer.Visible = $False
				$btnSuperDefer.Visible = $True
				$btnShutdown.Visible = $True
				$btnExit.Visible = $True
				$btnReset.Visible = $True
			} Else {
				Write-Log -Msg "Verify PIN : FAILED"
				$txtPINCode.BackColor = [System.Drawing.Color]::DarkRed				
			}			
		}
	}
}


#
# Function : Lock-PINCode
#
Function Lock-PINCode {
	Write-Log -Msg "Pressed button to lock."
	# Switch Lock to Unlock and SuperDefer to Defer buttons.
	# Hide Shutdown and Exit (Disable Guard) buttons.
	$btnUnlock = $Global:Form.Controls | Where-Object {$_.Name -like "btnUnlock"}
	$btnLock = $Global:Form.Controls | Where-Object {$_.Name -like "btnLock"}
	$btnDefer = $Global:Form.Controls | Where-Object {$_.Name -like "btnDefer"}
	$btnDefer = $Global:Form.Controls | Where-Object {$_.Name -like "btnDefer"}
	$btnSuperDefer = $Global:Form.Controls | Where-Object {$_.Name -like "btnSuperDefer"}
	$btnShutdown = $Global:Form.Controls | Where-Object {$_.Name -like "btnShutdown"}
	$btnExit = $Global:Form.Controls | Where-Object {$_.Name -like "btnExit"}
	$btnReset = $Global:Form.Controls | Where-Object {$_.Name -like "btnReset"}
	
	$btnUnlock.Visible = $True
	$btnLock.Visible = $False
	$btnDefer.Visible = $True
	$btnSuperDefer.Visible = $False
	$btnShutdown.Visible = $False
	$btnExit.Visible = $False
	$btnReset.Visible = $False
}


#
# Function : Disable-Guard
#
Function Disable-Guard {
	Write-Log -Msg "Pressed button to disable guard (exit)."
	
	# Run down utility
	Exit-Form -FormObject $Global:Form
	Exit-App
}


#
# Function : Reset-Guard
#
Function Reset-Guard {
	Write-Log -Msg "Pressed button to reset."
	
	# First, reset timer, or it will expire immediately!
	Reset-GameTime
	
	# reload original config
	Load-ScriptConfig
	
	# sync and make timer 'accurate'
	Reset-GameTime
	
	# lock and hide
	Lock-PINCode
	
	# Hide form
	Hide-Form -FormObject $Global:Form
}

#
# Function : Rng-Title
#
Function Rng-Title {
	[String[]]$arrTitles = @("Ooops, Play Time Has Expired !!!", "Play Time Has Expired !!!", "You will have to stop gaming !!!", "Nooooo, EXPIRED TIME!!!", "STOP GAMING !!!", "No more ... GAMES !!!")
	[Byte]$iRngIndex = [Byte](Get-Random -Minimum 0 -Maximum $arrTitles.Length)
	
	$lblTitle = $Global:Form.Controls | Where-Object {$_.Name -like "lblTitle"}

	If ($Null -ne $lblTitle) {
		$lblTitle.Text = $arrTitles[$iRngIndex]
	}
}
#EndRegion




#Region Main Function
#
# Function : Main
# C-Style main function
#
Function Main {
    Param(
        [String[]]$Arguments
    )
	
	# Delete old log file
	If (Test-Path -Path $Global:LogFile.Replace(".log", ".log.bck")) {
        Remove-Item -Path $($Global:LogFile.Replace(".log", ".log.bck")) -Force -Confirm:$false -ErrorAction SilentlyContinue
    }
	
	# Swap out old log file
    If (Test-Path -Path $Global:LogFile) {
        Rename-Item -Path $Global:LogFile -NewName $($Global:LogFile.Replace(".log", ".log.bck")) -Force -Confirm:$false -ErrorAction SilentlyContinue
    }
	
	# Write some info who we are
	Write-Log -Msg ""
	Write-Log -Msg "========================="
	Write-Log -Msg "Child PC Locker utility"
	Write-Log -Msg "========================="
	Write-Log -Msg ""
	
	# Load Config
	Load-ScriptConfig
	
	# Parse config verbose output and debug mode
	If ($Null -ne $Global:Config) {
        [Bool]::TryParse($Global:Config.Script.Verbose, [ref]$Global:VerboseMode) | Out-Null
        [Bool]::TryParse($Global:Config.Script.Debug, [ref]$Global:DebugMode) | Out-Null
	}
	
	# Process script CLI args, override settings if needed
    If ($Arguments) {
        For ($i = 0; $i -lt $args.Length; $i++) {
           Switch ($Arguments[$i]) {
                "-verbose" {
                    $Global:VerboseMode = $True
                }
				
				"-debug" {
                    $Global:DebugMode = $True
                }
            }
        }
    }

	# Hide or Minimize Console Window
	If ($Global:DebugMode) {
		Minimize-Console
	} Else {
		Hide-Console
	}

	# Create a background timer (Timers.Timer) - seems not to process unless you press (generate) events manually!
	#[System.Timers.Timer]$timer = New-Object -TypeName System.Timers.Timer
	#$timer.Interval = 30000 # 30 seconds
	#$action = { TimerAction }
	#Register-ObjectEvent -InputObject $timer -EventName elapsed -SourceIdentifier thetimer -Action $action | Out-Null
	#$timer.Start()
	
	# Create a background timer (Forms.Timer) - back to the good old default Forms Timer then...
	Write-Log -Msg "[i] Init timer"
	[System.Windows.Forms.Timer]$timer = New-Object -TypeName System.Windows.Forms.Timer
	$timer.Interval = 150	
	$timer.Add_Tick({ TimerAction })
	$timer.Start()

	# Get primary screen bounds
	Write-Log -Msg "[i] Checking screen"
	[System.Drawing.Rectangle]$screenSize = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
		
	# Create a Windows Primary WinForm
	Write-Log -Msg "[i] Init form"
	#[System.Windows.Forms.Form]$Global:Form = New-Object -TypeName System.Windows.Forms.Form
	$Global:Form = New-Object -TypeName System.Windows.Forms.Form
	[System.Windows.Forms.Application]::EnableVisualStyles()
	$Global:Form.Text = "Windows PC Locker"
	$Global:Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
	$Global:Form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
	$Global:Form.ControlBox = $False
	$Global:Form.MaximizeBox = $False
	$Global:Form.MinimizeBox = $False
	$Global:Form.ShowInTaskbar = $False  # hide in taskbar!
	$Global:Form.KeyPreview = $True
	$Global:Form.Top = 0
	$Global:Form.Left = 0
	$Global:Form.Width = $screenSize.Width
	$Global:Form.Height = $screenSize.Height
	$Global:Form.BackColor = [System.Drawing.Color]::Black

	If (-Not ($Global:DebugMode)) {
		$Global:Form.TopMost = $True
	}
	
	# Load Form icon, default Powershell icon (depends on current Powershell shell version)
	[String]$iconFile = "$($PSHOME)\powershell.exe"
	If (-not (Test-Path -Path "$($PSHOME)\powershell.exe")) {
		[String]$iconFile = "$($PSHOME)\pwsh.exe"
	}

	[System.Drawing.Icon]$Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($iconFile)
	$Global:Form.Icon = $Icon

	# Title Label
	[System.Windows.Forms.Label]$lblTitle = New-Object System.Windows.Forms.Label
	$lblTitle.Text = "Ooops, Play Time Has Expired !!!"
	$lblTitle.AutoSize = $True
	$lblTitle.Width = 640
	$lblTitle.Height = 42
	#$lblTitle.Size = "300,22"
	#$lblTitle.Location  = New-Object System.Drawing.Point(13,15)
	$lblTitle.Top = ($Global:Form.ClientSize.Height / 2) - ($lblTitle.Height / 2)
	$lblTitle.Left = ($Global:Form.ClientSize.Width / 2) - ($lblTitle.Width / 2)
	#$lblTitle.Font = New-Object System.Drawing.Font('Microsoft Sans Serif', 24, [System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
	$lblTitle.Font = New-Object System.Drawing.Font('Verdana', 24, [System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
	#$lblTitle.ForeColor = [System.Drawing.Color]::DarkOrange
	$lblTitle.ForeColor = Rng-Color
	$lblTitle.Name = "lblTitle"
	$Global:Form.Controls.Add($lblTitle)
	
	
	# Defer Button (gives extra 5 minutes)
	[System.Windows.Forms.Button]$btnDefer = New-Object System.Windows.Forms.Button
	$btnDefer.Visible = $True
	#$btnDefer.Size = "200,42"
	$btnDefer.Width = 200
	$btnDefer.Height = 42
	#$btnDefer.Location = New-Object System.Drawing.Point($Global:Form.ClientSize.Width - 30, $Global:Form.ClientSize.Height - 30)
	$btnDefer.Top = $lblTitle.Top + $lblTitle.Height + 30
	$btnDefer.Left = $lblTitle.Left
	$btnDefer.ForeColor = [System.Drawing.Color]::White
	$btnDefer.BackColor = [System.Drawing.Color]::Blue
	$btnDefer.Font = New-Object System.Drawing.Font('Verdana', 10,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
	$btnDefer.Text = "DEFER (+5m)"
	$btnDefer.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
	$btnDefer.FlatAppearance.BorderColor = $btnDefer.BackColor
	$btnDefer.FlatAppearance.BorderSize = 0
	$btnDefer.Name = "btnDefer"
	$btnDefer.Add_Click({ Defer-GameTime })
	$Global:Form.Controls.Add($btnDefer)
	
	
	# Parental Super Defer Button (gives extra 60 minutes - shows when pressing UNLOCK)
	[System.Windows.Forms.Button]$btnSuperDefer = New-Object System.Windows.Forms.Button
	$btnSuperDefer.Visible = $False
	#$btnSuperDefer.Size = "200,42"
	$btnSuperDefer.Width = 200
	$btnSuperDefer.Height = 42
	#$btnSuperDefer.Location = New-Object System.Drawing.Point($Global:Form.ClientSize.Width - 30, $Global:Form.ClientSize.Height - 30)
	$btnSuperDefer.Top = $lblTitle.Top + $lblTitle.Height + 30
	$btnSuperDefer.Left = $lblTitle.Left
	$btnSuperDefer.ForeColor = [System.Drawing.Color]::White
	$btnSuperDefer.BackColor = [System.Drawing.Color]::DarkOrange
	$btnSuperDefer.Font = New-Object System.Drawing.Font('Verdana', 10,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
	$btnSuperDefer.Text = "DEFER (+1h)"
	$btnSuperDefer.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
	$btnSuperDefer.FlatAppearance.BorderColor = $btnSuperDefer.BackColor
	$btnSuperDefer.FlatAppearance.BorderSize = 0
	$btnSuperDefer.Name = "btnSuperDefer"
	$btnSuperDefer.Add_Click({ SuperDefer-GameTime })
	$Global:Form.Controls.Add($btnSuperDefer)
	
	
	# Unlock Button
	[System.Windows.Forms.Button]$btnUnlock = New-Object System.Windows.Forms.Button
	$btnUnlock.Visible = $True
	#$btnUnlock.Size = "200,42"
	$btnUnlock.Width = 200
	$btnUnlock.Height = 42
	#$btnUnlock.Location = New-Object System.Drawing.Point(($lblTitle.Left + $lblTitle.Width) - $btnUnlock.Width, $lblTitle.Top + $lblTitle.Height + 30)
	$btnUnlock.Top = $lblTitle.Top + $lblTitle.Height + 30
	$btnUnlock.Left = ($lblTitle.Left + $lblTitle.Width) - $btnUnlock.Width
	$btnUnlock.ForeColor = [System.Drawing.Color]::White
	$btnUnlock.BackColor = [System.Drawing.Color]::Blue
	$btnUnlock.Font = New-Object System.Drawing.Font('Verdana', 10, [System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
	$btnUnlock.Text = "UNLOCK"
	$btnUnlock.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
	$btnUnlock.FlatAppearance.BorderColor = $btnUnlock.BackColor
	$btnUnlock.FlatAppearance.BorderSize = 0
	$btnUnlock.Name = "btnUnlock"
	$btnUnlock.Add_Click({ Show-PINCode })
	$Global:Form.Controls.Add($btnUnlock)
	
	
	# Parental Lock Button
	[System.Windows.Forms.Button]$btnLock = New-Object System.Windows.Forms.Button
	$btnLock.Visible = $False
	#$btnLock.Size = "200,42"
	$btnLock.Width = 200
	$btnLock.Height = 42
	#$btnLock.Location = New-Object System.Drawing.Point(($lblTitle.Left + $lblTitle.Width) - $btnLock.Width, $lblTitle.Top + $lblTitle.Height + 30)
	$btnLock.Top = $lblTitle.Top + $lblTitle.Height + 30
	$btnLock.Left = ($lblTitle.Left + $lblTitle.Width) - $btnLock.Width
	$btnLock.ForeColor = [System.Drawing.Color]::White
	$btnLock.BackColor = [System.Drawing.Color]::DarkOrange
	$btnLock.Font = New-Object System.Drawing.Font('Verdana', 10, [System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
	$btnLock.Text = "LOCK"
	$btnLock.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
	$btnLock.FlatAppearance.BorderColor = $btnLock.BackColor
	$btnLock.FlatAppearance.BorderSize = 0
	$btnLock.Name = "btnLock"
	$btnLock.Add_Click({ Lock-PINCode })
	$Global:Form.Controls.Add($btnLock)
	
	
	# Parental PIN code txt input (shows when pressing UNLOCK)
	[System.Windows.Forms.TextBox]$txtPINCode = New-Object System.Windows.Forms.TextBox
	$txtPINCode.Visible = $False
	$txtPINCode.MaxLength = 8
    $txtPINCode.PasswordChar = '*'
	$txtPINCode.Location = New-Object System.Drawing.Point(480,35)
	$txtPINCode.Top = $btnDefer.Top + $btnDefer.Height + 30
	$txtPINCode.Left = $btnUnlock.Left
	$txtPINCode.AutoSize = $False
	$txtPINCode.Width = $btnUnlock.Width
	$txtPINCode.ForeColor = [System.Drawing.Color]::White
	$txtPINCode.BackColor = [System.Drawing.Color]::Blue
	$txtPINCode.Size = New-Object System.Drawing.Size(200,22)
	$txtPINCode.Font = New-Object System.Drawing.Font('Verdana', 10, [System.Drawing.FontStyle]([System.Drawing.FontStyle]::Regular))
	$txtPINCode.Name = "txtPINCode"
	$txtPINCode.Add_KeyDown({ If ($_.KeyCode -eq "Enter") { Verify-PINCode } })
	$Global:Form.Controls.Add($txtPINCode)
	
	
	# Parental Shutdown Button (Shuts down PC)
	[System.Windows.Forms.Button]$btnShutdown = New-Object System.Windows.Forms.Button
	$btnShutdown.Visible = $False
	#$btnShutdown.Size = "200,42"
	$btnShutdown.Width = 200
	$btnShutdown.Height = 42
	#$btnShutdown.Location = New-Object System.Drawing.Point($btnDefer.Left, $btnDefer.Top + $btnDefer.Height + 30)
	$btnShutdown.Top = $btnDefer.Top + $btnDefer.Height + 30
	$btnShutdown.Left = $btnDefer.Left
	$btnShutdown.ForeColor = [System.Drawing.Color]::White
	$btnShutdown.BackColor = [System.Drawing.Color]::Blue
	$btnShutdown.Font = New-Object System.Drawing.Font('Verdana', 10, [System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
	$btnShutdown.Text = "Shutdown PC"
	$btnShutdown.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
	$btnShutdown.FlatAppearance.BorderColor = $btnShutdown.BackColor
	$btnShutdown.FlatAppearance.BorderSize = 0
	$btnShutdown.Name = "btnShutdown"
	$btnShutdown.Add_Click({ Write-Log -Msg "Pressed button to shutdown."; Try { $(Stop-Computer -Force); Exit-App } Catch { Write-Log -Msg "[!] Failed to shutdown PC!" } })
	
	If (-Not (Is-Admin)) {
		# Disable button if the current user account is not entitled to reboot the machine!
		$btnShutdown.Enabled = $False
	}
	
	$Global:Form.Controls.Add($btnShutdown)
	

	# Parental Exit Button (Disable Guard / Quit's App)
	[System.Windows.Forms.Button]$btnExit = New-Object System.Windows.Forms.Button
	$btnExit.Visible = $False
	#$btnExit.Size = "200,42"
	$btnExit.Width = 200
	$btnExit.Height = 42
	#$btnExit.Location = New-Object System.Drawing.Point(($btnShutdown.Left + $btnShutdown.Width) - $btnExit.Width, $btnUnlock.Top + $btnUnlock.Height + 30)
	$btnExit.Top = $btnUnlock.Top + $btnUnlock.Height + 30
	$btnExit.Left = $btnUnlock.Left
	$btnExit.ForeColor = [System.Drawing.Color]::White
	$btnExit.BackColor = [System.Drawing.Color]::Blue
	$btnExit.Font = New-Object System.Drawing.Font('Verdana', 10, [System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
	$btnExit.Text = "Disable Guard"
	$btnExit.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
	$btnExit.FlatAppearance.BorderColor = $btnExit.BackColor
	$btnExit.FlatAppearance.BorderSize = 0
	$btnExit.Name = "btnExit"
	$btnExit.Add_Click({ Disable-Guard })
	$Global:Form.Controls.Add($btnExit)
	
	
	# Parental Reset Button
	[System.Windows.Forms.Button]$btnReset = New-Object System.Windows.Forms.Button
	$btnReset.Visible = $False
	#$btnReset.Size = "200,42"
	$btnReset.Width = (($btnDefer.Left + $btnDefer.Width) - $btnUnlock.Left) + ($btnDefer.Width + $btnUnlock.Width) * 2 + 28
	$btnReset.Height = 42
	#$btnReset.Location = New-Object System.Drawing.Point(($btnShutdown.Left + $btnShutdown.Width) - $btnReset.Width, $btnUnlock.Top + $btnUnlock.Height + 30)
	$btnReset.Top = $btnShutdown.Top + $btnShutdown.Height + 30
	$btnReset.Left = $btnShutdown.Left
	$btnReset.ForeColor = [System.Drawing.Color]::White
	$btnReset.BackColor = [System.Drawing.Color]::Blue
	$btnReset.Font = New-Object System.Drawing.Font('Verdana', 10, [System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
	$btnReset.Text = "Reset Timer"
	$btnReset.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
	$btnReset.FlatAppearance.BorderColor = $btnReset.BackColor
	$btnReset.FlatAppearance.BorderSize = 0
	$btnReset.Name = "btnReset"
	$btnReset.Add_Click({ Reset-Guard })
	$Global:Form.Controls.Add($btnReset)
	
	
	# Intercept key strokes send to Form
	$Global:Form.Add_KeyDown({
		Param([System.Object]$Sender, [System.Windows.Forms.KeyEventArgs]$e)

		# KeyCode is a enum of type [System.Windows.Forms.Keys]
		Switch($_.KeyCode) {
			# Escape to quit only works in debug mode!
			"Escape" { If ($Global:DebugMode) {$Global:Form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; Exit-Form -FormObject $Global:Form; Exit-App } }
		}
		
		# Intercept ALT+F4 press
		If (($_.Alt -eq $True) -and ($_.KeyCode -eq 'F4')) {
			$Script:AltF4Pressed = $True
		}
	})
	
	
	# Intercept and Abort ALT+F4 keypress to try and close the Form/App
	$Global:Form.Add_Closing({
		Param([System.Object]$Sender, [System.Windows.Forms.FormClosingEventArgs]$e)
		
		If ($Script:AltF4Pressed) {
			If ($e.CloseReason -eq 'UserClosing') {
				$e.Cancel = $True
				$Script:AltF4Pressed = $False
			}
		} Else {
			#Exit-App
		}
	})
	
	
	# -- TESTING CASES
	#Show-Form -FormObject $Global:Form
	#
	#[System.Windows.Forms.Form]$busyFrm = Show-BusyDlg -Message "Game time will almost expire!"
	#Start-Sleep -Seconds 5	
    #If ($busyFrm) {
    #    $busyFrm.Close()
    #    $busyFrm.Dispose()
    #    $busyFrm = $Null
    #}
	# -- TESTING CASES
	
	
	# ---
	
	# Keep waiting for when the Form object is NOT in ShowDialog() mode
	Write-Log -Msg "[i] Ready!"
	Do {
		[System.Windows.Forms.Application]::DoEvents()
		Start-Sleep -Milliseconds 150
	} While($Global:Active)
	
	# ---
	
	# Stop the timer after From closes
	$timer.Stop()
	#Unregister-Event thetimer (only needed for Timers.Timer)

	# Cleanup memory
	$timer.Dispose()
	$lblTitle.Dispose()
	$btnDefer.Dispose()
	$btnSuperDefer.Dispose()
	$btnUnlock.Dispose()
	$btnLock.Dispose()
	$txtPINCode.Dispose()
	$btnShutdown.Dispose()
	$btnExit.Dispose()
	$btnReset.Dispose()
	$Global:Form.Dispose()
	
	# show console
	If ($Global:DebugMode) {
		Show-Console
	}
	
	Write-Log -Msg "--END"

	# Gracefully exit
	Exit(0)
}
#EndRegion


# -- call main function ---
Main -arguments $args
