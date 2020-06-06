<#
.SYNOPSIS
    Script to Check scoop for updates
.DESCRIPTION
    Script used to check scoop for any updates or application updates
.NOTES
    This script can be used directly, or by passing parameters can run
    as a scheduled task. Script makes a call to BurntToast to provide
    a Desktop Notification from PowerShell.

    Before running the script, install BurtToast

    > Install-Module -Name BurntToast

    You might also consider placing the script in a directory that is
    included in the $PATH.
.LINK
    https://github.com/lukesampson/scoop
    https://github.com/Windos/BurntToast
.PARAMETER Install
    Creates a scheduled task to run script every hour...

    > .\Check-ScoopStatus.ps1 -Install
.PARAMETER Uninstall
    Removes previously created scheduled task...

    > .\Check-ScoopStatus.ps1 -Uninstall
.EXAMPLE
    > .\Check-ScoopStatus.ps1
#>

Param (
    [Parameter(Mandatory=$false)]
    [Switch]
    $Install,
    [Parameter(Mandatory=$false)]
    [Switch]
    $Uninstall
)

function Create-ScheduledTask {
    param (
    )
    begin {
        $Arguments = "-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -File Check-ScoopStatus.ps1"
        $TaskName = "Check-ScoopStatus"
        $TaskDescription = "Checks for updates to either Scoop or Applications"
        $TaskAction =   New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Arguments -WorkingDirectory $PSScriptRoot
        $TaskTrigger =  New-ScheduledTaskTrigger -Once -At 12pm -RepetitionInterval (New-TimeSpan -Minutes 60)
        $TaskSettings = New-ScheduledTaskSettingsSet -Hidden 
    }
    process {
        try { Register-ScheduledTask  -Action $TaskAction -Trigger $TaskTrigger -Settings $TaskSettings -TaskName $TaskName -Description $TaskDescription -Force }
        catch {
            Write-Error "Unable to create Scheduled Task!!!"
            Break
        }
    }
    end {
        Clear-Variable -Name Arguments -Scope Global -ErrorAction SilentlyContinue
        Clear-Variable -Name TaskName -Scope Global -ErrorAction SilentlyContinue
        Clear-Variable -Name $TaskDescription -Scope Global -ErrorAction SilentlyContinue
        Clear-Variable -Name TaskAction -Scope Global -ErrorAction SilentlyContinue
        Clear-Variable -Name TaskTrigger -Scope Global -ErrorAction SilentlyContinue
    }
}

function Delete-ScheduledTask {
    param (
    )
    begin {
        $TaskName = "Check-ScoopStatus"
    }
    process {
        try { Unregister-ScheduledTask -TaskName "Check-ScoopStatus" -Confirm:$False }
        catch {
            Write-Error "Unable to remove Scheduled Task!!!"
            Break
        }
        
    }
    end {
        Clear-Variable -Name TaskName -Scope Global -ErrorAction SilentlyContinue
    }
}

function Check-ScoopStatus {
    begin {
        # Create Background Job to capture output from scoop status
        Invoke-Command -ScriptBlock {scoop update} *> $Null
        $StatusJob = Start-Job -ScriptBlock { scoop status }
    }
    process {
        # Wait for Backgroup Job to finish
        Wait-Job $StatusJob -ErrorAction SilentlyContinue | Out-Null
        # Create a new event for BurntToast, displaying the output of scoop status
        # https://github.com/Windos/BurntToast
        # Borrowed icon from https://github.com/lukesampson/scoop/issues/2261
        if ( $StatusJob.ChildJobs.Output -ne $Null ) {
            New-BurntToastNotification -AppLogo $PSScriptRoot\logo.png -Text "Scoop Updates Avaliable: `n $($StatusJob.ChildJobs.Output)"
        } else {
            New-BurntToastNotification -AppLogo $PSScriptRoot\logo.png -Text "Scoop is up to date."
        }
    }
    end {
        # Stop and Remove any left-over jobs
        Stop-Job -State Running
        Remove-Job -State Stopped
        Remove-Job -State Completed
        # Cleanup Variables
        Clear-Variable -Name StatusJob -Scope Global -ErrorAction SilentlyContinue
    }
}

switch -wildcard ($PSBoundParameters.Keys) {
    Install { Create-ScheduledTask; Break }
    Uninstall { Delete-ScheduledTask; Break }
    Default {}
}

Check-ScoopStatus
