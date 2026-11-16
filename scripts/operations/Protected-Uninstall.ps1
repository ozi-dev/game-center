function Protected-Uninstall {
    Assert-PrivilegedContext
    Assert-StreamIdle
    $inventory=Get-OwnershipInventory
    Set-RecoveryTask $false
    Restore-LanFirewallPolicy
    $restored=@()
    if(Test-Path -LiteralPath (Join-Path $DataRoot 'backup-journal.json')) { $restored=@((Restore-Protected).Restored) }
    $removed=@();$manual=@();$reboot=$false
    if($Settings.RemoveOwnedComponents) {
        foreach($component in @($inventory.Components | Where-Object InstalledByThisPackage)) {
            switch($component.Id) {
                'vdd' {
                    $instance=[string]$component.Details.InstanceId
                    if($instance -notmatch '^ROOT\\DISPLAY\\[A-Za-z0-9]+$') { $manual+=@((L 'Sanal ekran aygıtının kimliği doğrulanamadı. Aygıt Yöneticisi üzerinden elle inceleyin.'));continue }
                    $device=Get-PnpDevice -InstanceId $instance -ErrorAction SilentlyContinue
                    if($device) {
                        $hardware=Get-PnpDeviceProperty -InstanceId $instance -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop
                        if($hardware.Data -notcontains 'Root\MttVDD') { throw 'The recorded VDD instance is now a different device.' }
                        $null=Start-CheckedProcess (Join-Path $env:WINDIR 'System32\pnputil.exe') @('/remove-device',$instance)
                        $reboot=$true
                    }
                    $removed+=@('vdd-device')
                    $manual+=@((L 'Sürücü deposu ve C:\VirtualDisplayDriver dosyaları korundu. Başka sanal ekran kullanmıyorsa Aygıt Yöneticisi üzerinden elle kaldırabilirsiniz.'))
                }
                'sunshine' {
                    $code=[string]$component.Details.ProductCode
                    if($code -notmatch '^\{[A-Fa-f0-9-]{36}\}$') { $manual+=@((L 'Sunshine kurulumunun sahipliği veya sürümü doğrulanamadı. Artık gerekmiyorsa Windows Yüklü uygulamalar bölümünden elle kaldırın.'));continue }
                    $key=Join-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' $code
                    $record=Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
                    if($record -and $record.DisplayName -match '^Sunshine' -and $component.Details.PSObject.Properties['Version'] -and $record.DisplayVersion -eq $component.Details.Version) {
                        $exitCode=Start-CheckedProcess (Join-Path $env:WINDIR 'System32\msiexec.exe') @('/x',$code,'/qn','/norestart')
                        $reboot=$reboot -or $exitCode -in @(3010,1641);$removed+=@('sunshine')
                    } else { $manual+=@((L 'Sunshine kurulumunun sahipliği veya sürümü doğrulanamadı. Artık gerekmiyorsa Windows Yüklü uygulamalar bölümünden elle kaldırın.')) }
                }
                'vigem' {
                    $current=Get-InstalledProductDetails 'Nefarius Virtual Gamepad Emulation Bus Driver'
                    if(!$component.Details.PSObject.Properties['ProductCode'] -or !$component.Details.PSObject.Properties['Version'] -or !$current.ProductCode -or !$current.Version -or $current.ProductCode -ne $component.Details.ProductCode -or $current.Version -ne $component.Details.Version) { $manual+=@((L 'ViGEmBus sahipliği veya doğrulanmış kaldırıcı bulunamadı. Başka uygulamalar kullanmıyorsa Windows Yüklü uygulamalar bölümünden elle kaldırın.'));continue }
                    $item=@((Read-Json (Join-Path $PackageRoot 'manifests\packages.json')).Packages | Where-Object Id -eq 'vigem')[0]
                    $installer=Join-Path $DataRoot ('downloads\'+$item.FileName)
                    if(!(Test-Path -LiteralPath $installer) -or (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ne $item.Sha256) { $manual+=@((L 'ViGEmBus sahipliği veya doğrulanmış kaldırıcı bulunamadı. Başka uygulamalar kullanmıyorsa Windows Yüklü uygulamalar bölümünden elle kaldırın.'));continue }
                    Assert-PackageSignature 'vigem' $installer
                    $exitCode=Start-CheckedProcess $installer @('/uninstall','/quiet','/norestart')
                    $reboot=$reboot -or $exitCode -in @(3010,1641);$removed+=@('vigem')
                }
            }
        }
    }
    $inventory=Get-OwnershipInventory
    $inventory | Add-Member -NotePropertyName Uninstalled -NotePropertyValue $true -Force
    Write-Json (Join-Path $DataRoot 'ownership.json') $inventory
    return @{Restored=$restored;Removed=$removed;ManualSteps=$manual;RebootRequired=$reboot;SharedComponentsPreserved=(!$Settings.RemoveOwnedComponents)}
}
