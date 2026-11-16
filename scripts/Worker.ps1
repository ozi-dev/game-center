param(
 [ValidateSet('Diagnose','Install','CoreOnly','Apply','InstallClients','InstallRetroArch','ProtectedApply','Restore','ProtectedRestore','ProtectedUninstall','Uninstall','ConnectDevice','InstallMoonlight','Recover','Diagnostics','AccountGuide','TotkProfile')][string]$Action='Diagnose',
 [Parameter(Mandatory)][string]$SettingsPath,
 [Parameter(Mandatory)][string]$DataRoot,
 [string]$PackageRoot=(Split-Path -Parent $PSScriptRoot),
 [string]$ResultPath,
 [ValidateSet(60,90)][int]$FPS=60,
 [switch]$NoShortcuts
)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
Import-Module (Join-Path $PSScriptRoot 'Common.psm1') -Force -DisableNameChecking
$PackageRoot=Resolve-Full $PackageRoot;$DataRoot=Resolve-Full $DataRoot;$SettingsPath=Resolve-Full $SettingsPath
New-Item -ItemType Directory -Force -Path $DataRoot | Out-Null
if(!$ResultPath){$ResultPath=Join-Path $DataRoot ('result-'+$Action+'.json')}
$Settings=Read-Json $SettingsPath
if(!$Settings){throw (L 'Ayar dosyası bulunamadı. Kurulum uygulamasını yeniden açın.')}
Add-Type -Path (Join-Path $PackageRoot 'SofaRelay.Core.dll')
Add-Type -AssemblyName System.Web.Extensions
$selectedLanguage=if($Settings.PSObject.Properties['UILanguage']){$Settings.UILanguage}else{''};[SofaRelay.I18n]::Initialize($PackageRoot,$selectedLanguage)
foreach($name in @('RecoveryWatchdog','LANOnly','RemoveOwnedComponents')) { if(!$Settings.PSObject.Properties[$name]) { $Settings | Add-Member -NotePropertyName $name -NotePropertyValue ($name -ne 'RemoveOwnedComponents') } }

Import-Module (Join-Path $PSScriptRoot 'Privacy.psm1') -Force
. (Join-Path $PSScriptRoot 'ProtectedState.ps1')
. (Join-Path $PSScriptRoot 'RecoveryTask.ps1')
. (Join-Path $PSScriptRoot 'NetworkPolicy.ps1')
. (Join-Path $PSScriptRoot 'ConfigTransaction.ps1')
. (Join-Path $PSScriptRoot 'IntegrationTransaction.ps1')
$operations=Read-Json (Join-Path $PackageRoot 'manifests\runtime-operations.json')
foreach($name in $operations.Operations){if($name -notmatch '^[A-Za-z][A-Za-z0-9-]+\.ps1$'){throw 'Invalid operation name.'}; . (Join-Path $PSScriptRoot ('operations\'+$name))}
try {
    $data=switch($Action){
        Diagnose {Get-Diagnosis $Settings}
        Install {if($Settings.AutoInstallStoreClients){Install-StoreClients};$core=Install-PlayniteCore;[pscustomobject]@{Core=$core;Streaming=(Invoke-Protected 'ProtectedApply')}}
        CoreOnly {Install-PlayniteCore}
        Apply {$core=Install-PlayniteCore;[pscustomobject]@{Core=$core;Streaming=(Invoke-Protected 'ProtectedApply')}}
        InstallClients {Install-StoreClients;@{ClientsRequested=@($Settings.Libraries)}}
        InstallRetroArch {
            $winget=Get-Command winget.exe -ErrorAction SilentlyContinue;if(!$winget){throw (L 'WinGet eksik. Yardım sayfasındaki App Installer bağlantısını kullanın veya https://www.retroarch.com/?page=platforms adresinden RetroArch kurun.')}
            [void](Start-CheckedProcess $winget.Source @('install','--id','Libretro.RetroArch','--exact','--silent','--accept-source-agreements','--accept-package-agreements','--disable-interactivity') -SuccessCodes @(0,-1978335189))
            @{Next=(L 'RetroArch > Main Menu > Online Updater > Core Downloader ile uygun çekirdeği seçin; sonra Emülatör ekle düğmesinde çekirdek DLL dosyasını ve ROM klasörünüzü gösterin.')}
        }
        ProtectedApply {Apply-Protected}
        Restore {Assert-PlayniteClosed;$null=Restore-UserConfiguration -PreflightOnly;$system=Invoke-Protected 'ProtectedRestore';@{System=$system;User=(Restore-UserConfiguration)}}
        ProtectedRestore {Restore-Protected}
        ProtectedUninstall {Protected-Uninstall}
        Uninstall {Assert-PlayniteClosed;Assert-StreamIdle;$null=Restore-UserConfiguration -PreflightOnly;$system=Invoke-Protected 'ProtectedUninstall';$restored=Restore-UserConfiguration;$user=Remove-UserIntegration;@{System=$system;User=$user;UserConfiguration=$restored}}
        ConnectDevice {Device-Connect}
        InstallMoonlight {Install-ClientMoonlight}
        Recover {Recover-Display}
        Diagnostics {
            $diag=Get-Diagnosis $Settings;$path=Join-Path $DataRoot ('diagnostic-'+(Get-Date -Format yyyyMMdd-HHmmss)+'.json')
            Write-Json $path (New-DiagnosticExport $diag $Settings ([SofaRelay.I18n]::Version))
            @{File=$path}
        }
        AccountGuide {Start-Process (Join-Path $Settings.PlaynitePath 'Playnite.DesktopApp.exe') -ArgumentList '--startdesktop','--hidesplashscreen';@{ManualLoginRequired=$true}}
        TotkProfile {Set-TotkProfile}
    }
    Write-Json $ResultPath @{Success=$true;Action=$Action;Message=(L 'İşlem tamamlandı.');Data=$data}
    exit 0
}catch{
    Write-Json $ResultPath @{Success=$false;Action=$Action;Message=$_.Exception.Message;Data=$null}
    Write-Output $_.Exception.Message
    exit 1
}
