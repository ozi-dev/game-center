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
        Assert-PackageSignature 'playnite' (Join-Path $play 'Playnite.DesktopApp.exe')
    }
    $version=Get-PlayniteVersion $play
    if($version -lt [version]'10.64'){throw (L 'Playnite 10.64 veya üstü gerekiyor. Mevcut Playnite ana menüsünden güncellemeyi tamamlayıp tekrar deneyin; oyun kütüphaneniz değiştirilmedi.')}
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
                New-Item -ItemType Directory -Force -Path (Join-Path $root 'tools') | Out-Null
                Copy-Item -LiteralPath $cli -Destination (Join-Path $root 'tools\legendary.exe') -Force
                $dir=Join-Path $playData 'ExtensionsData\ead65c3b-2f8f-4e37-b4e6-b3de6be540c6';$file=Join-Path $dir 'config.json';$c=Read-Json $file
                if(!$c){$c=[pscustomobject]@{ConnectAccount=$false;ImportInstalledGames=$true;ImportUninstalledGames=$true;ImportUbisoftLauncherGames=$false;ImportEALauncherGames=$false;SelectedFullLauncherPath='';GamesInstallationPath='';UnattendedInstall=$true}}
                foreach($entry in @{SelectedFullLauncherPath=(Join-Path $root 'tools\legendary.exe');GamesInstallationPath=(Join-Path $root 'Games\Epic');UnattendedInstall=$true}.GetEnumerator()){$c | Add-Member -NotePropertyName $entry.Key -NotePropertyValue $entry.Value -Force}
                if(Test-Path $file){[void](Backup-File $file $DataRoot)};Write-Json $file $c;Mark-Applied $file $DataRoot;New-Item -ItemType Directory -Force -Path (Join-Path $root 'Games\Epic') | Out-Null
            }else{Install-Addon 'epic' 'EpicGamesLibrary_Builtin' $playData}
        }
        EA {Install-Addon 'ea' 'OriginLibrary_Builtin' $playData}
        Ubisoft {Install-Addon 'ubisoft' 'UplayLibrary_Builtin' $playData}
        Xbox {Install-Addon 'xbox' 'XboxLibrary_Builtin' $playData}
    }}
    Set-LibraryImportOptions $Settings $playData $DataRoot
    $plugin=Join-Path $playData 'Extensions\SofaRelay'
    $previous=Join-Path $playData 'Extensions\GamingCenter';if(Test-Path (Join-Path $previous 'extension.yaml')){$plugin=$previous}
    $legacy=Join-Path $playData 'Extensions\OziTvTools'
    if(Test-Path (Join-Path $legacy 'extension.yaml')){$plugin=$legacy}
    New-Item -ItemType Directory -Force -Path $plugin | Out-Null
    Copy-Item -Path (Join-Path $PackageRoot 'assets\plugin\*') -Destination $plugin -Recurse -Force
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'tools') | Out-Null
    Copy-Item -LiteralPath (Join-Path $PackageRoot 'assets\plugin\SteamTvInstall.exe') -Destination (Join-Path $root 'tools\SteamTvInstall.exe') -Force
    Write-Json (Join-Path $plugin 'center-integration.json') @{SettingsPath=(Join-Path $root 'data\settings.json');RuntimeRoot=$root;SettingsApp=(Join-Path $root 'SofaRelay.exe')}
    $config=Join-Path $playData 'fullscreenConfig.json';$full=Read-Json $config
    if(!$full){$full=[pscustomobject]@{}}
    if(Test-Path $config){[void](Backup-File $config $DataRoot)}
    foreach($entry in @{HideMouserCursor=(!$Settings.MouseKeyboard);ShowGameTitles=$true;EnableGameControllerSupport=$Settings.Gamepad;EnableMainBackgroundImage=$false;DarkenUninstalledGamesGrid=$true}.GetEnumerator()){$full | Add-Member -NotePropertyName $entry.Key -NotePropertyValue $entry.Value -Force}
    Write-Json $config $full;Mark-Applied $config $DataRoot
    $appConfig=Join-Path $playData 'config.json';$app=Read-Json $appConfig;if(!$app){$app=[pscustomobject]@{}}
    if(!$app.PSObject.Properties['DatabasePath'] -or !$app.DatabasePath){$app | Add-Member -NotePropertyName DatabasePath -NotePropertyValue (Join-Path $playData 'library') -Force}
    if(Test-Path $appConfig){[void](Backup-File $appConfig $DataRoot)}
    foreach($entry in @{Language=([SofaRelay.I18n]::PlayniteLanguage($selectedLanguage));FirstTimeWizardComplete=$true;AccessibilityInterface=1;CloseToTray=$false;DownloadMetadataOnImport=$true;CheckForLibraryUpdates=1;CheckForEmulatedLibraryUpdates=1}.GetEnumerator()){$app | Add-Member -NotePropertyName $entry.Key -NotePropertyValue $entry.Value -Force}
    Write-Json $appConfig $app;Mark-Applied $appConfig $DataRoot
    $setup=Join-Path $playData 'Extensions\SofaRelaySetup';$oldSetup=Join-Path $playData 'Extensions\GamingCenterSetup';if(Test-Path (Join-Path $oldSetup 'extension.yaml')){$setup=$oldSetup};New-Item -ItemType Directory -Force -Path $setup | Out-Null
    Copy-Item -LiteralPath (Join-Path $PackageRoot 'scripts\NativeSetup.psm1') -Destination (Join-Path $setup 'NativeSetup.psm1') -Force
    # Legacy extension ID: keep it stable to preserve existing Playnite state.
    @"
Id: GamingCenterSetup_e8bd5521-67bd-4600-a757-fbc0e93b385d
Name: SofaRelay Library Setup
Author: SofaRelay
Version: $([SofaRelay.I18n]::Version)
Module: NativeSetup.psm1
Type: Script
"@ | Set-Content -LiteralPath (Join-Path $setup 'extension.yaml') -Encoding UTF8
    Write-Json (Join-Path $setup 'setup.json') @{SettingsPath=(Join-Path $root 'data\settings.json');ReportPath=(Join-Path $root 'data\library-setup.json')}
    Write-Json (Join-Path $root 'data\settings.json') $Settings;Write-Json $SettingsPath $Settings
    if($NoShortcuts){return [pscustomobject]@{InstallRoot=$root;PlaynitePath=$play;SettingsPath=(Join-Path $root 'data\settings.json');App=(Join-Path $root 'SofaRelay.exe')}}
    [void](Set-CenterShortcuts $root $play)
    return [pscustomobject]@{InstallRoot=$root;PlaynitePath=$play;SettingsPath=(Join-Path $root 'data\settings.json');App=(Join-Path $root 'SofaRelay.exe')}
}