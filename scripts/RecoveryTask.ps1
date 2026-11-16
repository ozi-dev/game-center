function Set-RecoveryTask {
    param([bool]$Enabled)
    $identity = Read-Json (Join-Path $DataRoot 'identity.json')
    $suffix = [IO.Path]::GetFileName($DataRoot)
    $name = 'SofaRelay Recovery '+$suffix
    $inventory = Get-OwnershipInventory
    $existing = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    $script = Join-Path $Settings.InstallRoot 'scripts\DisplayWatchdog.ps1'
    $flag = Join-Path $Settings.InstallRoot 'data\watchdog-enabled.json'
    if(!$Enabled) {
        if($existing) {
            if($existing.Actions.Arguments -notlike ('*'+$script+'*')) { throw 'Recovery task ownership could not be verified.' }
            Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
            Unregister-ScheduledTask -TaskName $name -Confirm:$false
        }
        $inventory.Tasks=@()
    } else {
        if($existing -and $existing.Actions.Arguments -notlike ('*'+$script+'*')) { throw 'A task with the recovery name belongs to another application.' }
        $arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File '+(Quote-WindowsArgument $script)+' -RuntimeRoot '+(Quote-WindowsArgument $Settings.InstallRoot)
        $action = New-ScheduledTaskAction -Execute (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -Argument $arguments
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $identity.UserSid
        $principal = New-ScheduledTaskPrincipal -UserId $identity.UserSid -LogonType Interactive -RunLevel Limited
        $options = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)
        Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Principal $principal -Settings $options -Description 'Restore the saved physical display after an idle/crashed stream or at the next user sign-in.' -Force | Out-Null
        $inventory.Tasks=@([pscustomobject]@{Name=$name;Script=$script;UserSid=$identity.UserSid})
    }
    Write-Json (Join-Path $DataRoot 'ownership.json') $inventory
}
