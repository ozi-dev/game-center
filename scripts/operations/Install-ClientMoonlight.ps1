function Install-ClientMoonlight {
    $device=Device-Connect
    if(!$device.MoonlightInstalled){$apk=Get-Component 'moonlight' $PackageRoot $DataRoot;[void](Start-CheckedProcess $device.ADB @('-s',$device.Address,'install','-r',$apk))}
    [void](Start-CheckedProcess $device.ADB @('-s',$device.Address,'shell','am','start','-n','com.limelight/.PcView'))
    return @{MoonlightReady=$true;PairingRequired=$true}
}