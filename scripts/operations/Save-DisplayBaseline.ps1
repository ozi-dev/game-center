function Save-DisplayBaseline {
    $file=Join-Path $DataRoot 'display-baseline.json'
    Add-Type -Path (Join-Path $PackageRoot 'SofaRelay.Native.dll')
    $state=[NativeDisplayState]::Capture($true)
    if($Settings.TurnOffPhysicalMonitor -and !@($state.Displays | Where-Object {$_.Active -and $_.Name -notmatch 'VDD|Virtual'}).Count){throw (L 'Şu anda yalnız sanal ekran aktif. Fiziksel ekran düzenine dönüp yeniden uygulayın. Fiziksel monitörü olmayan bilgisayarda monitör kapatma seçeneğini kapatın.')}
    Write-Json $file $state
}
