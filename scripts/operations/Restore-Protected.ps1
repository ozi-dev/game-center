function Restore-Protected {
    Assert-PrivilegedContext
    if(!(Is-Admin)){throw (L 'Windows yönetici onayı gerekiyor.')}
    Assert-StreamIdle
    $journal=Read-Json (Join-Path $DataRoot 'backup-journal.json');if(!$journal){throw (L 'Geri alınacak yedek bulunamadı.')}
    $restored=@();$groups=$journal.Entries | Group-Object Target
    foreach($group in $groups){
        $first=$group.Group | Select-Object -First 1;$last=$group.Group | Select-Object -Last 1
        Assert-ProtectedBackupEntry $first
        if($last.AppliedSha256 -and (Test-Path $last.Target)) {
            $current=(Get-FileHash -LiteralPath $last.Target -Algorithm SHA256).Hash
            if($current -ne $last.AppliedSha256 -and $current -ne $first.OriginalSha256){throw (L '{0} kurulumdan sonra değiştirilmiş. Üzerine yazılmadı; yedeği inceleyin.' @(($last.Target)))}
        }
    }
    foreach($group in $groups){
        $first=$group.Group | Select-Object -First 1
        if($first.PSObject.Properties['OriginalExists'] -and !$first.OriginalExists) { if(Test-Path -LiteralPath $first.Target) { Remove-Item -LiteralPath $first.Target -Force } }
        else { Write-BytesAtomic $first.Target ([IO.File]::ReadAllBytes($first.Backup)) }
        $restored+=@($first.Target)
    }
    if(Get-Service SunshineService -ErrorAction SilentlyContinue){Restart-Service SunshineService}
    return @{Restored=$restored;DriverUninstalled=$false}
}
