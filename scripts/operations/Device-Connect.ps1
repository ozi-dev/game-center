function Device-Connect {
    if(!$Settings.DeviceAddress){throw (L 'Shield/TV IP adresini girin.')}
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