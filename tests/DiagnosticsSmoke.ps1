param([string]$OutputDirectory='build')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $project 'scripts\Common.psm1') -Force -DisableNameChecking
$package=Join-Path $project $OutputDirectory
$fixture=Join-Path $project ('reports\diagnostic-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
Add-Type -Path (Join-Path $package 'SofaRelay.Core.dll')
$settings=[SofaRelay.CenterSettings]::new()
$settings.InstallRoot=Join-Path $fixture 'runtime'
$settings.PlaynitePath=Join-Path $fixture 'no-library'
$settings.SunshineDirectory=''
$path=Join-Path $fixture 'settings.json'
[SofaRelay.Data]::Write($path,$settings)
$result=Join-Path $fixture 'result.json'
& (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $package 'scripts\Worker.ps1') -Action Diagnostics -SettingsPath $path -DataRoot $fixture -PackageRoot $package -ResultPath $result
if($LASTEXITCODE){throw 'Actual Diagnostics action failed.'}
$response=Read-Json $result
if(!$response.Success){throw 'Diagnostic export did not complete.'}
$json=[IO.File]::ReadAllText($response.Data.File)
$export=$json | ConvertFrom-Json
foreach($name in @([Environment]::UserName,[Environment]::MachineName)) {
    if($name -and $json -match ('(?i)\b'+[regex]::Escape($name)+'\b')){throw 'A current account/machine name leaked into the export.'}
}
if($json -match '(?i)[A-Z]:[\\/]|\\\\|\b(?:\d{1,3}\.){3}\d{1,3}\b|Bearer\s+\S+|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}') {throw 'A private path, address, email or credential leaked into the export.'}
foreach($key in @('Accounts','HostAddresses','ComputerName','UserName','PlaynitePath','SunshineDirectory','Settings','Token')){if($export.PSObject.Properties[$key]){throw ('Forbidden diagnostic field: '+$key)}}
if($export.Schema -ne 1 -or !$export.PSObject.Properties['GPU']){throw 'Unexpected diagnostic schema.'}
Write-Host 'PASS actual Diagnostics action: allowlisted export contains no account/machine name, path, address or account fields.'
