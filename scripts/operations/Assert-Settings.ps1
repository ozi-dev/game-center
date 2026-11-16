function Assert-Settings {
    $json=Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8
    $serializer=[Web.Script.Serialization.JavaScriptSerializer]::new()
    $value=$serializer.Deserialize($json,[SofaRelay.CenterSettings])
    $errors=[SofaRelay.Validation]::Settings($value)
    if($errors.Count){throw ($errors -join "`n")}
    if(!$Settings.InstallRoot){throw (L 'Kurulum klasörü seçilmedi.')}
    $architecture=if($env:PROCESSOR_ARCHITEW6432){$env:PROCESSOR_ARCHITEW6432}else{$env:PROCESSOR_ARCHITECTURE}
    if($architecture -ne 'AMD64'){throw (L 'Bu paket Intel/AMD x64 Windows içindir. ARM64 ve 32 bit Windows otomatik kurulumu desteklenmiyor.')}
}