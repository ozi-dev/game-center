Set-StrictMode -Version 2
$ErrorActionPreference='Stop'
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
function Assert-InRoot([string]$Path,[string]$Root) {
    $full=Resolve-Full $Path;$boundary=(Resolve-Full $Root).TrimEnd('\')+'\'
    if(!$full.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase)){throw "Beklenmeyen hedef: $full"}
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
    if($SuccessCodes -notcontains $p.ExitCode){throw "$([IO.Path]::GetFileName($File)) tamamlanamadı (kod $($p.ExitCode)). $($stderr.Substring(0,[Math]::Min(700,$stderr.Length)))"}
    if($Capture){return $stdout};return $p.ExitCode
}
function Get-Component([string]$Id,[string]$PackageRoot,[string]$DataRoot) {
    $manifest=Read-Json (Join-Path $PackageRoot 'manifests\packages.json')
    $item=$manifest.Packages | Where-Object Id -eq $Id | Select-Object -First 1
    if(!$item){throw "Bileşen listede yok: $Id"}
    if($item.Url -notmatch '^https://(github\.com|playnite\.link|dl\.google\.com|buildbot\.libretro\.com)/' -or $item.Sha256 -notmatch '^[0-9a-fA-F]{64}$'){throw 'Geçersiz paket kaynağı veya özeti.'}
    $cache=Join-Path $DataRoot 'downloads';New-Item -ItemType Directory -Force -Path $cache | Out-Null
    $path=Assert-InRoot (Join-Path $cache $item.FileName) $cache
    $valid=(Test-Path -LiteralPath $path) -and ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $item.Sha256)
    if(!$valid){
        Write-Output "İndiriliyor: $($item.Name) $($item.Version)" | Out-Host
        $part=$path+'.part'
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $item.Url -OutFile $part -UseBasicParsing -TimeoutSec 300
        if((Get-FileHash -LiteralPath $part -Algorithm SHA256).Hash -ne $item.Sha256){throw "$($item.Name) dosya doğrulaması başarısız; çalıştırılmadı."}
        Move-Item -LiteralPath $part -Destination $path -Force
    }
    return $path
}
function Expand-ZipSafe([string]$Archive,[string]$Destination) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $zip=[IO.Compression.ZipFile]::OpenRead($Archive)
    try {
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
        try{return @((($block -join "`n") | ConvertFrom-Json))}catch{}
    };return @()
}
function Get-StreamState {
    try{$request=[Net.HttpWebRequest]::Create('http://127.0.0.1:47989/serverinfo');$request.Timeout=3000;$response=$request.GetResponse();try{$reader=[IO.StreamReader]::new($response.GetResponseStream());try{$xml=[xml]$reader.ReadToEnd();if($xml.root.state){return [string]$xml.root.state};return 'UNKNOWN'}finally{$reader.Dispose()}}finally{$response.Dispose()}}catch{if(Get-Process sunshine -ErrorAction SilentlyContinue){return 'UNKNOWN'};return 'NOT_RUNNING'}
}
function Assert-StreamIdle { $state=Get-StreamState;if($state -eq 'SUNSHINE_SERVER_BUSY'){throw 'Aktif Moonlight yayını var. Yayından çıkıp tekrar uygulayın; mevcut oturum kesilmedi.'};if($state -notin @('SUNSHINE_SERVER_FREE','NOT_RUNNING')){throw 'Sunshine yayın durumu okunamadı; açık oturum kesilmemesi için ayarlar değiştirilmedi. Sunshine panelini kontrol edip tekrar deneyin.'} }
function Is-Admin { $p=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent());return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
function Find-Playnite {
    $roots=@((Join-Path $env:LOCALAPPDATA 'Playnite'),(Join-Path $env:LOCALAPPDATA 'OyunMerkezi\Playnite'),(Join-Path $env:ProgramFiles 'Playnite'))
    foreach($root in $roots){if(Test-Path (Join-Path $root 'Playnite.DesktopApp.exe')){return $root}}
    return ''
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
