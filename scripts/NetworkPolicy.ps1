function Get-SofaRelayFirewallRules {
    param([string]$Program)
    foreach($filter in @(Get-NetFirewallApplicationFilter -Program $Program -ErrorAction SilentlyContinue)) {
        @($filter | Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object {$_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow'})
    }
}

function Test-FirewallState {
    param($Rule,$Expected)
    $addresses=@(($Rule | Get-NetFirewallAddressFilter).RemoteAddress)
    return (($addresses -join ',') -eq (@($Expected.RemoteAddress) -join ',') -and [string]$Rule.Profile -eq [string]$Expected.Profile -and [string]$Rule.Enabled -eq [string]$Expected.Enabled)
}

function Set-LanFirewallPolicy {
    param([string]$Sunshine,[bool]$Enabled)
    if(!$Enabled) { Restore-LanFirewallPolicy;return }
    $inventory=Get-OwnershipInventory
    $program=Join-Path $Sunshine 'sunshine.exe'
    $prefix='SofaRelay-'+[IO.Path]::GetFileName($DataRoot)
    $old=@($inventory.Firewall)
    $rules=@(Get-SofaRelayFirewallRules $program)
    foreach($rule in $rules) {
        if($rule.Name -like ($prefix+'*')) { continue }
        if(!@($old | Where-Object Name -eq $rule.Name).Count) {
            $old+=@([pscustomobject]@{Name=$rule.Name;Program=$program;RemoteAddress=@(($rule | Get-NetFirewallAddressFilter).RemoteAddress);Profile=[string]$rule.Profile;Enabled=[string]$rule.Enabled})
        }
    }
    # Save originals before the first mutation, including crash recovery.
    $inventory.Firewall=$old
    $inventory | Add-Member -NotePropertyName FirewallPrefix -NotePropertyValue $prefix -Force
    Write-Json (Join-Path $DataRoot 'ownership.json') $inventory
    foreach($rule in $rules) { $rule | Set-NetFirewallRule -RemoteAddress LocalSubnet -Profile Private -Enabled True }
    foreach($protocol in @('TCP','UDP')) {
        $name=$prefix+'-'+$protocol
        $existing=Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue
        if($existing) {
            if(@(($existing | Get-NetFirewallApplicationFilter).Program) -notcontains $program) { throw 'A SofaRelay firewall name is owned by another program.' }
            $existing | Set-NetFirewallRule -RemoteAddress LocalSubnet -Profile Private -Enabled True
        } else {
            # Program-scoped rules also work with custom Sunshine ports.
            New-NetFirewallRule -Name $name -DisplayName ('SofaRelay LAN '+$protocol) -Group 'SofaRelay' -Program $program -Direction Inbound -Action Allow -Protocol $protocol -LocalPort Any -RemoteAddress LocalSubnet -Profile Private | Out-Null
        }
    }
}

function Restore-LanFirewallPolicy {
    $inventory=Get-OwnershipInventory
    $prefix='SofaRelay-'+[IO.Path]::GetFileName($DataRoot)
    $owned=@()
    if($inventory.PSObject.Properties['FirewallPrefix'] -and $inventory.FirewallPrefix) {
        if($inventory.FirewallPrefix -ne $prefix) { throw 'Firewall inventory identity changed.' }
        $sun=Get-SunshineDirectory
        foreach($suffix in @('TCP','UDP')) {
            $rule=Get-NetFirewallRule -Name ($prefix+'-'+$suffix) -ErrorAction SilentlyContinue
            if($rule) {
                if(!$sun -or @(($rule | Get-NetFirewallApplicationFilter).Program) -notcontains (Join-Path $sun 'sunshine.exe') -or !(Test-FirewallState $rule @{RemoteAddress=@('LocalSubnet');Profile='Private';Enabled='True'})) { throw 'An owned firewall rule changed after setup; restore stopped.' }
                $owned+=@($rule)
            }
        }
    }
    $restore=@()
    # Preflight all rules before changing the first one.
    foreach($original in @($inventory.Firewall)) {
        $rule=Get-NetFirewallRule -Name $original.Name -ErrorAction SilentlyContinue
        if(!$rule) { continue }
        if(@(($rule | Get-NetFirewallApplicationFilter).Program) -notcontains $original.Program) { throw 'A firewall rule now belongs to another program; restore stopped.' }
        if(Test-FirewallState $rule $original) { continue }
        if(!(Test-FirewallState $rule @{RemoteAddress=@('LocalSubnet');Profile='Private';Enabled='True'})) { throw 'A firewall rule was edited after setup; restore stopped.' }
        $restore+=@(@{Rule=$rule;Original=$original})
    }
    foreach($rule in $owned) { $rule | Remove-NetFirewallRule }
    foreach($item in $restore) { $item.Rule | Set-NetFirewallRule -RemoteAddress $item.Original.RemoteAddress -Profile $item.Original.Profile -Enabled $item.Original.Enabled }
    $inventory.Firewall=@()
    $inventory | Add-Member -NotePropertyName FirewallPrefix -NotePropertyValue '' -Force
    Write-Json (Join-Path $DataRoot 'ownership.json') $inventory
}
