param([string]$BuildDirectory='build',[string]$ArtifactDirectory='dist')
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
. (Join-Path $root 'scripts\maintainer\BuildSupport.ps1')
Import-Module (Join-Path $root 'scripts\Common.psm1') -Force -DisableNameChecking
$version=(Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$build=Join-Path $root $BuildDirectory
$output=Assert-InRoot (Join-Path $root $ArtifactDirectory) $root
New-Item -ItemType Directory -Force -Path $output | Out-Null
$zip=Join-Path $output ('SofaRelay-'+$version+'-Windows-x64.zip')
if(Test-Path -LiteralPath $zip) { throw 'A versioned artifact already exists. Published release assets must not be overwritten.' }
$public=@(Get-PublicSourceFiles $root)
$files=[ordered]@{}
foreach($name in @('Installer.exe','SofaRelay.exe','SofaRelay.Core.dll','SofaRelay.Native.dll','SofaRelay.Broker.exe','SofaRelay.Broker.exe.config','VERSION','BUILD-INFO.json')) { $files[$name]=Join-Path $build $name }
foreach($name in $public) {
    if($name -match '^(scripts|assets|locales|manifests|docs)/' -or $name -in @('README.md','LICENSE.txt','THIRD-PARTY.md','CHANGELOG.md','CONTRIBUTING.md','SECURITY.md')) { $files[$name]=Join-Path $build $name }
    if($name -notmatch '^(src|tests|assets/plugin|assets/compat)/.*\.(dll|exe)$') { $files['source/'+$name]=Join-Path $root $name }
}
foreach($name in @('SofaRelay.Core.dll','SofaRelay.Plugin.dll','SteamTvInstall.exe')) { $files['assets/plugin/'+$name]=Join-Path $build ('assets\plugin\'+$name) }
$files['assets/compat/LegacyLauncher.exe']=Join-Path $build 'assets\compat\LegacyLauncher.exe'
$files['source/SOURCE-FILES.txt']=Join-Path $build 'SOURCE-FILES.txt'
$start=Join-Path $output 'START-HERE.txt'
[IO.File]::WriteAllText($start,("SOFARELAY $version - PUBLIC BETA`n`nExtract the complete ZIP, then run Installer.exe.`nRead docs/RELEASE-STATUS.md for tested scenarios and remaining hardware checks.`nNew installations keep the physical monitor enabled; monitor shutdown is opt-in.`nStart menu: SofaRelay > SofaRelay Settings / Restore Display.`nRead docs/VERIFYING.md before running an unsigned download.`nOffline guides: docs/guides/en.html, tr.html, fr.html, es.html.`nUninstall and recovery: docs/UNINSTALL.md and docs/TROUBLESHOOTING.md.`nKeep your account data, game libraries and backups.`nNo games, firmware, keys, credentials or personal settings are included.`n"),[Text.UTF8Encoding]::new($false))
$files['START-HERE.txt']=$start
$blocked=@([Environment]::GetFolderPath('UserProfile'))
$settings=Read-Json (Join-Path $root 'data\settings.json')
if($settings){foreach($key in @('DisplayId','DeviceAddress')){if($settings.PSObject.Properties[$key] -and $settings.$key){$blocked+=@([string]$settings.$key)}}}
foreach($name in $files.Keys) {
    $file=[string]$files[$name]
    if(!(Test-Path -LiteralPath $file -PathType Leaf)) { throw "Required package file is missing: $name" }
    if($name -match '(?i)(^|/)(data|downloads|reports|library|ExtensionsData)(/|$)|\.(nsp|nup|xci|rom|sav|db)$|prod\.keys|title\.keys|playtime\.bin|sunshine_state\.json') { throw "Private payload forbidden: $name" }
    if([IO.Path]::GetExtension($file) -in @('.cs','.ps1','.psm1','.py','.json','.yaml','.html','.md','.txt')) {
        $text=[IO.File]::ReadAllText($file).Replace('\\','\').Replace('/','\')
        foreach($marker in $blocked){if($marker -and $text.IndexOf($marker,[StringComparison]::OrdinalIgnoreCase) -ge 0){throw "Personal data detected: $name"}}
    }
}
$internal=Join-Path $output 'payload-SHA256SUMS.txt'
$lines=@($files.Keys | Sort-Object -CaseSensitive | ForEach-Object { (Get-FileHash -LiteralPath ([string]$files[$_]) -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+$_ })
[IO.File]::WriteAllText($internal,($lines -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
$files['SHA256SUMS.txt']=$internal
New-DeterministicZip $zip $files
$digest=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
$checksum=$digest+'  '+[IO.Path]::GetFileName($zip)+"`n"
[IO.File]::WriteAllText(($zip+'.sha256'),$checksum,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $output 'SHA256SUMS.txt'),$checksum,[Text.UTF8Encoding]::new($false))
New-Item -ItemType Directory -Force -Path (Join-Path $root 'reports') | Out-Null
Write-Json (Join-Path $root 'reports\release.json') @{Zip=$zip;Version=$version;Files=$files.Count;Size=(Get-Item -LiteralPath $zip).Length;SHA256=$digest}
Write-Output "Package ready: $zip; $($files.Count) allowlisted files; SHA256 $digest"
