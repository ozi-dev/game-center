function Read-CenterSetup {
    $folder=$CurrentExtensionInstallPath
    if(!$folder){$folder=Split-Path -Parent $MyInvocation.MyCommand.Module.Path}
    $control=Get-Content -LiteralPath (Join-Path $folder 'setup.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    return @{Control=$control;Settings=(Get-Content -LiteralPath $control.SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json)}
}
function Find-Named($collection,[string]$type,[string]$name) {
    $item=$collection | Where-Object Name -eq $name | Select-Object -First 1
    if(!$item){$item=New-Object $type;$item.Name=$name;$collection.Add($item)}
    return $item
}
function Get-CenterSourceName($Definition) {
    $emu=$PlayniteApi.Database.Emulators | Where-Object Name -eq $Definition.Name | Select-Object -First 1
    if($emu){foreach($game in $PlayniteApi.Database.Games){if(!$game.Roms -or !$game.Source){continue};foreach($action in $game.GameActions){if($action.Type -eq [Playnite.SDK.Models.GameActionType]::Emulator -and $action.EmulatorId -eq $emu.Id){return $game.Source.Name}}}}
    return $Definition.Name
}
function Update-CenterLibrary($Settings) {
    $report=@()
    foreach($definition in $Settings.Emulators){
        $exe=[Environment]::ExpandEnvironmentVariables($definition.Executable)
        $directory=[Environment]::ExpandEnvironmentVariables($definition.RomDirectory)
        if(!(Test-Path -LiteralPath $exe) -or !(Test-Path -LiteralPath $directory)){continue}
        $platform=Find-Named $PlayniteApi.Database.Platforms 'Playnite.SDK.Models.Platform' $definition.Platform
        $emu=Find-Named $PlayniteApi.Database.Emulators 'Playnite.SDK.Models.Emulator' $definition.Name
        $emu.InstallDir=Split-Path $exe -Parent
        if(!$emu.CustomProfiles){$emu.CustomProfiles=[Collections.ObjectModel.ObservableCollection[Playnite.SDK.Models.CustomEmulatorProfile]]::new()}
        $profileName='Oyun Merkezi - '+$definition.Platform
        $profile=$emu.CustomProfiles | Where-Object Name -eq $profileName | Select-Object -First 1
        if(!$profile){$profile=$emu.CustomProfiles | Where-Object {$_.Platforms -contains $platform.Id -and $_.Executable.Replace('{EmulatorDir}',$emu.InstallDir) -in @($exe,[IO.Path]::GetFileName($exe))} | Select-Object -First 1}
        if(!$profile){$profile=[Playnite.SDK.Models.CustomEmulatorProfile]::new();$profile.Name=$profileName;$emu.CustomProfiles.Add($profile)}
        $profile.Executable=$exe;$profile.WorkingDirectory='{EmulatorDir}';$profile.Arguments=$definition.Arguments.Replace('{CorePath}',$definition.CorePath).Replace('{GameCenterDir}',$Settings.InstallRoot)
        $extensions=@($definition.Extensions -split '[,; ]+' | Where-Object {$_} | ForEach-Object {$_.TrimStart('.')})
        $profile.ImageExtensions=[Collections.Generic.List[string]]::new([string[]]$extensions)
        $profile.Platforms=[Collections.Generic.List[guid]]::new([guid[]]@($platform.Id));$profile.TrackingMode=[Playnite.SDK.Models.TrackingMode]::OriginalProcess
        $PlayniteApi.Database.Emulators.Update($emu)
        $scannerName='Oyun Merkezi - '+$definition.Name+' - '+$definition.Platform
        $scanner=$PlayniteApi.Database.GameScanners | Where-Object Name -eq $scannerName | Select-Object -First 1
        if(!$scanner){$scanner=$PlayniteApi.Database.GameScanners | Where-Object {$_.Directory.TrimEnd('\') -eq $directory.TrimEnd('\') -and $_.EmulatorId -eq $emu.Id -and $_.EmulatorProfileId -eq $profile.Id} | Select-Object -First 1}
        $new=!$scanner;if(!$scanner){$scanner=[Playnite.SDK.Models.GameScannerConfig]::new();$scanner.Name=$scannerName}
        $scanner.Directory=$directory;$scanner.EmulatorId=$emu.Id;$scanner.EmulatorProfileId=$profile.Id;$scanner.OverridePlatformId=$platform.Id;$scanner.InGlobalUpdate=$true;$scanner.ScanSubfolders=$definition.ScanSubfolders;$scanner.ScanInsideArchives=$false
        $scanner.CrcExcludeFileTypes=[Collections.Generic.List[string]]::new([string[]]$extensions)
        if($new){$PlayniteApi.Database.GameScanners.Add($scanner)}else{$PlayniteApi.Database.GameScanners.Update($scanner)}
        $source=Find-Named $PlayniteApi.Database.Sources 'Playnite.SDK.Models.GameSource' (Get-CenterSourceName $definition)
        foreach($game in $PlayniteApi.Database.Games){
            if(!$game.Roms){continue}
            $match=$false
            foreach($action in $game.GameActions){if($action.Type -eq [Playnite.SDK.Models.GameActionType]::Emulator -and $action.EmulatorId -eq $emu.Id){$match=$true;break}}
            if($match -and $game.SourceId -eq [guid]::Empty){$game.SourceId=$source.Id;$PlayniteApi.Database.Games.Update($game)}
        }
        $report+=@(@{Name=$definition.Name;ProfileId=$profile.Id;Scanner=$scanner.Name})
    }
    return $report
}
function Update-CenterFilters($Settings) {
    $definitions=@(@{Name='Kurulu Oyunlar';Installed=$true;Id='d5a3fa84-090f-4347-9529-d7f3c759c313'},@{Name='Tüm Kütüphane';Id='077a16f9-1f8f-4bb8-b50f-369553007033'})
    $sourceNames=@{Steam='Steam';Epic='Epic';EA='EA app';Ubisoft='Ubisoft Connect';Xbox='Xbox'}
    foreach($library in $Settings.Libraries){$definitions+=@(@{Name=$library;Source=$sourceNames[$library]})}
    foreach($emu in $Settings.Emulators){$sourceName=Get-CenterSourceName $emu;$definitions+=@(@{Name=$sourceName;Source=$sourceName})}
    foreach($definition in $definitions){
        $preset=$PlayniteApi.Database.FilterPresets | Where-Object Name -eq $definition.Name | Select-Object -First 1
        $new=!$preset;if(!$preset){$preset=[Playnite.SDK.Models.FilterPreset]::new();$preset.Name=$definition.Name;if($definition.Id){$preset.Id=[guid]$definition.Id}}
        $preset.ShowInFullscreeQuickSelection=$true;$preset.Settings=[Playnite.SDK.Models.FilterPresetSettings]::new();$preset.Settings.IsInstalled=[bool]$definition.Installed
        if($definition.Source){$source=Find-Named $PlayniteApi.Database.Sources 'Playnite.SDK.Models.GameSource' $definition.Source;$preset.Settings.Source=[Playnite.SDK.Models.IdItemFilterItemProperties]::new();$preset.Settings.Source.Ids=[Collections.Generic.List[guid]]::new([guid[]]@($source.Id))}
        if($new){$PlayniteApi.Database.FilterPresets.Add($preset)}else{$PlayniteApi.Database.FilterPresets.Update($preset)}
    }
    $PlayniteApi.MainView.ApplyFilterPreset([guid]'d5a3fa84-090f-4347-9529-d7f3c759c313')
}
function OnApplicationStarted {
    try {
        $context=Read-CenterSetup;$control=$context.Control;$Settings=$context.Settings
        $hash=(Get-FileHash -LiteralPath $control.SettingsPath -Algorithm SHA256).Hash
        $previous=$null;if(Test-Path $control.ReportPath){$previous=Get-Content $control.ReportPath -Raw -Encoding UTF8 | ConvertFrom-Json}
        if($previous -and $previous.SettingsHash -eq $hash){return}
        if($Settings.EpicDirectInstall -and $Settings.Libraries -contains 'Epic'){
            foreach($game in $PlayniteApi.Database.Games | Where-Object PluginId -eq ([guid]'00000002-dbd1-46c6-b5d0-b1ba559d10e4')){$game.PluginId=[guid]'ead65c3b-2f8f-4e37-b4e6-b3de6be540c6';$PlayniteApi.Database.Games.Update($game)}
        }
        $profiles=@(Update-CenterLibrary $Settings);Update-CenterFilters $Settings
        @{Success=$true;SettingsHash=$hash;Profiles=$profiles;Games=$PlayniteApi.Database.Games.Count;Time=(Get-Date).ToString('o')} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $control.ReportPath -Encoding UTF8
    }catch{if($control){@{Success=$false;Message=$_.Exception.Message;Stack=$_.ScriptStackTrace} | ConvertTo-Json | Set-Content -LiteralPath $control.ReportPath -Encoding UTF8}else{try{@{Success=$false;Message=$_.Exception.Message;Stack=$_.ScriptStackTrace} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $CurrentExtensionInstallPath 'setup-error.json') -Encoding UTF8}catch{}}}
}
function OnLibraryUpdated {
    try{$context=Read-CenterSetup;[void](Update-CenterLibrary $context.Settings)}catch{}
}
Export-ModuleMember -Function *
