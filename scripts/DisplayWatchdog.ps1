param([Parameter(Mandatory)][string]$RuntimeRoot,[switch]$Once)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Common.psm1') -Force -DisableNameChecking
Add-Type -Path (Join-Path $RuntimeRoot 'SofaRelay.Core.dll')
Add-Type -Path (Join-Path $RuntimeRoot 'SofaRelay.Native.dll')
$data = Join-Path $RuntimeRoot 'data'
$checkpointPath = Join-Path $data 'recovery-checkpoint.json'
$mutexName = 'Local\SofaRelayRecovery-' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($RuntimeRoot.ToLowerInvariant())).Replace('/','_').TrimEnd('=')
$mutex = [Threading.Mutex]::new($false,$mutexName)
if(!$mutex.WaitOne(0)) { $mutex.Dispose();exit 0 }
try {
    $checkpoint = [SofaRelay.RecoveryCheckpoint]::new()
    $saved = Read-Json $checkpointPath
    if($saved) { $checkpoint.Pending=[bool]$saved.Pending;$checkpoint.IdleSamples=0 }
    do {
        $settings = Read-Json (Join-Path $data 'settings.json')
        $flag = Join-Path $data 'watchdog-enabled.json'
        if(!$settings -or !(Test-Path -LiteralPath $flag)) { break }
        $enabled = $settings.RecoveryWatchdog -and $settings.VirtualDisplay -and $settings.TurnOffPhysicalMonitor -and $settings.RestoreDisplay
        $baseline = Read-Json (Join-Path $data 'display-baseline.json')
        if(!$enabled -or !$baseline) { break }
        $current = [NativeDisplayState]::Capture($true)
        $physical = @($baseline.Displays | Where-Object { $_.Active -and $_.Name -notmatch 'VDD|Virtual' } | ForEach-Object {$_.DevicePath})
        $present = @($current.Displays | Where-Object { $_.Active -and $_.DevicePath -in $physical })
        $missing = $physical.Count -gt 0 -and !$present.Count
        $recover = [SofaRelay.RecoveryPolicy]::Advance($checkpoint,$enabled,(Get-StreamState),$missing)
        if($recover) {
            $code = [NativeDisplayState]::Apply($baseline.PathCount,$baseline.PathsBase64,$baseline.ModeCount,$baseline.ModesBase64,$false,$true)
            if($code -eq 0) { $checkpoint.Pending=$false;$checkpoint.IdleSamples=0 }
            Write-Json (Join-Path $data 'recovery-status.json') @{Recovered=($code -eq 0);WindowsCode=$code;At=(Get-Date).ToString('o')}
        }
        [SofaRelay.Data]::Write($checkpointPath,$checkpoint)
        if(!$Once) { Start-Sleep -Seconds 5 }
    } while(!$Once)
} catch {
    Write-Json (Join-Path $data 'recovery-status.json') @{Recovered=$false;Error='Watchdog could not complete a display check. Use Restore Display or Windows display settings.';At=(Get-Date).ToString('o')}
    exit 1
} finally { $mutex.ReleaseMutex();$mutex.Dispose() }
