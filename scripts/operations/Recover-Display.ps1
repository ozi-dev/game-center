function Recover-Display {
    Add-Type -Path (Join-Path $PackageRoot 'SofaRelay.Native.dll')
    $path=Join-Path $DataRoot 'display-baseline.json';if(!(Test-Path -LiteralPath $path)){throw (L 'Henüz bir fiziksel ekran yedeği yok. Önce Yayın ayarlarını uygulayın.')}
    $state=Read-DisplaySnapshot $path
    $code=[NativeDisplayState]::Restore($state,$false)
    if($code -ne 0){throw (L 'Ekran düzeni geri getirilemedi (Windows kodu {0}). Windows ekran ayarlarında fiziksel monitörü etkinleştirin.' @(($code)))}
    return @{DisplayRestored=$true}
}
