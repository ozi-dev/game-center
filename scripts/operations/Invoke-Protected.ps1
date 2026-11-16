function Invoke-Protected {
    param([string]$NextAction)
    # Elevate a hash-bound executable, never a user-writable PowerShell script.
    $result = Join-Path $Settings.InstallRoot ('data\broker-result-'+[guid]::NewGuid().ToString('N')+'.json')
    $arguments = @('--broker-action',$NextAction,'--config',$SettingsPath,'--broker-result',$result)
    $null = Start-CheckedProcess (Join-Path $PackageRoot 'SofaRelay.exe') $arguments -SuccessCodes @(0,1)
    $response = Read-Json $result
    if(!$response -or !$response.Success) {
        if($response) { throw $response.Message }
        throw 'The protected broker did not complete. Review Windows consent and package integrity.'
    }
    # Only the unelevated caller writes user settings and watchdog files.
    if($NextAction -eq 'ProtectedApply') {
        $Settings.DisplayId=$response.Data.DisplayId
        Write-Json $SettingsPath $Settings
        Write-Json (Join-Path $Settings.InstallRoot 'data\settings.json') $Settings
        Write-Json (Join-Path $Settings.InstallRoot 'data\display-baseline.json') $response.Data.DisplayBaseline
        $flag=Join-Path $Settings.InstallRoot 'data\watchdog-enabled.json'
        if($response.Data.RecoveryWatchdog) {
            Write-Json $flag @{Enabled=$true}
            $task=@(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {$_.TaskName -like 'SofaRelay Recovery *' -and $_.Actions.Arguments -like ('*'+$Settings.InstallRoot+'*')})
            foreach($item in $task){Start-ScheduledTask -InputObject $item}
        } elseif(Test-Path -LiteralPath $flag){Remove-Item -LiteralPath $flag}
    }
    if($NextAction -in @('ProtectedRestore','ProtectedUninstall')) {
        $flag=Join-Path $Settings.InstallRoot 'data\watchdog-enabled.json'
        if(Test-Path -LiteralPath $flag){Remove-Item -LiteralPath $flag}
    }
    return $response.Data
}
