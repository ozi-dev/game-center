function Apply-Protected {
    Assert-PrivilegedContext
    if(!(Is-Admin)){throw (L 'Bu işlem Windows yönetici onayı gerektiriyor.')}
    Assert-Settings;Assert-StreamIdle
    $framework=Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue
    if(!$framework -or $framework -lt 528040){throw (L '.NET Framework 4.8 gerekiyor. Yardım > Gereksinimler bölümündeki resmi Microsoft kurucusunu çalıştırıp yeniden deneyin.')}
    foreach($architecture in @('x64','x86')){
        $runtime=Get-ItemProperty ('HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\'+$architecture) -ErrorAction SilentlyContinue
        if(!$runtime){$runtime=Get-ItemProperty ('HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\'+$architecture) -ErrorAction SilentlyContinue}
        if(!$runtime -or $runtime.Installed -ne 1){throw (L 'Microsoft Visual C++ x64/x86 çalışma zamanı eksik. Yardım > Gereksinimler bölümündeki imzalı Microsoft kurucusunu çalıştırıp yeniden deneyin.')}
    }
    $root=Resolve-Full $Settings.InstallRoot;$reboot=$false
    $sun=Get-SunshineDirectory
    if(!$sun){
        Write-Host (L 'Sunshine kuruluyor.');$msi=Get-Component 'sunshine' $PackageRoot $DataRoot
        Assert-PackageSignature 'sunshine' $msi
        $code=Start-CheckedProcess (Join-Path $env:WINDIR 'System32\msiexec.exe') @('/i',$msi,'/qn','/norestart');if($code -in @(3010,1641)){$reboot=$true}
        Set-OwnedComponent 'sunshine' $true (Get-InstalledProductDetails 'Sunshine')
        $sun=Get-SunshineDirectory;if(!$sun){throw (L 'Sunshine kurulduktan sonra bulunamadı; bilgisayarı yeniden başlatıp Tanı çalıştırın.')}
    }
    $Settings.SunshineDirectory=$sun
    Add-Type -Path (Join-Path $PackageRoot 'SofaRelay.Native.dll')
    Assert-ComponentDirectory $sun
    if(Test-Path -LiteralPath (Join-Path $sun 'config')){Assert-ComponentDirectory (Join-Path $sun 'config')}
    if($Settings.VirtualDisplay -and (Test-Path -LiteralPath $Settings.VddDirectory)){Assert-ComponentDirectory $Settings.VddDirectory}
    $vdd=@(Get-PnpDevice -Class Display -PresentOnly | Where-Object {$_.FriendlyName -match 'Virtual Display|VDD by|IddSample'})
    Save-DisplayBaseline
    if($Settings.Gamepad -and !@(Get-PnpDevice -PresentOnly | Where-Object {$_.InstanceId -like 'ROOT\VIGEMBUS*' -or $_.FriendlyName -match 'Virtual Gamepad Emulation Bus|ViGEmBus|Nefarius.*Virtual HID'}).Count){
        Write-Host (L 'Kumanda sürücüsü kuruluyor.');$exe=Get-Component 'vigem' $PackageRoot $DataRoot
        Assert-PackageSignature 'vigem' $exe
        $code=Start-CheckedProcess $exe @('/install','/quiet','/norestart');if($code -in @(3010,1641)){$reboot=$true}
        Set-OwnedComponent 'vigem' $true (Get-InstalledProductDetails 'Nefarius Virtual Gamepad Emulation Bus Driver')
    }
    if($Settings.VirtualDisplay -and !$vdd.Count){
        if((Resolve-Full $Settings.VddDirectory).TrimEnd('\') -ne 'C:\VirtualDisplayDriver'){throw (L 'Yeni VDD kurulumu için sürücünün standart C:\VirtualDisplayDriver klasörünü seçin. Başka klasör seçimi zaten kurulu sürücünün gerçek ayar konumu içindir.')}
        $archive=Get-Component 'vdd' $PackageRoot $DataRoot;$unpack=Join-Path $DataRoot 'staging\vdd';Expand-ZipSafe $archive $unpack
        $cat=Get-ChildItem $unpack -Recurse -Filter mttvdd.cat | Select-Object -First 1
        if(!$cat){throw (L 'Sanal ekran sürücüsünün imzası doğrulanamadı.')}
        Assert-PackageSignature 'vdd' $cat.FullName
        $driverDir=Resolve-Full $Settings.VddDirectory
        [SofaRelay.Security.BrokerPaths]::ProtectDirectory($driverDir)
        if(Test-Path (Join-Path $driverDir 'MttVDD.inf')){throw (L 'Eski sürücü klasörü var ancak aygıt görünmüyor. Tanı sayfasından sürücüyü kontrol edin; dosyalar üzerine kurulmadı.')}
        New-Item -ItemType Directory -Force -Path $driverDir | Out-Null
        Copy-Item -Path (Join-Path $cat.Directory.FullName '*') -Destination $driverDir -Force
        Add-Type -Path (Join-Path $PackageRoot 'SofaRelay.Native.dll')
        $installed=[NativeVddInstall]::Install((Join-Path $driverDir 'MttVDD.inf'))
        if($installed -match 'RebootRequired=True'){$reboot=$true}
        Write-Json (Join-Path $DataRoot 'installed-driver.json') @{Instance=$installed;InstalledByThisPackage=$true}
        Set-OwnedComponent 'vdd' $true @{InstanceId=($installed -split '\|')[0]}
        $baseline=Read-Json (Join-Path $DataRoot 'display-baseline.json')
        [void][NativeDisplayState]::Apply($baseline.PathCount,$baseline.PathsBase64,$baseline.ModeCount,$baseline.ModesBase64,$false,$true)
    }
    $transactionFiles=@((Join-Path $sun 'config\sunshine.conf'),(Join-Path $sun 'config\apps.json'),(Join-Path $Settings.VddDirectory 'vdd_settings.xml'))
    return Invoke-ConfigurationTransaction $transactionFiles {
    if($Settings.VirtualDisplay){
        $file=Join-Path (Resolve-Full $Settings.VddDirectory) 'vdd_settings.xml'
        if(Test-Path $file){[void](Backup-ProtectedFile $file);$xml=[xml](Get-Content $file -Raw -Encoding UTF8)}else{[void](Backup-ProtectedFile $file);$xml=[xml]'<vdd_settings><monitors><count>1</count></monitors><gpu><friendlyname></friendlyname></gpu><global><g_refresh_rate>60</g_refresh_rate></global><resolutions></resolutions><options><HardwareCursor>true</HardwareCursor><HDRPlus>false</HDRPlus></options></vdd_settings>'}
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
    [void](Backup-ProtectedFile $config);[void](Backup-ProtectedFile $appsFile)
    $values=[ordered]@{keyboard=$(if($Settings.MouseKeyboard){'enabled'}else{'disabled'});mouse=$(if($Settings.MouseKeyboard){'enabled'}else{'disabled'});controller=$(if($Settings.Gamepad){'enabled'}else{'disabled'});dd_config_revert_on_disconnect=$(if($Settings.RestoreDisplay){'enabled'}else{'disabled'})}
    if($Settings.VirtualDisplay){$values.output_name=$Settings.DisplayId;$values.dd_configuration_option=if($Settings.TurnOffPhysicalMonitor){'ensure_only_display'}else{'ensure_primary'}}else{$values.output_name='';$values.dd_configuration_option='disabled'}
    $values.dd_resolution_option=if($Settings.AutomaticDisplayMode){'auto'}else{'manual'};$values.dd_refresh_rate_option=if($Settings.AutomaticDisplayMode){'auto'}else{'manual'}
    $values.dd_manual_resolution=[string]$Settings.Width+'x'+$Settings.Height;$values.dd_manual_refresh_rate=[string]$Settings.RefreshRate
    if($Settings.LANOnly){$values.upnp='disabled';$values.origin_web_ui_allowed='pc'}
    $old=if(Test-Path $config){[IO.File]::ReadAllText($config)}else{''};if($old -notmatch '(?m)^\s*gamepad_driver\s*='){$values.gamepad_driver='vigembus'};$new=Set-ConfValues $old $values
    $apps=Read-Json $appsFile;if(!$apps){$apps=[pscustomobject]@{env=[pscustomobject]@{};apps=@()}}
    $managed=@('Oyun Kütüphanesi - Playnite','Oyun Merkezi','Game Center','SofaRelay','Masaüstü - Desktop','Desktop','Game Library - Playnite','Bibliothèque - Playnite','Bureau','Biblioteca - Playnite','Escritorio')
    $retained=@();if($Settings.PreserveExistingApps){$retained=@($apps.apps | Where-Object {$_.name -notin $managed})}
    if($Settings.ShowDesktop){$retained+=@([pscustomobject]@{name='Desktop';'image-path'=(Join-Path $root 'assets\desktop.png')})}
    if($Settings.ShowLibrary){$retained+=@([pscustomobject]@{name='Game Library - Playnite';cmd=('"'+(Join-Path $Settings.PlaynitePath 'Playnite.FullscreenApp.exe')+'" --startfullscreen --hidesplashscreen');'working-dir'=$Settings.PlaynitePath;'auto-detach'=$true;'wait-all'=$true;'image-path'=(Join-Path $root 'assets\library.png')})}
    $apps.apps=$retained
    [IO.File]::WriteAllText($config,$new,[Text.UTF8Encoding]::new($false));Write-Json $appsFile $apps
    Mark-Applied $config $DataRoot;Mark-Applied $appsFile $DataRoot
    Write-Json $SettingsPath $Settings
    return Invoke-IntegrationTransaction $sun {
    Set-LanFirewallPolicy $sun ([bool]$Settings.LANOnly)
    Set-RecoveryTask ([bool]($Settings.RecoveryWatchdog -and $Settings.VirtualDisplay -and $Settings.TurnOffPhysicalMonitor -and $Settings.RestoreDisplay))
    Restart-Service SunshineService
    return @{Applications=@($retained.name);DisplayId=$Settings.DisplayId;VirtualDisplay=$Settings.VirtualDisplay;PhysicalMonitorOff=$Settings.TurnOffPhysicalMonitor;Width=$Settings.Width;Height=$Settings.Height;RefreshRate=$Settings.RefreshRate;ClientSettingsRequired=$true;RebootRequired=$reboot;DisplayBaseline=(Read-Json (Join-Path $DataRoot 'display-baseline.json'));RecoveryWatchdog=([bool]($Settings.RecoveryWatchdog -and $Settings.VirtualDisplay -and $Settings.TurnOffPhysicalMonitor -and $Settings.RestoreDisplay))}
    }
    }
}
