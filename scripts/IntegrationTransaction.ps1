function Invoke-IntegrationTransaction {
    param([string]$Sunshine,[scriptblock]$Operation)
    $program=Join-Path $Sunshine 'sunshine.exe'
    $rules=@(Get-SofaRelayFirewallRules $program | ForEach-Object {
        @{Name=$_.Name;RemoteAddress=@(($_ | Get-NetFirewallAddressFilter).RemoteAddress);Profile=[string]$_.Profile;Enabled=[string]$_.Enabled}
    })
    $taskName='SofaRelay Recovery '+[IO.Path]::GetFileName($DataRoot)
    $task=Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    $xml=if($task){Export-ScheduledTask -InputObject $task}else{$null}
    $inventoryFile=Join-Path $DataRoot 'ownership.json'
    $inventoryBytes=if(Test-Path -LiteralPath $inventoryFile){[IO.File]::ReadAllBytes($inventoryFile)}else{$null}
    try { return (& $Operation) }
    catch {
        $failure=$_
        try {
            foreach($current in @(Get-SofaRelayFirewallRules $program)) {
                $previous=@($rules | Where-Object Name -eq $current.Name)
                if($previous.Count) { $current | Set-NetFirewallRule -RemoteAddress $previous[0].RemoteAddress -Profile $previous[0].Profile -Enabled $previous[0].Enabled }
                elseif($current.Name -like ('SofaRelay-'+[IO.Path]::GetFileName($DataRoot)+'-*')) { $current | Remove-NetFirewallRule }
            }
            if($xml) { Register-ScheduledTask -TaskName $taskName -Xml $xml -Force | Out-Null }
            elseif(Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
            if($null -ne $inventoryBytes){Write-BytesAtomic $inventoryFile $inventoryBytes}
            elseif(Test-Path -LiteralPath $inventoryFile){Remove-Item -LiteralPath $inventoryFile}
        } catch { throw ('Setup failed and task/firewall rollback needs review: '+$_.Exception.Message+'; initial error: '+$failure.Exception.Message) }
        throw $failure
    }
}
