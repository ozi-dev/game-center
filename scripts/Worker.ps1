param(
 [ValidateSet('Diagnose','Install','CoreOnly','Apply','InstallClients','InstallRetroArch','ProtectedApply','Restore','ProtectedRestore','ConnectDevice','InstallMoonlight','Recover','Diagnostics','AccountGuide','TotkProfile')][string]$Action='Diagnose',
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
Add-Type -Path (Join-Path $PackageRoot 'GamingCenter.Core.dll')
Add-Type -AssemblyName System.Web.Extensions
$selectedLanguage=if($Settings.PSObject.Properties['UILanguage']){$Settings.UILanguage}else{''};[OyunMerkezi.I18n]::Initialize($PackageRoot,$selectedLanguage)
function Assert-Settings {
    $json=Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8
    $serializer=[Web.Script.Serialization.JavaScriptSerializer]::new()
    $value=$serializer.Deserialize($json,[OyunMerkezi.CenterSettings])
    $errors=[OyunMerkezi.Validation]::Settings($value)
    if($errors.Count){throw ($errors -join "`n")}
    if(!$Settings.InstallRoot){throw (L 'Kurulum klasörü seçilmedi.')}
    $architecture=if($env:PROCESSOR_ARCHITEW6432){$env:PROCESSOR_ARCHITEW6432}else{$env:PROCESSOR_ARCHITECTURE}
    if($architecture -ne 'AMD64'){throw (L 'Bu paket Intel/AMD x64 Windows içindir. ARM64 ve 32 bit Windows otomatik kurulumu desteklenmiyor.')}
}
function Assert-PlayniteClosed {
    if(Get-Process Playnite.DesktopApp,Playnite.FullscreenApp -ErrorAction SilentlyContinue){throw (L 'Playnite açık. Menüsünden Çıkış seçip bu adımı yeniden çalıştırın; oyunlarınız zorla kapatılmadı.')}
}
function Initialize-Runtime {
    $target=Resolve-Full $Settings.InstallRoot
    if($target -eq [IO.Path]::GetPathRoot($target)){throw (L 'Sürücü kökü kurulum klasörü olarak kullanılamaz.')}
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    if($target.TrimEnd('\') -ne $PackageRoot.TrimEnd('\')){
        foreach($name in @('OyunMerkezi.exe','GamingCenter.Core.dll','scripts','assets','locales','manifests','docs','README.html','LICENSE.txt','THIRD-PARTY.md')){
            $source=Join-Path $PackageRoot $name;if(Test-Path -LiteralPath $source){$destination=Join-Path $target $name;if((Get-Item $source).PSIsContainer){New-Item -ItemType Directory -Force -Path $destination | Out-Null;Copy-Item -Path (Join-Path $source '*') -Destination $destination -Recurse -Force}else{Copy-Item -LiteralPath $source -Destination $destination -Force}}
        }
    }
    $destination=Join-Path $target 'data\settings.json';Write-Json $destination $Settings
    return $target
}
function Install-Addon([string]$Id,[string]$Folder,[string]$Playnite) {
    $archive=Get-Component $Id $PackageRoot $DataRoot
    $destination=Join-Path $Playnite ('Extensions\'+$Folder)
    Expand-ZipSafe $archive $destination
}
function Install-PlayniteCore {
    Assert-Settings;Assert-PlayniteClosed
    $root=Initialize-Runtime
    $play=$Settings.PlaynitePath
    if(!$play){$play=Join-Path $root 'Playnite'}
    $play=Resolve-Full $play
    if(!(Test-Path (Join-Path $play 'Playnite.DesktopApp.exe'))){
        $archive=Get-Component 'playnite' $PackageRoot $DataRoot
        New-Item -ItemType Directory -Force -Path $play | Out-Null
        $seven=Join-Path $PackageRoot 'assets\tools\7zip\7za.exe'
        [void](Start-CheckedProcess $seven @('x',$archive,('-o'+$play),'-y','-bso0','-bsp0'))
        if(!(Test-Path (Join-Path $play 'Playnite.DesktopApp.exe'))){throw (L 'Playnite arşivi beklenen programı içermiyor.')}
        if((Get-AuthenticodeSignature (Join-Path $play 'Playnite.DesktopApp.exe')).Status -ne 'Valid'){throw (L 'Playnite imzası doğrulanamadı.')}
    }
    $version=[Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $play 'Playnite.DesktopApp.exe'))
    if($version.FileMajorPart -lt 10 -or ($version.FileMajorPart -eq 10 -and $version.FileMinorPart -lt 64)){throw (L 'Playnite 10.64 veya üstü gerekiyor. Mevcut Playnite ana menüsünden güncellemeyi tamamlayıp tekrar deneyin; oyun kütüphaneniz değiştirilmedi.')}
    $Settings.PlaynitePath=$play
    $playData=Get-PlayniteDataDirectory $play;New-Item -ItemType Directory -Force -Path $playData | Out-Null
    $db=Join-Path $playData 'library';$snapshot=Join-Path $DataRoot 'backups\playnite-before-setup'
    if((Test-Path $db) -and !(Test-Path $snapshot)){New-Item -ItemType Directory -Force -Path $snapshot | Out-Null;Get-ChildItem $db -File -Filter *.db | Copy-Item -Destination $snapshot}
    Write-Host (L 'Playnite ve seçili kütüphane eklentileri hazırlanıyor.')
    Install-Addon 'igdb' 'IGDBMetadata_Builtin' $playData
    foreach($library in $Settings.Libraries){switch($library){
        Steam {Install-Addon 'steam' 'SteamLibrary_Builtin' $playData}
        Epic {
            if($Settings.EpicDirectInstall){
                Install-Addon 'legendary-plugin' 'LegendaryLibrary' $playData;Install-Addon 'udm' 'UnifiedDownloadManager' $playData
                $cli=Get-Component 'legendary-cli' $PackageRoot $DataRoot
                New-Item -ItemType Directory -Force -Path (Join-Path $root 'araclar') | Out-Null
                Copy-Item -LiteralPath $cli -Destination (Join-Path $root 'araclar\legendary.exe') -Force
                $dir=Join-Path $playData 'ExtensionsData\ead65c3b-2f8f-4e37-b4e6-b3de6be540c6';$file=Join-Path $dir 'config.json';$c=Read-Json $file
                if(!$c){$c=[pscustomobject]@{ConnectAccount=$false;ImportInstalledGames=$true;ImportUninstalledGames=$true;ImportUbisoftLauncherGames=$false;ImportEALauncherGames=$false;SelectedFullLauncherPath='';GamesInstallationPath='';UnattendedInstall=$true}}
                foreach($entry in @{SelectedFullLauncherPath=(Join-Path $root 'araclar\legendary.exe');GamesInstallationPath=(Join-Path $root 'Games\Epic');UnattendedInstall=$true}.GetEnumerator()){$c | Add-Member -NotePropertyName $entry.Key -NotePropertyValue $entry.Value -Force}
                if(Test-Path $file){[void](Backup-File $file $DataRoot)};Write-Json $file $c;Mark-Applied $file $DataRoot;New-Item -ItemType Directory -Force -Path (Join-Path $root 'Games\Epic') | Out-Null
            }else{Install-Addon 'epic' 'EpicGamesLibrary_Builtin' $playData}
        }
        EA {Install-Addon 'ea' 'OriginLibrary_Builtin' $playData}
        Ubisoft {Install-Addon 'ubisoft' 'UplayLibrary_Builtin' $playData}
        Xbox {Install-Addon 'xbox' 'XboxLibrary_Builtin' $playData}
    }}
    Set-LibraryImportOptions $Settings $playData $DataRoot
    $plugin=Join-Path $playData 'Extensions\GamingCenter';New-Item -ItemType Directory -Force -Path $plugin | Out-Null
    $legacy=Join-Path $playData 'Extensions\OziTvTools'
    if(Test-Path (Join-Path $legacy 'extension.yaml')){$plugin=$legacy}
    Copy-Item -Path (Join-Path $PackageRoot 'assets\plugin\*') -Destination $plugin -Recurse -Force
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'araclar') | Out-Null
    Copy-Item -LiteralPath (Join-Path $PackageRoot 'assets\plugin\SteamTvInstall.exe') -Destination (Join-Path $root 'araclar\SteamTvInstall.exe') -Force
    Write-Json (Join-Path $plugin 'center-integration.json') @{SettingsPath=(Join-Path $root 'data\settings.json');RuntimeRoot=$root;SettingsApp=(Join-Path $root 'OyunMerkezi.exe')}
    $config=Join-Path $playData 'fullscreenConfig.json';$full=Read-Json $config
    if(!$full){$full=[pscustomobject]@{}}
    if(Test-Path $config){[void](Backup-File $config $DataRoot)}
    foreach($entry in @{HideMouserCursor=(!$Settings.MouseKeyboard);ShowGameTitles=$true;EnableGameControllerSupport=$Settings.Gamepad;EnableMainBackgroundImage=$false;DarkenUninstalledGamesGrid=$true}.GetEnumerator()){$full | Add-Member -NotePropertyName $entry.Key -NotePropertyValue $entry.Value -Force}
    Write-Json $config $full;Mark-Applied $config $DataRoot
    $appConfig=Join-Path $playData 'config.json';$app=Read-Json $appConfig;if(!$app){$app=[pscustomobject]@{}}
    if(!$app.PSObject.Properties['DatabasePath'] -or !$app.DatabasePath){$app | Add-Member -NotePropertyName DatabasePath -NotePropertyValue (Join-Path $playData 'library') -Force}
    if(Test-Path $appConfig){[void](Backup-File $appConfig $DataRoot)}
    foreach($entry in @{Language=([OyunMerkezi.I18n]::PlayniteLanguage($selectedLanguage));FirstTimeWizardComplete=$true;AccessibilityInterface=1;CloseToTray=$false;DownloadMetadataOnImport=$true;CheckForLibraryUpdates=1;CheckForEmulatedLibraryUpdates=1}.GetEnumerator()){$app | Add-Member -NotePropertyName $entry.Key -NotePropertyValue $entry.Value -Force}
    Write-Json $appConfig $app;Mark-Applied $appConfig $DataRoot
    $setup=Join-Path $playData 'Extensions\GamingCenterSetup';New-Item -ItemType Directory -Force -Path $setup | Out-Null
    Copy-Item -LiteralPath (Join-Path $PackageRoot 'scripts\NativeSetup.psm1') -Destination (Join-Path $setup 'NativeSetup.psm1') -Force
    @'
Id: GamingCenterSetup_e8bd5521-67bd-4600-a757-fbc0e93b385d
Name: Oyun Merkezi Library Setup
Author: Oyun Merkezi
Version: 2.1.0
Module: NativeSetup.psm1
Type: Script
'@ | Set-Content -LiteralPath (Join-Path $setup 'extension.yaml') -Encoding UTF8
    Write-Json (Join-Path $setup 'setup.json') @{SettingsPath=(Join-Path $root 'data\settings.json');ReportPath=(Join-Path $root 'data\library-setup.json')}
    Write-Json (Join-Path $root 'data\settings.json') $Settings;Write-Json $SettingsPath $Settings
    if($NoShortcuts){return [pscustomobject]@{InstallRoot=$root;PlaynitePath=$play;SettingsPath=(Join-Path $root 'data\settings.json');App=(Join-Path $root 'OyunMerkezi.exe')}}
    $menu=Join-Path ([Environment]::GetFolderPath('Programs')) 'Oyun Merkezi';New-Item -ItemType Directory -Force -Path $menu | Out-Null
    $wsh=New-Object -ComObject WScript.Shell
    foreach($definition in @(@{Name='Oyun Merkezi';Target=(Join-Path $play 'Playnite.FullscreenApp.exe');Args='--startfullscreen --hidesplashscreen'},@{Name=(L 'Oyun Merkezi Ayarları');Target=(Join-Path $root 'OyunMerkezi.exe');Args='--settings'},@{Name=(L 'Ekranı Geri Getir');Target=(Join-Path $root 'OyunMerkezi.exe');Args='--recover'})){
        $link=$wsh.CreateShortcut((Join-Path $menu ($definition.Name+'.lnk')));$link.TargetPath=$definition.Target;$link.Arguments=$definition.Args;$link.WorkingDirectory=$root;if($definition.Args -eq '--recover'){$link.Hotkey='CTRL+ALT+F11'};$link.Save()
    }
    return [pscustomobject]@{InstallRoot=$root;PlaynitePath=$play;SettingsPath=(Join-Path $root 'data\settings.json');App=(Join-Path $root 'OyunMerkezi.exe')}
}
function Install-StoreClients {
    $winget=Get-Command winget.exe -ErrorAction SilentlyContinue
    if(!$winget){throw (L 'WinGet bulunamadı. Yardım sayfasındaki App Installer bağlantısını açıp kurun; ardından Eksikleri kur düğmesini yeniden kullanın.')}
    $ids=@{Steam='Valve.Steam';Epic='EpicGames.EpicGamesLauncher';EA='ElectronicArts.EADesktop';Ubisoft='Ubisoft.Connect';Xbox='Microsoft.GamingApp'}
    foreach($source in $Settings.Libraries){
        if(!$ids.ContainsKey($source)){continue}
        if($source -eq 'Epic' -and $Settings.EpicDirectInstall){continue}
        Write-Host (L '{0} başlatıcısı denetleniyor.' @(($source)))
        try {
            $p=[Diagnostics.ProcessStartInfo]::new();$p.FileName=$winget.Source;$p.Arguments='install --id '+$ids[$source]+' --exact --silent --accept-source-agreements --accept-package-agreements --disable-interactivity';$p.UseShellExecute=$false;$p.CreateNoWindow=$true;$process=[Diagnostics.Process]::Start($p);$process.WaitForExit()
            if($process.ExitCode -notin @(0,-1978335189)){throw (L 'Kurulum kodu {0}' @($process.ExitCode))}
        }catch{throw (L '{0} otomatik kurulamadı. Yardım → Başlatıcı bağlantısından resmi kurucuyu çalıştırıp bu adımı tekrar deneyin. {1}' @(($source),($_.Exception.Message)))}
    }
}
function Invoke-Protected([string]$NextAction) {
    if(Is-Admin){if($NextAction -eq 'ProtectedRestore'){return Restore-Protected};return Apply-Protected}
    $result=Join-Path $DataRoot ('admin-'+[guid]::NewGuid().ToString('N')+'.json')
    $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath,'-Action',$NextAction,'-SettingsPath',$SettingsPath,'-DataRoot',$DataRoot,'-PackageRoot',$PackageRoot,'-ResultPath',$result)
    $command=($args | ForEach-Object {Quote-WindowsArgument $_}) -join ' '
    try {$p=Start-Process -FilePath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -Verb RunAs -ArgumentList $command -WindowStyle Hidden -PassThru -Wait}catch{throw (L 'Windows yönetici istemi onaylanmadı; Sunshine ve sürücü ayarları uygulanmadı. Uygula düğmesinden yeniden deneyebilirsiniz.')}
    $data=Read-Json $result
    if(!$data -or !$data.Success){if($data){throw $data.Message}else{throw (L 'Yönetici işlemi sonuç üretmedi. Tanı günlüğünü açın.')}}
    return $data.Data
}
function Save-DisplayBaseline {
    $file=Join-Path $DataRoot 'display-baseline.json'
    Add-Type -Path (Join-Path $PackageRoot 'assets\native\DisplayState.cs')
    $state=[NativeDisplayState]::Capture($true)
    if($Settings.TurnOffPhysicalMonitor -and !@($state.Displays | Where-Object {$_.Active -and $_.Name -notmatch 'VDD|Virtual'}).Count){throw (L 'Şu anda yalnız sanal ekran aktif. Fiziksel ekran düzenine dönüp yeniden uygulayın. Fiziksel monitörü olmayan bilgisayarda monitör kapatma seçeneğini kapatın.')}
    Write-Json $file $state
}
function Apply-Protected {
    if(!(Is-Admin)){throw (L 'Bu işlem Windows yönetici onayı gerektiriyor.')}
    Assert-Settings;Assert-StreamIdle
    $framework=Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue
    if(!$framework -or $framework -lt 528040){throw (L '.NET Framework 4.8 gerekiyor. Yardım > Gereksinimler bölümündeki resmi Microsoft kurucusunu çalıştırıp yeniden deneyin.')}
    foreach($architecture in @('x64','x86')){
        $runtime=Get-ItemProperty ('HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\'+$architecture) -ErrorAction SilentlyContinue
        if(!$runtime){$runtime=Get-ItemProperty ('HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\'+$architecture) -ErrorAction SilentlyContinue}
        if(!$runtime -or $runtime.Installed -ne 1){$winget=Get-Command winget.exe -ErrorAction SilentlyContinue;if(!$winget){throw (L 'Visual C++ çalışma zamanı eksik. Yardım > Gereksinimler bölümünden x64 ve x86 paketlerini kurun veya App Installer kurup yeniden deneyin.')};[void](Start-CheckedProcess $winget.Source @('install','--id',('Microsoft.VCRedist.2015+.'+$architecture),'--exact','--silent','--accept-source-agreements','--accept-package-agreements','--disable-interactivity') -SuccessCodes @(0,3010,-1978335189))}
    }
    $root=Resolve-Full $Settings.InstallRoot;$reboot=$false
    $sun=Get-SunshineDirectory
    if(!$sun){
        Write-Host (L 'Sunshine kuruluyor.');$msi=Get-Component 'sunshine' $PackageRoot $DataRoot
        if((Get-AuthenticodeSignature -LiteralPath $msi).Status -ne 'Valid'){throw (L 'Sunshine kurucusunun imzası doğrulanamadı.')}
        $code=Start-CheckedProcess (Join-Path $env:WINDIR 'System32\msiexec.exe') @('/i',$msi,'/qn','/norestart');if($code -in @(3010,1641)){$reboot=$true}
        $sun=Get-SunshineDirectory;if(!$sun){throw (L 'Sunshine kurulduktan sonra bulunamadı; bilgisayarı yeniden başlatıp Tanı çalıştırın.')}
    }
    $Settings.SunshineDirectory=$sun
    $vdd=@(Get-PnpDevice -Class Display -PresentOnly | Where-Object {$_.FriendlyName -match 'Virtual Display|VDD by|IddSample'})
    Save-DisplayBaseline
    if($Settings.Gamepad -and !@(Get-PnpDevice -PresentOnly | Where-Object {$_.InstanceId -like 'ROOT\VIGEMBUS*' -or $_.FriendlyName -match 'Virtual Gamepad Emulation Bus|ViGEmBus|Nefarius.*Virtual HID'}).Count){
        Write-Host (L 'Kumanda sürücüsü kuruluyor.');$exe=Get-Component 'vigem' $PackageRoot $DataRoot
        if((Get-AuthenticodeSignature $exe).Status -ne 'Valid'){throw (L 'ViGEmBus kurucusunun imzası doğrulanamadı.')}
        $code=Start-CheckedProcess $exe @('/install','/quiet','/norestart');if($code -in @(3010,1641)){$reboot=$true}
    }
    if($Settings.VirtualDisplay -and !$vdd.Count){
        if((Resolve-Full $Settings.VddDirectory).TrimEnd('\') -ne 'C:\VirtualDisplayDriver'){throw (L 'Yeni VDD kurulumu için sürücünün standart C:\VirtualDisplayDriver klasörünü seçin. Başka klasör seçimi zaten kurulu sürücünün gerçek ayar konumu içindir.')}
        $archive=Get-Component 'vdd' $PackageRoot $DataRoot;$unpack=Join-Path $DataRoot 'staging\vdd';Expand-ZipSafe $archive $unpack
        $cat=Get-ChildItem $unpack -Recurse -Filter mttvdd.cat | Select-Object -First 1
        if(!$cat -or (Get-AuthenticodeSignature $cat.FullName).Status -ne 'Valid'){throw (L 'Sanal ekran sürücüsünün imzası doğrulanamadı.')}
        $driverDir=Resolve-Full $Settings.VddDirectory
        if(Test-Path (Join-Path $driverDir 'MttVDD.inf')){throw (L 'Eski sürücü klasörü var ancak aygıt görünmüyor. Tanı sayfasından sürücüyü kontrol edin; dosyalar üzerine kurulmadı.')}
        New-Item -ItemType Directory -Force -Path $driverDir | Out-Null
        Copy-Item -Path (Join-Path $cat.Directory.FullName '*') -Destination $driverDir -Force
        Add-Type -Path (Join-Path $PackageRoot 'assets\native\InstallVdd.cs')
        $installed=[NativeVddInstall]::Install((Join-Path $driverDir 'MttVDD.inf'))
        if($installed -match 'RebootRequired=True'){$reboot=$true}
        Write-Json (Join-Path $DataRoot 'installed-driver.json') @{Instance=$installed;InstalledByThisPackage=$true}
        $baseline=Read-Json (Join-Path $DataRoot 'display-baseline.json')
        [void][NativeDisplayState]::Apply($baseline.PathCount,$baseline.PathsBase64,$baseline.ModeCount,$baseline.ModesBase64,$false,$true)
    }
    if($Settings.VirtualDisplay){
        $file=Join-Path (Resolve-Full $Settings.VddDirectory) 'vdd_settings.xml'
        if(Test-Path $file){[void](Backup-File $file $DataRoot);$xml=[xml](Get-Content $file -Raw -Encoding UTF8)}else{$xml=[xml]'<vdd_settings><monitors><count>1</count></monitors><gpu><friendlyname></friendlyname></gpu><global><g_refresh_rate>60</g_refresh_rate></global><resolutions></resolutions><options><HardwareCursor>true</HardwareCursor><HDRPlus>false</HDRPlus></options></vdd_settings>'}
        if($xml.DocumentElement.Name -ne 'vdd_settings'){throw (L 'Bu VDD ayar biçimi farklı. Sürücünün kendi yöneticisinde çözünürlüğü ekleyip Tanı ile yeniden kontrol edin.')}
        $resolutions=$xml.SelectSingleNode('/vdd_settings/resolutions');if(!$resolutions){throw (L 'VDD çözünürlük bölümü bulunamadı. Sürücünün kendi yöneticisinde modu ekleyin.')}
        $wanted=@(@{w=1920;h=1080;hz=60},@{w=2560;h=1440;hz=60},@{w=3840;h=2160;hz=60},@{w=$Settings.Width;h=$Settings.Height;hz=$Settings.RefreshRate})
        foreach($mode in $wanted){
            $found=@($xml.SelectNodes('/vdd_settings/resolutions/resolution') | Where-Object {[int]$_.width -eq $mode.w -and [int]$_.height -eq $mode.h -and [int]$_.refresh_rate -eq $mode.hz})
            if(!$found.Count){$node=$xml.CreateElement('resolution');foreach($k in @('width','height','refresh_rate')){$e=$xml.CreateElement($k);$e.InnerText=[string]$(if($k -eq 'width'){$mode.w}elseif($k -eq 'height'){$mode.h}else{$mode.hz});[void]$node.AppendChild($e)};[void]$resolutions.AppendChild($node);$reboot=$true}
        }
        $xml.Save($file);Mark-Applied $file $DataRoot
        $devices=@(Get-SunshineDisplays $sun)
        if(!$Settings.DisplayId){$candidate=@($devices | Where-Object {$_.friendly_name -match 'VDD|Virtual|IddSample'});if($candidate.Count -eq 1){$Settings.DisplayId=$candidate[0].device_id}}
        if(!$Settings.DisplayId){
            Restart-Service SunshineService
            for($i=0;$i -lt 16;$i++){Start-Sleep -Milliseconds 500;$devices=@(Get-SunshineDisplays $sun);$candidate=@($devices | Where-Object {$_.friendly_name -match 'VDD|Virtual|IddSample'});if($candidate.Count -eq 1){$Settings.DisplayId=$candidate[0].device_id;break}}
        }
        if(!$Settings.DisplayId){throw (L 'Sanal ekranın Sunshine kimliği bulunamadı. Tanı sayfasından ekranları yenileyip aygıtı seçin; gerekirse önce Windows sistemini yeniden başlatın.')}
        if(!@($devices | Where-Object device_id -eq $Settings.DisplayId).Count){throw (L 'Seçilen ekran bu bilgisayarda bulunamadı. Ekran listesinden yeniden seçin.')}
    }
    $config=Join-Path $sun 'config\sunshine.conf';$appsFile=Join-Path $sun 'config\apps.json'
    [void](Backup-File $config $DataRoot);[void](Backup-File $appsFile $DataRoot)
    $values=[ordered]@{keyboard=$(if($Settings.MouseKeyboard){'enabled'}else{'disabled'});mouse=$(if($Settings.MouseKeyboard){'enabled'}else{'disabled'});controller=$(if($Settings.Gamepad){'enabled'}else{'disabled'});dd_config_revert_on_disconnect=$(if($Settings.RestoreDisplay){'enabled'}else{'disabled'})}
    if($Settings.VirtualDisplay){$values.output_name=$Settings.DisplayId;$values.dd_configuration_option=if($Settings.TurnOffPhysicalMonitor){'ensure_only_display'}else{'ensure_primary'}}else{$values.output_name='';$values.dd_configuration_option='disabled'}
    $values.dd_resolution_option=if($Settings.AutomaticDisplayMode){'auto'}else{'manual'};$values.dd_refresh_rate_option=if($Settings.AutomaticDisplayMode){'auto'}else{'manual'}
    $values.dd_manual_resolution=[string]$Settings.Width+'x'+$Settings.Height;$values.dd_manual_refresh_rate=[string]$Settings.RefreshRate
    $old=if(Test-Path $config){[IO.File]::ReadAllText($config)}else{''};if($old -notmatch '(?m)^\s*gamepad_driver\s*='){$values.gamepad_driver='vigembus'};$new=Set-ConfValues $old $values
    $apps=Read-Json $appsFile;if(!$apps){$apps=[pscustomobject]@{env=[pscustomobject]@{};apps=@()}}
    $managed=@('Oyun Kütüphanesi - Playnite','Oyun Merkezi','Masaüstü - Desktop','Desktop','Game Library - Playnite','Bibliothèque - Playnite','Bureau','Biblioteca - Playnite','Escritorio')
    $retained=@();if($Settings.PreserveExistingApps){$retained=@($apps.apps | Where-Object {$_.name -notin $managed})}
    if($Settings.ShowDesktop){$retained+=@([pscustomobject]@{name=(L 'Masaüstü - Desktop');'image-path'=(Join-Path $root 'assets\desktop.png')})}
    if($Settings.ShowLibrary){$retained+=@([pscustomobject]@{name=(L 'Oyun Kütüphanesi - Playnite');cmd=('"'+(Join-Path $Settings.PlaynitePath 'Playnite.FullscreenApp.exe')+'" --startfullscreen --hidesplashscreen');'working-dir'=$Settings.PlaynitePath;'auto-detach'=$true;'wait-all'=$true;'image-path'=(Join-Path $root 'assets\library.png')})}
    $apps.apps=$retained
    [IO.File]::WriteAllText($config,$new,[Text.UTF8Encoding]::new($false));Write-Json $appsFile $apps
    Mark-Applied $config $DataRoot;Mark-Applied $appsFile $DataRoot
    Write-Json $SettingsPath $Settings;Write-Json (Join-Path $root 'data\settings.json') $Settings
    Restart-Service SunshineService
    return @{Applications=@($retained.name);DisplayId=$Settings.DisplayId;VirtualDisplay=$Settings.VirtualDisplay;PhysicalMonitorOff=$Settings.TurnOffPhysicalMonitor;Width=$Settings.Width;Height=$Settings.Height;RefreshRate=$Settings.RefreshRate;ClientSettingsRequired=$true;RebootRequired=$reboot}
}
function Restore-Protected {
    if(!(Is-Admin)){throw (L 'Windows yönetici onayı gerekiyor.')}
    Assert-StreamIdle
    $journal=Read-Json (Join-Path $DataRoot 'backup-journal.json');if(!$journal){throw (L 'Geri alınacak yedek bulunamadı.')}
    $restored=@();$groups=$journal.Entries | Group-Object Target
    foreach($group in $groups){
        $first=$group.Group | Select-Object -First 1;$last=$group.Group | Select-Object -Last 1
        if(!(Test-Path $first.Backup)){throw (L 'Yedek dosyası eksik.')}
        if((Get-FileHash $first.Backup).Hash -ne $first.OriginalSha256){throw (L 'Yedek dosyasının özeti değişmiş; geri alma durduruldu.')}
        if($last.AppliedSha256 -and (Test-Path $last.Target) -and (Get-FileHash $last.Target).Hash -ne $last.AppliedSha256){throw (L '{0} kurulumdan sonra değiştirilmiş. Üzerine yazılmadı; yedeği inceleyin.' @(($last.Target)))}
    }
    foreach($group in $groups){
        $first=$group.Group | Select-Object -First 1
        Copy-Item -LiteralPath $first.Backup -Destination $first.Target -Force;$restored+=@($first.Target)
    }
    if(Get-Service SunshineService -ErrorAction SilentlyContinue){Restart-Service SunshineService}
    return @{Restored=$restored;DriverUninstalled=$false}
}
function Recover-Display {
    Add-Type -Path (Join-Path $PackageRoot 'assets\native\DisplayState.cs')
    $state=Read-Json (Join-Path $DataRoot 'display-baseline.json');if(!$state){throw (L 'Henüz bir fiziksel ekran yedeği yok. Önce Yayın ayarlarını uygulayın.')}
    $code=[NativeDisplayState]::Apply($state.PathCount,$state.PathsBase64,$state.ModeCount,$state.ModesBase64,$false,$true)
    if($code -ne 0){throw (L 'Ekran düzeni geri getirilemedi (Windows kodu {0}). Windows ekran ayarlarında fiziksel monitörü etkinleştirin.' @(($code)))}
    return @{DisplayRestored=$true}
}
function Device-Connect {
    if(!$Settings.DeviceAddress){throw 'Shield/TV IP adresini girin.'}
    $ip=$null;if(![Net.IPAddress]::TryParse($Settings.DeviceAddress,[ref]$ip) -or $ip.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork){throw (L 'Geçerli bir IPv4 adresi girin; komut veya URL kullanmayın.')}
    $zip=Get-Component 'adb' $PackageRoot $DataRoot;$dir=Join-Path $DataRoot 'tools\adb';Expand-ZipSafe $zip $dir;$adb=Join-Path $dir 'platform-tools\adb.exe'
    $address=$Settings.DeviceAddress+':5555';$out=Start-CheckedProcess $adb @('connect',$address) -Capture
    $devices=Start-CheckedProcess $adb @('devices') -Capture
    if($devices -notmatch ([regex]::Escape($address)+'\s+device\b')){throw (L 'ADB yetkisi tamamlanmadı. Shield ekranındaki bu bilgisayara izin ver penceresini onaylayın; USB/ağ hata ayıklamasının açık olduğunu kontrol edip yeniden bağlanın.')}
    $display=Start-CheckedProcess $adb @('-s',$address,'shell','dumpsys','display') -Capture
    $modes=@([regex]::Matches($display,'width\s*[=:]\s*(\d+)\s*,?\s*height\s*[=:]\s*(\d+)\s*,?\s*(?:fps|refreshRate)\s*[=:]\s*([0-9.]+)') | ForEach-Object {[pscustomobject]@{Width=[int]$_.Groups[1].Value;Height=[int]$_.Groups[2].Value;Hz=[double]::Parse($_.Groups[3].Value,[Globalization.CultureInfo]::InvariantCulture)}} | Sort-Object Width,Height,Hz -Unique)
    $pkg=Start-CheckedProcess $adb @('-s',$address,'shell','pm','path','com.limelight') -SuccessCodes @(0,1) -Capture
    return @{Connected=$true;MoonlightInstalled=($pkg -match 'package:');Modes=$modes;ADB=$adb;Address=$address}
}
function Install-ClientMoonlight {
    $device=Device-Connect
    if(!$device.MoonlightInstalled){$apk=Get-Component 'moonlight' $PackageRoot $DataRoot;[void](Start-CheckedProcess $device.ADB @('-s',$device.Address,'install','-r',$apk))}
    [void](Start-CheckedProcess $device.ADB @('-s',$device.Address,'shell','am','start','-n','com.limelight/.PcView'))
    return @{MoonlightReady=$true;PairingRequired=$true}
}
function Set-TotkProfile {
    $emulator=$Settings.Emulators | Where-Object {$_.Kind -eq 'Switch'} | Select-Object -First 1
    if(!$emulator){throw (L 'Önce Switch emülatörünüzü Emülatörler sayfasına ekleyin.')}
    $data=[Environment]::ExpandEnvironmentVariables($emulator.DataDirectory)
    $load=Join-Path $data 'load\0100F2C0115B6000'
    $mods=@(Get-ChildItem -LiteralPath $load -Directory -ErrorAction SilentlyContinue | Where-Object {$_.Name -match '(Dynamic.?FPS|dFPS).*1\.5\.5' -and (Test-Path (Join-Path $_.FullName 'romfs\dfps'))})
    if($mods.Count -ne 1){throw (L 'Tek bir uyumlu Dynamic FPS 1.5.5 mod klasörü bulunamadı. Yardım → Oyuna özel FPS bölümünü izleyin; mod olmadan yalnız hız sınırı değiştirilmedi.')}
    $profiles=@(Get-ChildItem (Join-Path $mods[0].FullName 'romfs\dfps') -Filter zzz*.ini -File)
    $mod=if($profiles.Count -eq 1){$profiles[0].FullName}else{Join-Path $mods[0].FullName 'romfs\dfps\zzzz-gamecenter.ini'}
    if(Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($emulator.Executable)) -ErrorAction SilentlyContinue){throw (L 'Önce emülatörü tamamen kapatın.')}
    $config=Join-Path $data 'config\custom\0100F2C0115B6000.ini';[void](Backup-File $config $DataRoot);[void](Backup-File $mod $DataRoot)
    $pairs=@{'[Core]'=@{'use_speed_limit\use_global'='false';use_speed_limit=$(if($FPS -eq 60){'true'}else{'false'});'speed_limit\use_global'='false';speed_limit='100'};'[Renderer]'=@{'frame_pacing_mode\use_global'='false';frame_pacing_mode=$(if($FPS -eq 60){'2'}else{'3'});'frame_gen\use_global'='false';frame_gen='false'}}
    $text=[IO.File]::ReadAllText($config)
    foreach($section in $pairs.Keys){$pattern='(?ms)^'+[regex]::Escape($section)+'\s*\r?\n(?<body>.*?)(?=^\[|\z)';$m=[regex]::Match($text,$pattern);if(!$m.Success){throw (L 'Oyun ayar bölümü bulunamadı; değişiklik uygulanmadı.')};$body=$m.Groups['body'].Value;foreach($key in $pairs[$section].Keys){$linePattern='(?m)^'+[regex]::Escape($key)+'=.*\r?$';$line=$key+'='+$pairs[$section][$key];if([regex]::IsMatch($body,$linePattern)){$body=[regex]::Replace($body,$linePattern,[Text.RegularExpressions.MatchEvaluator]{param($m)$line})}else{$body+=$line+"`r`n"}};$text=$text.Substring(0,$m.Index)+$section+"`r`n"+$body+$text.Substring($m.Index+$m.Length)}
    $modText=if(Test-Path $mod){[IO.File]::ReadAllText($mod)}else{"[dFPS]`r`n"};$modText=[regex]::Replace($modText,'(?m)^\s*MaxFramerate\s*=.*\r?$','');$modText=$modText.TrimEnd()+"`r`nMaxFramerate = $FPS`r`n"
    [IO.File]::WriteAllText($config,$text,[Text.UTF8Encoding]::new($false));[IO.File]::WriteAllText($mod,$modText,[Text.UTF8Encoding]::new($false));Mark-Applied $config $DataRoot;Mark-Applied $mod $DataRoot
    return @{FPS=$FPS;FrameGeneration=$false}
}
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
        Restore {Assert-PlayniteClosed;Invoke-Protected 'ProtectedRestore'}
        ProtectedRestore {Restore-Protected}
        ConnectDevice {Device-Connect}
        InstallMoonlight {Install-ClientMoonlight}
        Recover {Recover-Display}
        Diagnostics {
            $diag=Get-Diagnosis $Settings;$path=Join-Path $DataRoot ('diagnostic-'+(Get-Date -Format yyyyMMdd-HHmmss)+'.json')
            Write-Json $path @{Version='2.1.0';OS=$diag.OS;Is64Bit=$diag.Is64Bit;GPU=$diag.GPU;SunshineInstalled=$diag.SunshineInstalled;VirtualDisplayInstalled=$diag.VirtualDisplayInstalled;GamepadDriverInstalled=$diag.GamepadDriverInstalled;FrameworkRelease=$diag.FrameworkRelease;PlaytimeSync=$Settings.SyncPlaytime;MouseKeyboard=$Settings.MouseKeyboard;Client=$Settings.ClientKind;RequestedMode=(@{Width=$Settings.Width;Height=$Settings.Height;Hz=$Settings.RefreshRate});Note=(L 'Hesaplar, IP, bilgisayar adı, ROM yolları ve kimlik bilgileri bu rapora alınmaz.')}
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
