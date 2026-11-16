param([string]$OutputDirectory='build')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts\Common.psm1') -Force -DisableNameChecking
$fixture=Join-Path $root ('reports\backend-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
$script:count=0
function Assert([bool]$Value,[string]$Message){if(!$Value){throw $Message};$script:count++}
function Throws([scriptblock]$Code,[string]$Message){$caught=$false;try{& $Code | Out-Null}catch{$caught=$true};Assert $caught $Message}
$path=Join-Path $fixture 'with spaces\test.json'
Write-Json $path @{Value=1};Write-Json $path @{Value=2}
Assert ((Read-Json $path).Value -eq 2) 'Atomic overwrite must work on Windows PowerShell 5.1'
$backup=Backup-File $path $fixture;Write-Json $path @{Value=3};Mark-Applied $path $fixture
$journal=Read-Json (Join-Path $fixture 'backup-journal.json')
Assert ((Read-Json $backup).Value -eq 2) 'Original backup preserved'
Assert ($journal.Entries[0].AppliedSha256 -eq (Get-FileHash $path).Hash) 'Applied hash recorded'
Throws {Assert-InRoot (Join-Path $fixture '..\outside.exe') $fixture} 'Traversal rejected'
Assert ((Quote-WindowsArgument 'a b\') -eq '"a b\\"') 'Trailing slash quoting'
Assert ((Set-ConfValues "keyboard = disabled`r`nother = keep`r`nkeyboard = enabled" @{keyboard='enabled'}) -eq "other = keep`r`nkeyboard = enabled`r`n") 'Config keys deduplicated; unrelated preserved'
Add-Type -AssemblyName System.IO.Compression.FileSystem,System.IO.Compression
$zip=Join-Path $fixture 'bad.zip';$stream=[IO.File]::Create($zip);$archive=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create)
try{[void]$archive.CreateEntry('../escaped.txt')}finally{$archive.Dispose();$stream.Dispose()}
Throws {Expand-ZipSafe $zip (Join-Path $fixture 'unpack')} 'Zip traversal rejected'
Assert (!(Test-Path (Join-Path $fixture 'escaped.txt'))) 'Escaped file never written'
$play=Join-Path $fixture 'Playnite';$data=Join-Path $fixture 'data';$steam=Join-Path $play 'ExtensionsData\cb91dfc9-b977-43bf-8e70-55f46e410fab\config.json';$epic=Join-Path $play 'ExtensionsData\00000002-dbd1-46c6-b5d0-b1ba559d10e4\config.json'
Write-Json $steam @{ConnectAccount=$true;UserId='test-user';ImportInstalledGames=$false;ImportUninstalledGames=$false}
Write-Json $epic @{ConnectAccount=$true;ImportInstalledGames=$true;ImportUninstalledGames=$true}
$settings=[pscustomobject]@{Libraries=@('Steam','Epic','Ubisoft');EpicDirectInstall=$true}
Set-LibraryImportOptions $settings $play $data
Assert ((Read-Json $steam).ConnectAccount -and (Read-Json $steam).UserId -eq 'test-user') 'Existing authentication fields preserved'
Assert ((Read-Json $steam).ImportUninstalledGames) 'Owned uninstalled Steam games enabled'
Assert (!(Read-Json $epic).ImportUninstalledGames) 'Duplicate Epic native import disabled'
Assert ((Read-Json (Join-Path $play 'ExtensionsData\ead65c3b-2f8f-4e37-b4e6-b3de6be540c6\config.json')).ImportUninstalledGames) 'Legendary import enabled'
Assert ((Read-Json (Join-Path $play 'ExtensionsData\c2f038e5-8b92-4877-91f1-da9094155fc5\config.json')).ImportUninstalledGames) 'Ubisoft correct provider ID'
$settings.Libraries=@();Set-LibraryImportOptions $settings $play $data
Assert (!(Read-Json $steam).ImportInstalledGames -and (Read-Json $steam).ConnectAccount) 'Deselection disables import without deleting account'
Assert ((Get-PlayniteDataDirectory $play) -eq $play) 'Portable Playnite data next to executable'
[IO.File]::WriteAllText((Join-Path $play 'unins000.exe'),'fixture')
Assert ((Get-PlayniteDataDirectory $play) -eq (Join-Path $env:APPDATA 'Playnite')) 'Installed Playnite data in roaming profile'
# Run the real protected configuration functions with all system/driver/service
# boundaries mocked; writes are confined to this disposable project fixture.
Add-Type -Path (Join-Path $root ($OutputDirectory+'\SofaRelay.Core.dll'))
. (Join-Path $root 'scripts\ProtectedState.ps1')
. (Join-Path $root 'scripts\ConfigTransaction.ps1')
foreach($name in @('Assert-Settings','Apply-Protected','Restore-Protected')){. (Join-Path $root ('scripts\operations\'+$name+'.ps1'))}
function Is-Admin{return $true}
function Assert-PrivilegedContext{}
function Assert-ComponentDirectory{param($Directory)}
function Set-LanFirewallPolicy{param($Sunshine,$Enabled)}
function Set-RecoveryTask{param($Enabled)}
function Invoke-IntegrationTransaction{param($Sunshine,$Operation) & $Operation}
function Assert-StreamIdle{}
function Save-DisplayBaseline{}
function Get-ItemPropertyValue{param($Path,$Name,$ErrorAction) return 528040}
function Get-ItemProperty{param($Path,$ErrorAction) return [pscustomobject]@{Installed=1}}
function Restart-Service{param($Name)}
function Get-PnpDevice{param($Class,[switch]$PresentOnly) @([pscustomobject]@{FriendlyName='VDD by MTT';InstanceId='ROOT\DISPLAY\0000'},[pscustomobject]@{FriendlyName='Nefarius Virtual Gamepad Emulation Bus';InstanceId='ROOT\SYSTEM\0003'})}
function Get-SunshineDirectory{return (Join-Path $fixture 'Sunshine')}
function Get-SunshineDisplays{param($Directory) @([pscustomobject]@{device_id='{11111111-1111-1111-1111-111111111111}';friendly_name='VDD by MTT'})}
$PackageRoot=Join-Path $root $OutputDirectory;$DataRoot=Join-Path $fixture 'protected-data';$SettingsPath=Join-Path $fixture 'protected-settings.json'
$typed=[SofaRelay.CenterSettings]::new();$typed.InstallRoot=Join-Path $fixture 'runtime';$typed.PlaynitePath=$play;$typed.VddDirectory=Join-Path $fixture 'vdd'
$typed.Width=1920;$typed.Height=1080;$typed.RefreshRate=120
[SofaRelay.Data]::Write($SettingsPath,$typed);$Settings=Read-Json $SettingsPath
New-Item -ItemType Directory -Force -Path (Join-Path $typed.InstallRoot 'data'),$typed.VddDirectory,(Join-Path $fixture 'Sunshine\config') | Out-Null
$sunConfig=Join-Path $fixture 'Sunshine\config\sunshine.conf';$apps=Join-Path $fixture 'Sunshine\config\apps.json';$vdd=Join-Path $typed.VddDirectory 'vdd_settings.xml'
[IO.File]::WriteAllText($sunConfig,"encoder = nvenc`r`nkeyboard = disabled`r`n")
[IO.File]::WriteAllText($vdd,'<vdd_settings><monitors><count>1</count></monitors><resolutions></resolutions></vdd_settings>')
Write-Json $apps @{env=@{};apps=@(@{name='Other app';cmd='example.exe'},@{name='Desktop'})}
$result=Apply-Protected
Assert ($result.PhysicalMonitorOff -and $result.RefreshRate -eq 120) 'Requested display and monitor settings applied'
Assert ((Get-Content $sunConfig -Raw) -match 'ensure_only_display') 'Physical displays disabled only via Sunshine session configuration'
Assert ((Get-Content $sunConfig -Raw) -match 'encoder = nvenc') 'Existing encoder preserved'
Assert (@((Read-Json $apps).apps).Count -eq 3) 'Desktop and library added; other app preserved'
Assert (@(([xml](Get-Content $vdd -Raw)).vdd_settings.resolutions.resolution).Count -eq 4) 'Custom refresh mode added to VDD'
[void](Apply-Protected)
Assert (@((Read-Json $apps).apps).Count -eq 3) 'Repeated apply does not duplicate apps'
Assert (@(([xml](Get-Content $vdd -Raw)).vdd_settings.resolutions.resolution).Count -eq 4) 'Repeated apply does not duplicate modes'
$before=Get-Content $sunConfig -Raw;[IO.File]::AppendAllText($apps,"`r`n ")
Throws {Restore-Protected} 'Restore refuses post-install user changes'
Assert ((Get-Content $sunConfig -Raw) -eq $before) 'Restore preflight avoids partial restore'
$last=(Read-Json (Join-Path $DataRoot 'backup-journal.json')).Entries | Where-Object Target -eq $apps | Select-Object -Last 1
# Return fixture to its recorded applied content, then exercise successful restore.
[void](Apply-Protected);$restored=Restore-Protected
Assert ($restored.Restored.Count -eq 3) 'All original configuration files restored'
Assert ((Get-Content $sunConfig -Raw) -notmatch 'ensure_only_display') 'Original display configuration recovered'
$tokens=$null;$parseErrors=$null
foreach($script in @(Get-ChildItem (Join-Path $root 'scripts') -File | Where-Object Extension -in '.ps1','.psm1')){[void][Management.Automation.Language.Parser]::ParseFile($script.FullName,[ref]$tokens,[ref]$parseErrors);Assert (!$parseErrors.Count) ('PowerShell parse: '+$script.Name)}
$manifest=Read-Json (Join-Path $root 'manifests\packages.json')
foreach($id in @('playnite','steam','epic','igdb','ea','ubisoft','xbox','legendary-plugin','legendary-cli','udm','sunshine','vigem','vdd','adb','moonlight')){Assert (@($manifest.Packages | Where-Object Id -eq $id).Count -eq 1) ('Pinned package: '+$id)}
$menuRoot=Join-Path $fixture 'start-menu';$oldMenu=Join-Path $menuRoot 'Oyun Merkezi';New-Item -ItemType Directory -Force -Path $oldMenu | Out-Null
$shell=New-Object -ComObject WScript.Shell;$legacyLink=Join-Path $oldMenu 'Old settings.lnk';$link=$shell.CreateShortcut($legacyLink);$link.TargetPath=Join-Path $typed.InstallRoot 'OyunMerkezi.exe';$link.Save()
$otherLink=Join-Path $oldMenu 'Unrelated.lnk';$link=$shell.CreateShortcut($otherLink);$link.TargetPath=Join-Path $env:WINDIR 'notepad.exe';$link.Save()
$menu=Set-CenterShortcuts $typed.InstallRoot $play $menuRoot
Assert ((Split-Path $menu -Leaf) -eq 'SofaRelay' -and @(Get-ChildItem -LiteralPath $menu -Filter '*.lnk').Count -eq 3) 'English product folder and three shortcuts'
$link=$shell.CreateShortcut((Join-Path $menu 'SofaRelay Settings.lnk'));Assert ($link.TargetPath -eq (Join-Path $typed.InstallRoot 'SofaRelay.exe') -and $link.Arguments -eq '--settings') 'Settings shortcut targets renamed app'
$link=$shell.CreateShortcut((Join-Path $menu 'Restore Display.lnk'));Assert ($link.Arguments -eq '--recover' -and $link.Hotkey -match 'F11') 'Recovery shortcut and hotkey preserved'
Assert (!(Test-Path -LiteralPath $legacyLink) -and (Test-Path (Join-Path $typed.InstallRoot 'data\shortcut-backups\Old settings.lnk'))) 'Owned legacy shortcut backed up and retired'
Assert (Test-Path -LiteralPath $otherLink) 'Unrelated legacy-folder shortcuts preserved'
[void](Set-CenterShortcuts $typed.InstallRoot $play $menuRoot);Assert (@(Get-ChildItem -LiteralPath $menu -Filter '*.lnk').Count -eq 3) 'Shortcut migration is idempotent'
Import-Module (Join-Path $root 'scripts\NativeSetup.psm1') -Force -DisableNameChecking
$definition=[pscustomobject]@{Arguments='--appendconfig "{GameCenterDir}\assets\retroarch-tv.cfg" -L "{CorePath}" "{ImagePath}"';CorePath='test-core.dll'}
$resolved=Resolve-CenterArguments $definition $typed
Assert ($resolved.Contains($typed.InstallRoot) -and !$resolved.Contains('{GameCenterDir}') -and $resolved.Contains('{ImagePath}')) 'Legacy emulator placeholder resolves without altering game path token'
$definition.Arguments=$definition.Arguments.Replace('{GameCenterDir}','{SofaRelayDir}');Assert ((Resolve-CenterArguments $definition $typed) -eq $resolved) 'New and legacy emulator placeholders resolve identically'
$versionFolder=Join-Path $fixture 'native-bootstrapper';New-Item -ItemType Directory -Force -Path $versionFolder | Out-Null
$versionSource=Join-Path $versionFolder 'Version.cs';$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
foreach($number in @('10.64.0.0','10.63.0.0')){
    [IO.File]::WriteAllText($versionSource,('[assembly:System.Reflection.AssemblyVersion("'+$number+'")] public class VersionFixture {}'))
    & $compiler /nologo /target:library ('/out:'+(Join-Path $versionFolder 'Playnite.dll')) $versionSource
    if($LASTEXITCODE){throw 'Version regression fixture compilation failed'}
    $detected=Get-PlayniteVersion $versionFolder
    Assert ($detected -eq [version]$number -and (($detected -ge [version]'10.64') -eq ($number -eq '10.64.0.0'))) ('Read actual Playnite assembly version: '+$number)
}
Write-Json (Join-Path $root 'reports\backend-tests.json') @{Success=$true;Assertions=$script:count;Date=(Get-Date).ToString('o');Fixture=$fixture}
Write-Host "PASS $script:count backend assertions"
