function Initialize-Runtime {
    $target=Resolve-Full $Settings.InstallRoot
    if($target -eq [IO.Path]::GetPathRoot($target)){throw (L 'Sürücü kökü kurulum klasörü olarak kullanılamaz.')}
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    if($target.TrimEnd('\') -ne $PackageRoot.TrimEnd('\')){
        foreach($name in @('SofaRelay.exe','SofaRelay.Core.dll','SofaRelay.Native.dll','SofaRelay.Broker.exe','SofaRelay.Broker.exe.config','VERSION','scripts','assets','locales','manifests','docs','README.md','LICENSE.txt','THIRD-PARTY.md')){
            $source=Join-Path $PackageRoot $name;if(Test-Path -LiteralPath $source){$destination=Join-Path $target $name;if((Get-Item $source).PSIsContainer){New-Item -ItemType Directory -Force -Path $destination | Out-Null;Copy-Item -Path (Join-Path $source '*') -Destination $destination -Recurse -Force}else{Copy-Item -LiteralPath $source -Destination $destination -Force}}
        }
    }
    $destination=Join-Path $target 'data\settings.json';Write-Json $destination $Settings
    $legacyEntry=Join-Path $target 'OyunMerkezi.exe'
    if(Test-Path -LiteralPath $legacyEntry){[void](Backup-File $legacyEntry $DataRoot);Copy-Item -LiteralPath (Join-Path $PackageRoot 'assets\compat\LegacyLauncher.exe') -Destination $legacyEntry -Force;Mark-Applied $legacyEntry $DataRoot}
    return $target
}