function Remove-UserIntegration {
    Assert-PlayniteClosed
    $play=Get-PlayniteDataDirectory $Settings.PlaynitePath
    $removed=@();$manual=@()
    foreach($name in @('SofaRelay','GamingCenter','OziTvTools','SofaRelaySetup','GamingCenterSetup')) {
        $directory=Join-Path $play ('Extensions\'+$name)
        $metadata=Join-Path $directory 'extension.yaml'
        if(!(Test-Path -LiteralPath $metadata)) { continue }
        $null=Assert-InRoot $metadata (Join-Path $play 'Extensions')
        $text=Get-Content -LiteralPath $metadata -Raw -Encoding UTF8
        if($text -notmatch '15378b45-7634-47ed-8570-69ad2d7a9067|e8bd5521-67bd-4600-a757-fbc0e93b385d') { continue }
        foreach($file in @('extension.yaml','SofaRelay.Core.dll','SofaRelay.Plugin.dll','SteamTvInstall.exe','center-integration.json','NativeSetup.psm1','setup.json')) {
            $path=Join-Path $directory $file
            if(Test-Path -LiteralPath $path) { $null=Assert-InRoot $path $directory;Remove-Item -LiteralPath $path -Force;$removed+=@($path) }
        }
    }
    $menu=Join-Path ([Environment]::GetFolderPath('Programs')) 'SofaRelay'
    $shell=New-Object -ComObject WScript.Shell
    foreach($name in @('SofaRelay','SofaRelay Settings','Restore Display')) {
        $file=Join-Path $menu ($name+'.lnk')
        if(Test-Path -LiteralPath $file) {
            $link=$shell.CreateShortcut($file)
            if($link.TargetPath -in @((Join-Path $Settings.InstallRoot 'SofaRelay.exe'),(Join-Path $Settings.PlaynitePath 'Playnite.FullscreenApp.exe'))) { Remove-Item -LiteralPath $file;$removed+=@($file) }
        }
    }
    $flag=Join-Path $Settings.InstallRoot 'data\watchdog-enabled.json'
    if(Test-Path -LiteralPath $flag) { Remove-Item -LiteralPath $flag }
    $manual+=@((L 'SofaRelay kapandıktan sonra taşınabilir uygulama dosyalarını silebilirsiniz. Yedekleri koruyun; oyunlar, hesaplar ve kayıtlar silinmedi.'))
    return @{Removed=$removed;ManualSteps=$manual}
}
