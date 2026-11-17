Set-StrictMode -Version 2
$ErrorActionPreference='Stop'
function L([string]$Text,[object[]]$Values=@()) { if('SofaRelay.I18n' -as [type]){return [SofaRelay.I18n]::F($Text,$Values)};if($Values.Count){return ($Text -f $Values)};return $Text }
function Read-Json([string]$Path) { if(Test-Path -LiteralPath $Path){Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json}else{$null} }
function Write-Json([string]$Path,$Object) {
    $parent=Split-Path -Parent $Path;New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $temp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    [IO.File]::WriteAllText($temp,($Object | ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
    if(Test-Path -LiteralPath $Path){
        for($attempt=0;$attempt -lt 25;$attempt++){
            try{[IO.File]::Replace($temp,$Path,[System.Management.Automation.Language.NullString]::Value,$true);break}catch [IO.IOException]{if($attempt -eq 24){throw};Start-Sleep -Milliseconds 80}
        }
    }else{[IO.File]::Move($temp,$Path)}
}
function Resolve-Full([string]$Path) { [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path)) }
function Write-BytesAtomic([string]$Path,[byte[]]$Bytes) {
    $parent=Split-Path $Path -Parent
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $temp=Join-Path $parent ([guid]::NewGuid().ToString('N')+'.tmp')
    [IO.File]::WriteAllBytes($temp,$Bytes)
    try {
        if(Test-Path -LiteralPath $Path) {
            for($attempt=0;$attempt -lt 25;$attempt++) {
                try { [IO.File]::Replace($temp,$Path,[System.Management.Automation.Language.NullString]::Value,$true);break }
                catch [IO.IOException] { if($attempt -eq 24){throw};Start-Sleep -Milliseconds 80 }
            }
        }
        else { [IO.File]::Move($temp,$Path) }
    } finally { if(Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force } }
}
function Assert-InRoot([string]$Path,[string]$Root) {
    $full=Resolve-Full $Path;$boundary=(Resolve-Full $Root).TrimEnd('\')+'\'
    if(!$full.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)){throw (L 'Beklenmeyen hedef: {0}' @($full))}
    $part=$full
    while($part -and $part -ne [IO.Path]::GetPathRoot($part)) {
        if((Test-Path -LiteralPath $part) -and ((Get-Item -LiteralPath $part -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Reparse points are not accepted for managed file writes.' }
        $part=Split-Path $part -Parent
    }
    $full
}
function Quote-WindowsArgument([string]$Value) {
    if($Value -notmatch '[\s"]' -and $Value.Length){return $Value}
    '"'+[regex]::Replace([regex]::Replace($Value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'
}
function Start-CheckedProcess([string]$File,[string[]]$Arguments,[int[]]$SuccessCodes=@(0,3010,1641),[switch]$Capture) {
    $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName=$File;$psi.Arguments=($Arguments | ForEach-Object {Quote-WindowsArgument $_}) -join ' '
    $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
    $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;[void]$p.Start()
    $out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync();$p.WaitForExit()
    $stdout=$out.Result;$stderr=$err.Result
    if($SuccessCodes -notcontains $p.ExitCode){throw (L '{0} tamamlanamadı (kod {1}). {2}' @(([IO.Path]::GetFileName($File)),($p.ExitCode),($stderr.Substring(0,[Math]::Min(700,$stderr.Length)))))}
    if($Capture){return $stdout};return $p.ExitCode
}
function Get-Component([string]$Id,[string]$PackageRoot,[string]$DataRoot) {
    $manifest=Read-Json (Join-Path $PackageRoot 'manifests\packages.json')
    $item=$manifest.Packages | Where-Object Id -eq $Id | Select-Object -First 1
    if(!$item){throw (L 'Bileşen listede yok: {0}' @(($Id)))}
    if(!$item.Version -or $item.Url -match '/(?:latest|master|main)(?:/|$)' -or $item.FileName -ne [IO.Path]::GetFileName($item.FileName) -or $item.FileName -match '[:\\/]' -or $item.Url -notmatch '^https://(github\.com|playnite\.link|dl\.google\.com|buildbot\.libretro\.com)/' -or $item.Sha256 -notmatch '^[0-9a-fA-F]{64}$'){throw (L 'Geçersiz paket kaynağı veya özeti.')}
    $cache=Join-Path $DataRoot 'downloads';New-Item -ItemType Directory -Force -Path $cache | Out-Null
    $path=Assert-InRoot (Join-Path $cache $item.FileName) $cache
    $valid=(Test-Path -LiteralPath $path) -and ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $item.Sha256)
    if(!$valid){
        Write-Output (L 'İndiriliyor: {0} {1}' @(($item.Name),($item.Version))) | Out-Host
        $part=$path+'.part'
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        $previousProgress = $ProgressPreference
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $item.Url -OutFile $part -UseBasicParsing -TimeoutSec 300
            if((Get-FileHash -LiteralPath $part -Algorithm SHA256).Hash -ne $item.Sha256){throw (L '{0} dosya doğrulaması başarısız; çalıştırılmadı.' @(($item.Name)))}
            Move-Item -LiteralPath $part -Destination $path -Force
        } finally {
            $ProgressPreference = $previousProgress
            if(Test-Path -LiteralPath $part){Remove-Item -LiteralPath $part -Force}
        }
    }
    return $path
}
function Expand-ZipSafe([string]$Archive,[string]$Destination) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $zip=[IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        # Validate the complete archive before the first file is extracted.
        foreach($entry in $zip.Entries){
            if($entry.FullName -match '[:]' -or (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000){throw 'Unsafe archive entry.'}
            $null=Assert-InRoot (Join-Path $Destination $entry.FullName) $Destination
        }
        foreach($entry in $zip.Entries){
            $out=Assert-InRoot (Join-Path $Destination $entry.FullName) $Destination
            if($entry.FullName.EndsWith('/')){New-Item -ItemType Directory -Force -Path $out | Out-Null;continue}
            New-Item -ItemType Directory -Force -Path (Split-Path $out -Parent) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$out,$true)
        }
    }finally{$zip.Dispose()}
}
function Backup-File([string]$File,[string]$DataRoot) {
    if(!(Test-Path -LiteralPath $File)){return $null}
    $id=[guid]::NewGuid().ToString('N');$folder=Join-Path $DataRoot 'backups';New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $backup=Join-Path $folder ($id+'-'+[IO.Path]::GetFileName($File));Copy-Item -LiteralPath $File -Destination $backup
    $journalPath=Join-Path $DataRoot 'backup-journal.json';$journal=Read-Json $journalPath
    $entries=@();if($journal){$entries=@($journal.Entries)}
    $entries+=@([pscustomobject]@{Time=(Get-Date).ToString('o');Target=$File;Backup=$backup;OriginalSha256=(Get-FileHash -LiteralPath $File).Hash;AppliedSha256=$null})
    Write-Json $journalPath @{Entries=$entries};return $backup
}
function Mark-Applied([string]$File,[string]$DataRoot) {
    $path=Join-Path $DataRoot 'backup-journal.json';$journal=Read-Json $path;if(!$journal){return}
    $entry=@($journal.Entries | Where-Object Target -eq $File | Select-Object -Last 1)
    if($entry.Count){$entry[0].AppliedSha256=(Get-FileHash -LiteralPath $File).Hash;Write-Json $path $journal}
}
function Set-LibraryImportOptions($Settings,[string]$Playnite,[string]$DataRoot) {
    $definitions=@(
        @{Name='Steam';Id='cb91dfc9-b977-43bf-8e70-55f46e410fab'},
        @{Name='Epic';Id='00000002-dbd1-46c6-b5d0-b1ba559d10e4';NativeEpic=$true},
        @{Name='Epic';Id='ead65c3b-2f8f-4e37-b4e6-b3de6be540c6';Legendary=$true},
        @{Name='EA';Id='85dd7072-2f20-4e76-a007-41035e390724'},
        @{Name='Ubisoft';Id='c2f038e5-8b92-4877-91f1-da9094155fc5'},
        @{Name='Xbox';Id='7e4fbb5e-2ae3-48d4-8ba0-6b30e7a4e287'})
    foreach($definition in $definitions){
        $enabled=$Settings.Libraries -contains $definition.Name
        if($definition.ContainsKey('NativeEpic') -and $Settings.EpicDirectInstall){$enabled=$false}
        if($definition.ContainsKey('Legendary') -and !$Settings.EpicDirectInstall){$enabled=$false}
        $file=Join-Path $Playnite ('ExtensionsData\'+$definition.Id+'\config.json');$config=Read-Json $file
        if(!$config -and !$enabled){continue}
        if(!$config){$config=[pscustomobject]@{}}
        foreach($key in @('ImportInstalledGames','ImportUninstalledGames')){$config | Add-Member -NotePropertyName $key -NotePropertyValue ([bool]$enabled) -Force}
        if(Test-Path $file){[void](Backup-File $file $DataRoot)};Write-Json $file $config;Mark-Applied $file $DataRoot
    }
}
function Set-ConfValues([string]$Text,[System.Collections.IDictionary]$Values) {
    foreach($key in $Values.Keys){$pattern='(?m)^\s*'+[regex]::Escape($key)+'\s*=.*(?:\r?\n|$)';$Text=[regex]::Replace($Text,$pattern,'');$Text=$Text.TrimEnd()+"`r`n"+$key+' = '+$Values[$key]+"`r`n"}
    return $Text
}
function Get-SunshineDirectory {
    $service=Get-CimInstance Win32_Service -Filter "Name='SunshineService'" -ErrorAction SilentlyContinue
    if($service){$m=[regex]::Match($service.PathName,'^"([^"]+)"|^(\S+\.exe)');if($m.Success){$exe=if($m.Groups[1].Success){$m.Groups[1].Value}else{$m.Groups[2].Value};$dir=Split-Path $exe -Parent;if((Split-Path $dir -Leaf) -eq 'tools'){$dir=Split-Path $dir -Parent};if(Test-Path (Join-Path $dir 'sunshine.exe')){return $dir}}}
    $default=Join-Path $env:ProgramFiles 'Sunshine';if(Test-Path (Join-Path $default 'sunshine.exe')){return $default};return ''
}
function Get-SunshineDisplays([string]$Directory) {
    $log=Join-Path $Directory 'config\sunshine.log';if(!(Test-Path -LiteralPath $log)){return @()}
    $lines=@(Get-Content -LiteralPath $log -Tail 4000 -ErrorAction SilentlyContinue)
    for($i=$lines.Count-1;$i -ge 0;$i--){
        if($lines[$i] -notmatch 'Currently available display devices:'){continue}
        $block=[Collections.Generic.List[string]]::new()
        for($j=$i+1;$j -lt $lines.Count;$j++){$block.Add($lines[$j]);if($lines[$j].Trim() -eq ']'){break}}
        try{return @((($block -join "`n") | ConvertFrom-Json))}catch{Write-Verbose 'A display-log block was incomplete; trying an earlier block.'}
    };return @()
}
function Get-StreamState {
    try{$request=[Net.HttpWebRequest]::Create('http://127.0.0.1:47989/serverinfo');$request.Timeout=3000;$response=$request.GetResponse();try{$reader=[IO.StreamReader]::new($response.GetResponseStream());try{$xml=[xml]$reader.ReadToEnd();if($xml.root.state){return [string]$xml.root.state};return 'UNKNOWN'}finally{$reader.Dispose()}}finally{$response.Dispose()}}catch{if(Get-Process sunshine -ErrorAction SilentlyContinue){return 'UNKNOWN'};return 'NOT_RUNNING'}
}
function Resolve-StreamLogActivity {
    param([string[]]$Lines)
    $active=-1;$pending=0
    foreach($line in $Lines) {
        if($line -match 'Sunshine version:'){$active=0;$pending=0}
        elseif($line -match 'New streaming session started \[active sessions: (\d+)\]') {
            $confirmed=if($active -ge 0){[Math]::Max(0,$active-$pending)}else{0}
            $active=[int]$Matches[1];$pending=[Math]::Max(0,$active-$confirmed)
        }
        elseif($line -match 'CLIENT CONNECTED') {if($pending -gt 0){$pending--}elseif($active -ge 0){$active++}}
        elseif($line -match 'CLIENT DISCONNECTED') {if($active -gt 0){$active--;$pending=[Math]::Min($pending,$active)}else{$active=-1;$pending=0}}
    }
    return $active
}
function Get-StreamActivity {
    # /serverinfo BUSY means an app is retained for resume, not a connected client.
    # The watchdog additionally requires a complete, current log session history.
    $state=Get-StreamState
    if($state -notin @('SUNSHINE_SERVER_BUSY','SUNSHINE_SERVER_FREE')){return $state}
    try {
        $sun=Get-SunshineDirectory
        if(!$sun){return 'UNKNOWN'}
        $file=Join-Path $sun 'config\sunshine.log'
        $item=Get-Item -LiteralPath $file -ErrorAction Stop
        $process=Get-CimInstance Win32_Process -Filter "Name='sunshine.exe'" -ErrorAction Stop | Select-Object -First 1
        if(!$process -or !$process.CreationDate -or $item.LastWriteTimeUtc -lt $process.CreationDate.ToUniversalTime()){return 'UNKNOWN'}
        $active=Resolve-StreamLogActivity @(Get-Content -LiteralPath $file -Tail 12000 -Encoding UTF8 -ErrorAction Stop)
        if($active -gt 0){return 'SUNSHINE_SERVER_BUSY'}
        if($active -eq 0){return 'SUNSHINE_SERVER_FREE'}
        return 'UNKNOWN'
    } catch {Write-Verbose 'Stream activity could not be established from the current Sunshine log.';return 'UNKNOWN'}
}
function Read-DisplaySnapshot {
    param([string]$Path)
    Add-Type -AssemblyName System.Web.Extensions
    $serializer=[Web.Script.Serialization.JavaScriptSerializer]::new()
    return $serializer.Deserialize([IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8),[SavedDisplayState])
}
function Assert-StreamIdle { $state=Get-StreamState;if($state -eq 'SUNSHINE_SERVER_BUSY'){throw (L 'Aktif Moonlight yayını var. Yayından çıkıp tekrar uygulayın; mevcut oturum kesilmedi.')};if($state -notin @('SUNSHINE_SERVER_FREE','NOT_RUNNING')){throw (L 'Sunshine yayın durumu okunamadı; açık oturum kesilmemesi için ayarlar değiştirilmedi. Sunshine panelini kontrol edip tekrar deneyin.')} }
function Is-Admin { $p=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent());return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
function Find-Playnite {
    $roots=@((Join-Path $env:LOCALAPPDATA 'Playnite'),(Join-Path $env:LOCALAPPDATA 'SofaRelay\Playnite'),(Join-Path $env:LOCALAPPDATA 'OyunMerkezi\Playnite'),(Join-Path $env:ProgramFiles 'Playnite'))
    $shell=New-Object -ComObject WScript.Shell
    foreach($name in @('SofaRelay','Oyun Merkezi')){$folder=Join-Path ([Environment]::GetFolderPath('Programs')) $name;if(Test-Path -LiteralPath $folder){foreach($file in Get-ChildItem -LiteralPath $folder -Filter '*.lnk' -File){$link=$shell.CreateShortcut($file.FullName);if([IO.Path]::GetFileName($link.TargetPath) -eq 'Playnite.FullscreenApp.exe'){$roots+=@(Split-Path $link.TargetPath -Parent)}}}}
    foreach($root in $roots){if(Test-Path (Join-Path $root 'Playnite.DesktopApp.exe')){return $root}}
    return ''
}
function Set-CenterShortcuts([string]$Root,[string]$Playnite,[string]$MenuRoot=([Environment]::GetFolderPath('Programs'))) {
    $menu=Join-Path $MenuRoot 'SofaRelay';New-Item -ItemType Directory -Force -Path $menu | Out-Null
    $shell=New-Object -ComObject WScript.Shell
    foreach($item in @(@{Name='SofaRelay';Target=(Join-Path $Playnite 'Playnite.FullscreenApp.exe');Args='--startfullscreen --hidesplashscreen'},@{Name='SofaRelay Settings';Target=(Join-Path $Root 'SofaRelay.exe');Args='--settings'},@{Name='Restore Display';Target=(Join-Path $Root 'SofaRelay.exe');Args='--recover'})){
        $link=$shell.CreateShortcut((Join-Path $menu ($item.Name+'.lnk')));$link.TargetPath=$item.Target;$link.Arguments=$item.Args;$link.WorkingDirectory=$Root;if($item.Args -eq '--recover'){$link.Hotkey='CTRL+ALT+F11'};$link.Save()
    }
    $oldMenu=Join-Path $MenuRoot 'Oyun Merkezi'
    if(Test-Path -LiteralPath $oldMenu){foreach($file in Get-ChildItem -LiteralPath $oldMenu -Filter '*.lnk' -File){
        $link=$shell.CreateShortcut($file.FullName)
        if($link.TargetPath -in @((Join-Path $Root 'OyunMerkezi.exe'),(Join-Path $Root 'SofaRelay.exe'),(Join-Path $Playnite 'Playnite.FullscreenApp.exe'))){
            $backup=Join-Path $Root ('data\shortcut-backups\'+$file.Name);New-Item -ItemType Directory -Force -Path (Split-Path $backup -Parent) | Out-Null;Copy-Item -LiteralPath $file.FullName -Destination $backup -Force;Remove-Item -LiteralPath $file.FullName
        }
    }}
    return $menu
}
function Get-PlayniteVersion([string]$InstallDirectory) {
    $core=Join-Path $InstallDirectory 'Playnite.dll'
    if(Test-Path -LiteralPath $core){return [Reflection.AssemblyName]::GetAssemblyName($core).Version}
    $info=[Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $InstallDirectory 'Playnite.DesktopApp.exe'))
    return [version]::new($info.FileMajorPart,$info.FileMinorPart,$info.FileBuildPart,$info.FilePrivatePart)
}
function Get-PlayniteDataDirectory([string]$InstallDirectory) {
    if(Test-Path (Join-Path $InstallDirectory 'unins000.exe')){return (Join-Path $env:APPDATA 'Playnite')}
    return $InstallDirectory
}
function Get-Diagnosis($Settings) {
    $sun=$Settings.SunshineDirectory;if(!$sun){$sun=Get-SunshineDirectory}
    $play=$Settings.PlaynitePath;if(!$play){$play=Find-Playnite}
    $adapters=@(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object Name,DriverVersion)
    $displays=@();if($sun){$displays=@(Get-SunshineDisplays $sun)}
    $vdd=@(Get-PnpDevice -Class Display -PresentOnly -ErrorAction SilentlyContinue | Where-Object {$_.FriendlyName -match 'Virtual Display|VDD by|IddSample'})
    $vigem=@(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {$_.InstanceId -like 'ROOT\VIGEMBUS*' -or $_.FriendlyName -match 'Virtual Gamepad Emulation Bus|ViGEmBus|Nefarius.*Virtual HID'})
    $release=Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue
    $physical=@(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ifIndex)
    $addresses=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*'})
    $ip=@($addresses | Where-Object {$_.InterfaceIndex -in $physical} | Select-Object -ExpandProperty IPAddress)
    if(!$ip.Count){$ip=@($addresses | Select-Object -ExpandProperty IPAddress)}
    [pscustomobject]@{OS=[Environment]::OSVersion.VersionString;Is64Bit=[Environment]::Is64BitOperatingSystem;FrameworkRelease=$release;Winget=[bool](Get-Command winget.exe -ErrorAction SilentlyContinue);PlaynitePath=$play;SunshineDirectory=$sun;SunshineInstalled=[bool]$sun;StreamState=Get-StreamState;VirtualDisplayInstalled=($vdd.Count -gt 0);GamepadDriverInstalled=($vigem.Count -gt 0);Displays=$displays;GPU=$adapters;HostAddresses=$ip;ComputerName=$env:COMPUTERNAME;IsAdmin=Is-Admin}
}
Export-ModuleMember -Function *
