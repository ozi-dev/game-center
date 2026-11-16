function Recover-Display {
    Add-Type -Path (Join-Path $PackageRoot 'SofaRelay.Native.dll')
    $state=Read-Json (Join-Path $DataRoot 'display-baseline.json');if(!$state){throw (L 'Henüz bir fiziksel ekran yedeği yok. Önce Yayın ayarlarını uygulayın.')}
    $code=[NativeDisplayState]::Apply($state.PathCount,$state.PathsBase64,$state.ModeCount,$state.ModesBase64,$false,$true)
    if($code -ne 0){throw (L 'Ekran düzeni geri getirilemedi (Windows kodu {0}). Windows ekran ayarlarında fiziksel monitörü etkinleştirin.' @(($code)))}
    return @{DisplayRestored=$true}
}