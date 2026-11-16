Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

function Assert-PrivilegedContext {
    $version = (Get-Content -LiteralPath (Join-Path $PackageRoot 'VERSION') -Raw).Trim()
    $expected = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) ('SofaRelay\Broker\'+$version)
    if((Resolve-Full $PackageRoot) -ne (Resolve-Full $expected)) { throw 'Privileged actions must run from the protected SofaRelay broker installation.' }
    $null = Assert-InRoot $DataRoot (Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'SofaRelay')
    $identity = Read-Json (Join-Path $DataRoot 'identity.json')
    if(!$identity -or $identity.RuntimeRoot -ne $Settings.InstallRoot -or $identity.UserSid -ne $env:SOFARELAY_REQUEST_USER_SID) { throw 'Protected installation identity does not match the request.' }
}

function Get-ProtectedFileTargets {
    $sunshine = Get-SunshineDirectory
    $targets = @((Join-Path $Settings.VddDirectory 'vdd_settings.xml'))
    if($sunshine) { $targets += @((Join-Path $sunshine 'config\sunshine.conf'),(Join-Path $sunshine 'config\apps.json')) }
    return @($targets | ForEach-Object { Resolve-Full $_ })
}

function Assert-ComponentDirectory {
    param([string]$Directory)
    [SofaRelay.Security.BrokerPaths]::RequireAdminDirectory($Directory)
}

function Assert-ProtectedBackupEntry {
    param($Entry)
    $target = Resolve-Full $Entry.Target
    if($target -notin @(Get-ProtectedFileTargets)) { throw 'A protected backup targets an unauthorized file.' }
    $null=Assert-InRoot $target (Split-Path -Parent $target)
    Assert-ComponentDirectory (Split-Path -Parent $target)
    if($Entry.PSObject.Properties['OriginalExists'] -and !$Entry.OriginalExists) { return }
    $null = Assert-InRoot $Entry.Backup (Join-Path $DataRoot 'backups')
    if(!(Test-Path -LiteralPath $Entry.Backup) -or (Get-FileHash -LiteralPath $Entry.Backup -Algorithm SHA256).Hash -ne $Entry.OriginalSha256) { throw 'The protected backup is missing or its checksum changed.' }
}

function Backup-ProtectedFile {
    param([string]$File)
    if((Resolve-Full $File) -notin @(Get-ProtectedFileTargets)) { throw 'Unauthorized protected backup target.' }
    if(Test-Path -LiteralPath $File) { return Backup-File $File $DataRoot }
    $path=Join-Path $DataRoot 'backup-journal.json'
    $journal=Read-Json $path
    $entries=@();if($journal){$entries=@($journal.Entries)}
    $entries+=@([pscustomobject]@{Time=(Get-Date).ToString('o');Target=$File;Backup=$null;OriginalExists=$false;OriginalSha256=$null;AppliedSha256=$null})
    Write-Json $path @{Entries=$entries}
    return $null
}

function Get-InstalledProductCode {
    param([string]$Name)
    foreach($key in @(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue)) {
        $item=Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
        if($item.PSObject.Properties['DisplayName'] -and $item.DisplayName -eq $Name -and $key.PSChildName -match '^\{[A-Fa-f0-9-]{36}\}$') { return $key.PSChildName }
    }
    return ''
}

function Get-OwnershipInventory {
    $value = Read-Json (Join-Path $DataRoot 'ownership.json')
    if(!$value) { return [pscustomobject]@{Schema=1;Components=@();Tasks=@();Firewall=@();UserRuntime=$Settings.InstallRoot} }
    if($value.UserRuntime -ne $Settings.InstallRoot) { throw 'Ownership inventory belongs to another installation.' }
    return $value
}

function Get-InstalledProductDetails {
    param([string]$Name)
    $code=Get-InstalledProductCode $Name
    $version=''
    if($code) {
        $record=Get-ItemProperty -LiteralPath (Join-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' $code) -ErrorAction SilentlyContinue
        if($record -and $record.PSObject.Properties['DisplayVersion']){$version=[string]$record.DisplayVersion}
    }
    return @{ProductCode=$code;Version=$version}
}

function Set-OwnedComponent {
    param([string]$Id,[bool]$InstalledByThisPackage,$Details)
    $inventory = Get-OwnershipInventory
    $remaining = @($inventory.Components | Where-Object Id -ne $Id)
    $inventory.Components = @($remaining)+@([pscustomobject]@{Id=$Id;InstalledByThisPackage=$InstalledByThisPackage;Details=$Details})
    Write-Json (Join-Path $DataRoot 'ownership.json') $inventory
}

function Assert-PackageSignature {
    param([string]$Id,[string]$File)
    $manifest = Read-Json (Join-Path $PackageRoot 'manifests\packages.json')
    $item = @($manifest.Packages | Where-Object Id -eq $Id)[0]
    if(!$item.PSObject.Properties['SignerThumbprints'] -or !$item.SignerThumbprints.Count) { throw 'The package has no reviewed signer identity.' }
    $signature = Get-AuthenticodeSignature -LiteralPath $File
    if([string]$signature.Status -ne 'Valid' -or !$signature.SignerCertificate -or $signature.SignerCertificate.Thumbprint -notin $item.SignerThumbprints) { throw 'Package signature or expected publisher identity verification failed.' }
}

function Restore-UserConfiguration {
    param([switch]$PreflightOnly)
    $journal = Read-Json (Join-Path $DataRoot 'backup-journal.json')
    if(!$journal) { return @{Restored=@();LegacyProtectedBackups=@()} }
    $userRoots = @((Resolve-Full $Settings.InstallRoot),(Resolve-Full (Get-PlayniteDataDirectory $Settings.PlaynitePath)))
    $legacy = @(); $groups = @()
    foreach($group in @($journal.Entries | Group-Object Target)) {
        $first = $group.Group | Select-Object -First 1
        $last = $group.Group | Select-Object -Last 1
        $target = Resolve-Full $first.Target
        $allowed = @($userRoots | Where-Object { $target.StartsWith($_.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) })
        if(!$allowed.Count -or [IO.Path]::GetExtension($target) -notin @('.json','.xml','.ini','.cfg')) { $legacy += @($target); continue }
        $null = Assert-InRoot $first.Backup (Join-Path $DataRoot 'backups')
        if(!(Test-Path -LiteralPath $first.Backup) -or (Get-FileHash -LiteralPath $first.Backup -Algorithm SHA256).Hash -ne $first.OriginalSha256) { throw 'A user configuration backup failed verification.' }
        $null=Assert-InRoot $target $allowed[0]
        if($last.AppliedSha256 -and (Test-Path -LiteralPath $target)) {
            $hash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
            if($hash -ne $last.AppliedSha256 -and $hash -ne $first.OriginalSha256){throw 'A user configuration changed after installation; restore stopped without overwriting it.'}
        }
        $groups += @($group)
    }
    $restored = @()
    if(!$PreflightOnly) {
        foreach($group in $groups) { $first=$group.Group | Select-Object -First 1; Copy-Item -LiteralPath $first.Backup -Destination $first.Target -Force; $restored+=@($first.Target) }
    }
    return @{Restored=$restored;LegacyProtectedBackups=$legacy}
}
