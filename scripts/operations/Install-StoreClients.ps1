function Install-StoreClients {
    $winget=Get-Command winget.exe -ErrorAction SilentlyContinue
    if(!$winget){throw (L 'WinGet bulunamadı. Yardım sayfasındaki App Installer bağlantısını açıp kurun; ardından Eksikleri kur düğmesini yeniden kullanın.')}
    $ids=@{Steam='Valve.Steam';Epic='EpicGames.EpicGamesLauncher';EA='ElectronicArts.EADesktop';Ubisoft='Ubisoft.Connect';Xbox='Microsoft.GamingApp'}
    foreach($source in $Settings.Libraries){
        if(!$ids.ContainsKey($source)){continue}
        if($source -eq 'Epic' -and $Settings.EpicDirectInstall){continue}
        Write-Host (L '{0} başlatıcısı denetleniyor.' @(($source)))
        try {
            $p=[Diagnostics.ProcessStartInfo]::new();$p.FileName=$winget.Source;$p.Arguments='install --id '+$ids[$source]+' --exact --silent --accept-source-agreements --accept-package-agreements --disable-interactivity';$p.UseShellExecute=$false;$p.CreateNoWindow=$true;$process=[Diagnostics.Process]::Start($p);$process.WaitForExit()
            if($process.ExitCode -notin @(0,-1978335189)){throw (L 'Kurulum kodu {0}' @($process.ExitCode))}
        }catch{throw (L '{0} otomatik kurulamadı. Yardım → Başlatıcı bağlantısından resmi kurucuyu çalıştırıp bu adımı tekrar deneyin. {1}' @(($source),($_.Exception.Message)))}
    }
}