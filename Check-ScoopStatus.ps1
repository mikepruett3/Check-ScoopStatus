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
    Creates a scheduled task to run script every 6 hours...

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
        Write-Verbose "Getting setup to create Scheduled Task..."
        $Arguments = "-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -File Check-ScoopStatus.ps1"
        $TaskName = "Check-ScoopStatus"
        $TaskDescription = "Checks for updates to either Scoop or Applications"
        $TaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $Arguments -WorkingDirectory $PSScriptRoot
        $TaskTrigger = New-ScheduledTaskTrigger -Once -At 12pm -RepetitionInterval (New-TimeSpan -Hours 6)
        $TaskSettings = New-ScheduledTaskSettingsSet -Hidden 
    }
    process {
        Write-Verbose "Creating Scheduled Task..."
        try { Register-ScheduledTask  -Action $TaskAction -Trigger $TaskTrigger -Settings $TaskSettings -TaskName $TaskName -Description $TaskDescription -Force *> $Null }
        catch {
            Write-Error "Unable to create Scheduled Task!!!"
            Break
        }
    }
    end {
        Write-Verbose "Cleaning up after creating Scheduled Task..."
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
        Write-Verbose "Getting setup to remove Scheduled Task..."
        $TaskName = "Check-ScoopStatus"
    }
    process {
        Write-Verbose "Removing Scheduled Task..."
        try { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$False *> $Null }
        catch {
            Write-Error "Unable to remove Scheduled Task!!!"
            Break
        }
    }
    end {
        Write-Verbose "Cleaning up after removing Scheduled Task..."
        Clear-Variable -Name TaskName -Scope Global -ErrorAction SilentlyContinue
    }
}

function Check-ScoopStatus {
    begin {
        Write-Verbose "Running scoop update, to fetch the latest updates from scoop"
        try { Invoke-Command -ScriptBlock {scoop update} *> $Null }
        catch {
            Write-Error "Unable to update scoop buckets!!!"
            Break
        }

        Write-Verbose "Create Background Job to capture output from scoop status"
        try { $StatusJob = Start-Job -ScriptBlock { scoop status } }
        catch {
            Write-Error "Unable to check scoop status!!!"
            Break
        }
        
    }
    process {
        Write-Verbose "Wait for Backgroup Job to finish"
        try { Wait-Job $StatusJob -ErrorAction SilentlyContinue | Out-Null }
        catch {
            Write-Error "Cannot find the status of the Background job, or job has not finished!!!"
            Break
        }
        
        Write-Verbose "Create a new event for BurntToast, displaying the output of scoop status"
        # https://github.com/Windos/BurntToast
        # Borrowed icon from https://github.com/lukesampson/scoop/issues/2261
        if ( $StatusJob.ChildJobs.Output -ne $Null ) {
            New-BurntToastNotification -AppLogo $PSScriptRoot\logo.png -Text "Scoop Updates Avaliable: `n $($StatusJob.ChildJobs.Output)"
        } #else {
        #    New-BurntToastNotification -AppLogo $PSScriptRoot\logo.png -Text "Scoop is up to date."
        #}
    }
    end {
        Write-Verbose "Stop and Remove any left-over jobs"
        Stop-Job -State Running -ErrorAction SilentlyContinue
        Remove-Job -State Stopped -ErrorAction SilentlyContinue
        Remove-Job -State Completed -ErrorAction SilentlyContinue
        Write-Verbose "Cleaning up after checking status..."
        Clear-Variable -Name StatusJob -Scope Global -ErrorAction SilentlyContinue
    }
}

switch -wildcard ($PSBoundParameters.Keys) {
    Install { Create-ScheduledTask; Break }
    Uninstall { Delete-ScheduledTask; Break }
    Default {}
}

Check-ScoopStatus
