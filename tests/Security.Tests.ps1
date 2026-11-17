BeforeAll {
    $script:project=Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $project 'scripts\Common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $project 'scripts\Privacy.psm1') -Force
    . (Join-Path $project 'scripts\ConfigTransaction.ps1')
    . (Join-Path $project 'scripts\ProtectedState.ps1')
    . (Join-Path $project 'scripts\NetworkPolicy.ps1')
    . (Join-Path $project 'scripts\RecoveryTask.ps1')
    . (Join-Path $project 'scripts\IntegrationTransaction.ps1')
    . (Join-Path $project 'scripts\operations\Protected-Uninstall.ps1')
}

Describe 'Redacted diagnostic exports' {
    It 'excludes accounts, machine identifiers, paths and credentials, including injected allowed-field text' {
        $token='ghp_'+('z'*32)
        $diagnosis=[pscustomobject]@{OS='Windows test';Is64Bit=$true;GPU=@([pscustomobject]@{Name=('GPU for Alice mail alice@example.test token='+$token+' '+(Join-Path $TestDrive 'private-path'));DriverVersion='555.00'});SunshineInstalled=$true;VirtualDisplayInstalled=$true;GamepadDriverInstalled=$true;FrameworkRelease=528040;UserName='Alice';ComputerName='PRIVATE-PC';HostAddresses=@('192.0.2.88');Accounts=@{Token=$token};PlaynitePath=(Join-Path $TestDrive 'library')}
        $settings=[pscustomobject]@{SyncPlaytime=$true;MouseKeyboard=$true;ClientKind='Shield';Width=1920;Height=1080;RefreshRate=60}
        $json=New-DiagnosticExport $diagnosis $settings 'test' | ConvertTo-Json -Depth 10
        foreach($secret in @($token,'alice@example.test','PRIVATE-PC','192.0.2.88','Alice','private-path','Accounts','HostAddresses','PlaynitePath')) { $json | Should -Not -Match ([regex]::Escape($secret)) }
        $json | Should -Match '555.00'
    }
    It 'redacts bearer tokens and email addresses' {
        Protect-DiagnosticText 'Bearer example-secret contact owner@example.test' | Should -Be 'Bearer <redacted-token> contact <redacted-email>'
    }
}

Describe 'Actual stream clients versus a paused application' {
    It 'recognizes a disconnected stream even while serverinfo retains a busy app' {
        Resolve-StreamLogActivity @('Sunshine version: test','New streaming session started [active sessions: 1]','CLIENT CONNECTED','CLIENT DISCONNECTED') | Should -Be 0
    }
    It 'keeps another client active when only one of two clients disconnects' {
        Resolve-StreamLogActivity @('Sunshine version: test','New streaming session started [active sessions: 1]','CLIENT CONNECTED','New streaming session started [active sessions: 2]','CLIENT CONNECTED','CLIENT DISCONNECTED') | Should -Be 1
    }
    It 'keeps a pending connection busy and handles overlapping handshakes' {
        Resolve-StreamLogActivity @('Sunshine version: test','New streaming session started [active sessions: 1]') | Should -Be 1
        Resolve-StreamLogActivity @('Sunshine version: test','New streaming session started [active sessions: 1]','New streaming session started [active sessions: 2]','CLIENT CONNECTED','CLIENT CONNECTED','CLIENT DISCONNECTED','CLIENT DISCONNECTED') | Should -Be 0
    }
    It 'does not infer idle from a truncated or unmatched disconnect event' {
        Resolve-StreamLogActivity @('CLIENT DISCONNECTED') | Should -Be -1
        Resolve-StreamLogActivity @('encoder info only') | Should -Be -1
    }
}

Describe 'Download verification and extraction' {
    It 'rejects a bad package hash and deletes the incomplete part' {
        $package=Join-Path $TestDrive 'package';$cache=Join-Path $TestDrive 'cache'
        New-Item -ItemType Directory -Force (Join-Path $package 'manifests') | Out-Null
        Write-Json (Join-Path $package 'manifests\packages.json') @{Packages=@(@{Id='bad';Name='Bad';Version='1.0';Url='https://github.com/example/example/releases/download/v1.0/file.zip';FileName='file.zip';Sha256=('0'*64)})}
        Mock Invoke-WebRequest -ModuleName Common {param($Uri,$OutFile) [IO.File]::WriteAllText($OutFile,'wrong bytes')}
        { Get-Component bad $package $cache } | Should -Throw
        Test-Path (Join-Path $cache 'downloads\file.zip.part') | Should -BeFalse
        Test-Path (Join-Path $cache 'downloads\file.zip') | Should -BeFalse
    }
    It 'validates every ZIP member before extracting an earlier valid member' {
        Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
        $archive=Join-Path $TestDrive 'traversal.zip';$destination=Join-Path $TestDrive 'destination'
        $zip=[IO.Compression.ZipFile]::Open($archive,[IO.Compression.ZipArchiveMode]::Create)
        try {foreach($name in @('good.txt','../outside.txt')){$entry=$zip.CreateEntry($name);$stream=$entry.Open();$stream.Dispose()}} finally {$zip.Dispose()}
        { Expand-ZipSafe $archive $destination } | Should -Throw
        Test-Path (Join-Path $destination 'good.txt') | Should -BeFalse
        Test-Path (Join-Path $TestDrive 'outside.txt') | Should -BeFalse
    }
}

Describe 'Privilege boundary and rollback' {
    It 'rejects a forged restore target even if an attacker supplies a matching backup checksum' {
        $script:DataRoot=Join-Path $TestDrive 'protected-state';New-Item -ItemType Directory -Force (Join-Path $DataRoot 'backups') | Out-Null
        $script:Settings=[pscustomobject]@{VddDirectory=(Join-Path $TestDrive 'vdd')}
        Mock Get-SunshineDirectory { Join-Path $TestDrive 'sunshine' }
        $backup=Join-Path $DataRoot 'backups\fake';[IO.File]::WriteAllText($backup,'attacker content')
        $entry=[pscustomobject]@{Target=(Join-Path $TestDrive 'other-system-file');Backup=$backup;OriginalSha256=(Get-FileHash $backup).Hash}
        { Assert-ProtectedBackupEntry $entry } | Should -Throw '*unauthorized*'
    }
    It 'rejects backup bytes outside the protected backup directory' {
        $script:DataRoot=Join-Path $TestDrive 'protected-state';$script:Settings=[pscustomobject]@{VddDirectory=(Join-Path $TestDrive 'vdd')}
        Mock Get-SunshineDirectory { Join-Path $TestDrive 'sunshine' }
        Mock Assert-ComponentDirectory {}
        $backup=Join-Path $TestDrive 'user-editable';[IO.File]::WriteAllText($backup,'content')
        $entry=[pscustomobject]@{Target=(Join-Path $Settings.VddDirectory 'vdd_settings.xml');Backup=$backup;OriginalSha256=(Get-FileHash $backup).Hash}
        { Assert-ProtectedBackupEntry $entry } | Should -Throw
    }
    It 'restores earlier configuration bytes when a later setup step throws' {
        $file=Join-Path $TestDrive 'config.json';[IO.File]::WriteAllText($file,'original')
        { Invoke-ConfigurationTransaction @($file) { [IO.File]::WriteAllText($file,'changed');throw 'later step failed' } } | Should -Throw
        [IO.File]::ReadAllText($file) | Should -Be 'original'
    }
    It 'rejects a valid signature belonging to the wrong signer' {
        $script:PackageRoot=Join-Path $TestDrive 'package';New-Item -ItemType Directory -Force (Join-Path $PackageRoot 'manifests') | Out-Null
        Write-Json (Join-Path $PackageRoot 'manifests\packages.json') @{Packages=@(@{Id='signed';SignerThumbprints=@('REVIEWED')})}
        Mock Get-AuthenticodeSignature { [pscustomobject]@{Status='Valid';SignerCertificate=[pscustomobject]@{Thumbprint='OTHER'}} }
        { Assert-PackageSignature signed 'unused' } | Should -Throw '*publisher*'
    }
}

Describe 'Uninstall ownership and firewall preflight' {
    BeforeEach {
        $script:DataRoot=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $DataRoot | Out-Null
        $script:Settings=[pscustomobject]@{InstallRoot=(Join-Path $TestDrive 'runtime');RemoveOwnedComponents=$true}
        Mock Assert-PrivilegedContext {}
        Mock Assert-StreamIdle {}
        Mock Set-RecoveryTask {}
        Mock Start-CheckedProcess { throw 'No component process should run in this test.' }
    }
    It 'preserves all pre-existing/shared components without running an uninstaller' {
        Mock Restore-LanFirewallPolicy {}
        Write-Json (Join-Path $DataRoot 'ownership.json') @{Schema=1;UserRuntime=$Settings.InstallRoot;Components=@(@{Id='sunshine';InstalledByThisPackage=$false;Details=@{}},@{Id='vigem';InstalledByThisPackage=$false;Details=@{}});Tasks=@();Firewall=@()}
        $result=Protected-Uninstall
        $result.Removed.Count | Should -Be 0
        Should -Invoke Start-CheckedProcess -Times 0
        (Get-OwnershipInventory).Uninstalled | Should -BeTrue
    }
    It 'does not remove an owned device whose recorded identity is invalid' {
        Mock Restore-LanFirewallPolicy {}
        Write-Json (Join-Path $DataRoot 'ownership.json') @{Schema=1;UserRuntime=$Settings.InstallRoot;Components=@(@{Id='vdd';InstalledByThisPackage=$true;Details=@{InstanceId='ROOT\OTHER\0001'}});Tasks=@();Firewall=@()}
        $result=Protected-Uninstall
        $result.ManualSteps.Count | Should -Be 1
        Should -Invoke Start-CheckedProcess -Times 0
    }
    It 'preflights every changed firewall rule before restoring any rule' {
        # Use the actual restore implementation in this test, replacing only OS calls.
        Write-Json (Join-Path $DataRoot 'ownership.json') @{Schema=1;UserRuntime=$Settings.InstallRoot;Components=@();Tasks=@();Firewall=@(@{Name='first';Program='sunshine.exe';RemoteAddress=@('Any');Profile='Any';Enabled='True'},@{Name='second';Program='sunshine.exe';RemoteAddress=@('Any');Profile='Any';Enabled='True'})}
        Mock Get-NetFirewallRule {param($Name) New-CimInstance -Namespace root/standardcimv2 -ClassName MSFT_NetFirewallRule -ClientOnly -Property @{InstanceID=$Name}}
        Mock Get-NetFirewallApplicationFilter { [pscustomobject]@{Program='sunshine.exe'} }
        Mock Test-FirewallState {param($Rule,$Expected) $Rule.Name -eq 'first' -and $Expected.Profile -eq 'Private'}
        Mock Set-NetFirewallRule { throw 'Must not partially restore.' }
        Mock Remove-NetFirewallRule { throw 'Must not remove before preflight.' }
        { Restore-LanFirewallPolicy } | Should -Throw '*edited*'
        Should -Invoke Set-NetFirewallRule -Times 0
        Should -Invoke Remove-NetFirewallRule -Times 0
    }
}

Describe 'Task/firewall failure rollback' {
    It 'restores the previous firewall scope and ownership bytes after a later failure' {
        $script:DataRoot=Join-Path $TestDrive 'transaction-state'
        New-Item -ItemType Directory -Force -Path $DataRoot | Out-Null
        $inventory=Join-Path $DataRoot 'ownership.json'
        [IO.File]::WriteAllText($inventory,'{"original":true}')
        $script:address='Any';$script:rollbackAddress=''
        Mock Get-SofaRelayFirewallRules { New-CimInstance -Namespace root/standardcimv2 -ClassName MSFT_NetFirewallRule -ClientOnly -Property @{InstanceID='vendor';Profiles=[uint32]0;Enabled=[uint16]1} }
        Mock Get-NetFirewallAddressFilter { [pscustomobject]@{RemoteAddress=@($script:address)} }
        Mock Get-ScheduledTask { $null }
        Mock Set-NetFirewallRule {param($RemoteAddress) $script:rollbackAddress=($RemoteAddress -join ',')}
        Mock Register-ScheduledTask { throw 'No old task should be restored.' }
        Mock Unregister-ScheduledTask { throw 'No task was created in this fixture.' }
        { Invoke-IntegrationTransaction 'C:\Program Files\Sunshine' {
            $script:address='LocalSubnet'
            [IO.File]::WriteAllText($inventory,'changed')
            throw 'later failure'
        }} | Should -Throw 'later failure'
        $script:rollbackAddress | Should -Be 'Any'
        [IO.File]::ReadAllText($inventory) | Should -Be '{"original":true}'
        Should -Invoke Set-NetFirewallRule -Times 1
    }
}

Describe 'Static installer policy' {
    It 'never uses remote expression evaluation or machine-wide execution-policy changes' {
        $files=Get-ChildItem -LiteralPath (Join-Path $project 'scripts') -Recurse -File | Where-Object Extension -in '.ps1','.psm1'
        foreach($file in $files){
            $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
            $errors.Count | Should -Be 0
            $commands=@($ast.FindAll({param($node)$node -is [Management.Automation.Language.CommandAst]},$true) | ForEach-Object {$_.GetCommandName()})
            $commands | Should -Not -Contain 'Invoke-Expression'
            $commands | Should -Not -Contain 'iex'
            $commands | Should -Not -Contain 'Set-ExecutionPolicy'
        }
    }
}
