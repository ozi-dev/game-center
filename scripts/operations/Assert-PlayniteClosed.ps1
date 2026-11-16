function Assert-PlayniteClosed {
    if(Get-Process Playnite.DesktopApp,Playnite.FullscreenApp -ErrorAction SilentlyContinue){throw (L 'Playnite açık. Menüsünden Çıkış seçip bu adımı yeniden çalıştırın; oyunlarınız zorla kapatılmadı.')}
}