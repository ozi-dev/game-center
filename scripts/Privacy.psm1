Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

function Protect-DiagnosticText {
    param([AllowNull()][object]$Value,[string[]]$SensitiveNames=@([Environment]::UserName,[Environment]::MachineName))
    $text = [string]$Value
    $text = [regex]::Replace($text, '(?i)\b(?:gh[pousr]_|github_pat_)[A-Za-z0-9_]+', '<redacted-token>')
    $text = [regex]::Replace($text, '(?i)\bBearer\s+\S+', 'Bearer <redacted-token>')
    $text = [regex]::Replace($text, '(?i)\b(?:token|password|secret|api[_-]?key|authorization)\s*[:=]\s*\S+', '<redacted-credential>')
    $text = [regex]::Replace($text, '\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b', '<redacted-token>')
    $text = [regex]::Replace($text, '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b', '<redacted-email>')
    $text = [regex]::Replace($text, '(?i)(?:[A-Z]:[\\/]|\\\\)[^\r\n"<>|]*', '<redacted-path>')
    $text = [regex]::Replace($text, '(?i)/(?:Users|home)/[^\s/]+(?:/[^\s]*)?', '<redacted-path>')
    $text = [regex]::Replace($text, '\b(?:\d{1,3}\.){3}\d{1,3}\b', '<redacted-address>')
    foreach($name in $SensitiveNames) { if($name) { $text=[regex]::Replace($text,'(?i)\b'+[regex]::Escape($name)+'\b','<redacted-name>') } }
    return $text
}

function New-DiagnosticExport {
    param($Diagnosis, $Settings, [string]$Version)
    # A schema allowlist is the primary protection. Never serialize settings,
    # accounts, environment variables, provider responses or local log files.
    $names=@([Environment]::UserName,[Environment]::MachineName)
    foreach($field in @('UserName','ComputerName')) { if($Diagnosis.PSObject.Properties[$field]) { $names+=@([string]$Diagnosis.$field) } }
    $gpu = @($Diagnosis.GPU | ForEach-Object {
        [ordered]@{Name=(Protect-DiagnosticText $_.Name $names);DriverVersion=(Protect-DiagnosticText $_.DriverVersion $names)}
    })
    return [ordered]@{
        Schema=1;Version=$Version
        OS=(Protect-DiagnosticText $Diagnosis.OS $names)
        Is64Bit=[bool]$Diagnosis.Is64Bit
        GPU=$gpu
        SunshineInstalled=[bool]$Diagnosis.SunshineInstalled
        VirtualDisplayInstalled=[bool]$Diagnosis.VirtualDisplayInstalled
        GamepadDriverInstalled=[bool]$Diagnosis.GamepadDriverInstalled
        FrameworkRelease=[int]$Diagnosis.FrameworkRelease
        PlaytimeSync=[bool]$Settings.SyncPlaytime
        MouseKeyboard=[bool]$Settings.MouseKeyboard
        Client=$(if($Settings.ClientKind -in @('Shield','AndroidTV','Other')){[string]$Settings.ClientKind}else{'Other'})
        RequestedMode=[ordered]@{Width=[int]$Settings.Width;Height=[int]$Settings.Height;Hz=[int]$Settings.RefreshRate}
        Note='Account data, network addresses, computer names, user names, game paths and logs are excluded.'
    }
}

Export-ModuleMember -Function Protect-DiagnosticText,New-DiagnosticExport
