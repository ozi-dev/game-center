param([string]$PlayniteSdkPath,[string]$OutputDirectory='build',[string]$CompilerPath)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
. (Join-Path $root 'scripts\maintainer\BuildSupport.ps1')
$version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
if($version -notmatch '^\d+\.\d+\.\d+$') { throw 'VERSION must contain a SemVer release number.' }
if(!$CompilerPath) { $CompilerPath=Join-Path (Get-PinnedBuildTool 'roslyn' $root) 'tasks\net472\csc.exe' }
if(!$PlayniteSdkPath) { $PlayniteSdkPath=Join-Path $root 'downloads\Playnite\Playnite.SDK.dll' }
if(!(Test-Path -LiteralPath $PlayniteSdkPath)) { throw 'Specify -PlayniteSdkPath with the official pinned Playnite SDK.' }
$out = Join-Path $root $OutputDirectory
New-Item -ItemType Directory -Force -Path $out | Out-Null
$generated = Join-Path $out 'generated'
New-Item -ItemType Directory -Force -Path $generated | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
$metadata = Join-Path $generated 'Version.cs'
[IO.File]::WriteAllText($metadata,('[assembly:System.Reflection.AssemblyVersion("'+$version+'.0")][assembly:System.Reflection.AssemblyFileVersion("'+$version+'.0")][assembly:System.Reflection.AssemblyProduct("SofaRelay")] namespace SofaRelay { public static class BuildVersion { public const string Value="'+$version+'"; } }'),$utf8)
function Compile([string[]]$Arguments) {
    & $CompilerPath /nologo /optimize+ /deterministic+ /debug- ('/pathmap:'+$out+'=/_/build,'+$root+'=/_/src') @Arguments
    if($LASTEXITCODE) { throw 'C# compilation failed.' }
}
$core=Join-Path $out 'SofaRelay.Core.dll'
Compile @('/target:library',('/out:'+$core),'/reference:System.Web.Extensions.dll',$metadata,(Join-Path $root 'src\Core.cs'),(Join-Path $root 'src\Localization.cs'))
Compile @('/target:library',('/out:'+(Join-Path $out 'SofaRelay.Native.dll')),$metadata,(Join-Path $root 'src\BrokerPaths.cs'),(Join-Path $root 'assets\native\DisplayState.cs'),(Join-Path $root 'assets\native\InstallVdd.cs'))
$wpf=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\WPF'
Compile @('/target:library',('/out:'+(Join-Path $out 'SofaRelay.Plugin.dll')),('/reference:'+$core),('/reference:'+$PlayniteSdkPath),'/reference:System.Drawing.dll','/reference:System.Xaml.dll',('/reference:'+(Join-Path $wpf 'PresentationFramework.dll')),('/reference:'+(Join-Path $wpf 'PresentationCore.dll')),('/reference:'+(Join-Path $wpf 'WindowsBase.dll')),$metadata,(Join-Path $root 'src\Plugin.cs'),(Join-Path $root 'src\Artwork.cs'))
Compile @('/target:winexe',('/out:'+(Join-Path $out 'SteamTvInstall.exe')),('/reference:'+(Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\Accessibility.dll')),$metadata,(Join-Path $root 'src\SteamTvInstall.cs'))
Compile @('/target:winexe','/reference:System.Windows.Forms.dll','/reference:System.Core.dll',('/out:'+(Join-Path $out 'LegacyLauncher.exe')),$metadata,(Join-Path $root 'src\LegacyLauncher.cs'))

$brokerConfig=Join-Path $out 'SofaRelay.Broker.exe.config'
[IO.File]::WriteAllText($brokerConfig,'<configuration><startup><supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8" /></startup></configuration>',$utf8)
$payloadFiles=[ordered]@{'SofaRelay.Core.dll'=$core;'SofaRelay.Native.dll'=(Join-Path $out 'SofaRelay.Native.dll');'SofaRelay.Broker.exe.config'=$brokerConfig;'VERSION'=(Join-Path $root 'VERSION');'manifests/packages.json'=(Join-Path $root 'manifests\packages.json');'manifests/runtime-operations.json'=(Join-Path $root 'manifests\runtime-operations.json')}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -File -Recurse | Where-Object {$_.Extension -in '.ps1','.psm1' -and $_.FullName -notlike '*\maintainer\*'}) { $payloadFiles[$file.FullName.Substring($root.Length+1).Replace('\','/')]=$file.FullName }
foreach($file in Get-ChildItem -LiteralPath (Join-Path $root 'locales') -Filter '*.json' -File) { $payloadFiles['locales/'+$file.Name]=$file.FullName }
$payload=Join-Path $generated 'BrokerPayload.zip'
New-DeterministicZip $payload $payloadFiles
$payloadHash=(Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash.ToLowerInvariant()
$brokerBuild=Join-Path $generated 'BrokerBuild.cs'
[IO.File]::WriteAllText($brokerBuild,('static class BrokerBuild { public const string PayloadHash="'+$payloadHash+'"; public const string Version="'+$version+'"; }'),$utf8)
Compile @('/target:exe',('/out:'+(Join-Path $out 'SofaRelay.Broker.exe')),'/reference:System.Web.Extensions.dll','/reference:System.IO.Compression.dll','/reference:System.IO.Compression.FileSystem.dll',('/resource:'+$payload+',SofaRelay.Broker.Payload'),$metadata,$brokerBuild,(Join-Path $root 'src\BrokerPaths.cs'),(Join-Path $root 'src\PrivilegedBroker.cs'))
& (Join-Path $out 'SofaRelay.Broker.exe') --selftest
if($LASTEXITCODE) { throw 'Broker payload self-test failed.' }

$runtime=[ordered]@{}
foreach($name in @('SofaRelay.Core.dll','SofaRelay.Native.dll','SofaRelay.Broker.exe','SofaRelay.Broker.exe.config','VERSION','manifests/packages.json','manifests/runtime-operations.json')) {
    $path=if($name -like 'SofaRelay.*.dll' -or $name -like 'SofaRelay.Broker.exe*') {Join-Path $out $name}else{Join-Path $root $name}
    $runtime[$name]=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -File -Recurse | Where-Object {$_.Extension -in '.ps1','.psm1' -and $_.FullName -notlike '*\maintainer\*'}) { $runtime[$file.FullName.Substring($root.Length+1).Replace('\','/')]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
$hashFile=Join-Path $generated 'RuntimeHashes.json'
[IO.File]::WriteAllText($hashFile,($runtime | ConvertTo-Json -Depth 5 -Compress),$utf8)
$appManifest=Join-Path $generated 'app.manifest'
[IO.File]::WriteAllText($appManifest,([IO.File]::ReadAllText((Join-Path $root 'src\app.manifest')) -replace 'version="\d+\.\d+\.\d+\.\d+"',('version="'+$version+'.0"')),$utf8)
Compile @('/target:winexe','/platform:x64',('/win32manifest:'+$appManifest),('/out:'+(Join-Path $out 'SofaRelay.exe')),('/reference:'+$core),'/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll',('/resource:'+$hashFile+',SofaRelay.RuntimeHashes'),$metadata,(Join-Path $root 'src\App.cs'),(Join-Path $root 'src\LocalizedControls.cs'),(Join-Path $root 'src\RuntimeIntegrity.cs'),(Join-Path $root 'src\BrokerLauncher.cs'))
foreach($test in @('CoreTests','LocalizationTests','DisplayStateTests')) {
    Compile @('/target:exe',('/out:'+(Join-Path $out ($test+'.exe'))),('/reference:'+$core),('/reference:'+(Join-Path $out 'SofaRelay.Native.dll')),'/reference:System.Core.dll',(Join-Path $root ('tests\'+$test+'.cs')))
    & (Join-Path $out ($test+'.exe')) $root
    if($LASTEXITCODE) { throw ($test+' failed.') }
}
$plugin=Join-Path $root 'assets\plugin'
$compat=Join-Path $root 'assets\compat'
New-Item -ItemType Directory -Force -Path $plugin,$compat | Out-Null
Copy-Item (Join-Path $out 'LegacyLauncher.exe') $compat -Force
Copy-Item $core,(Join-Path $out 'SofaRelay.Plugin.dll'),(Join-Path $out 'SteamTvInstall.exe') $plugin -Force
# Legacy extension ID: keep it unchanged to preserve Playnite state and game IDs.
[IO.File]::WriteAllText((Join-Path $plugin 'extension.yaml'),("Id: GamingCenter_15378b45-7634-47ed-8570-69ad2d7a9067`nName: SofaRelay Companion`nAuthor: SofaRelay`nVersion: $version`nModule: SofaRelay.Plugin.dll`nType: GenericPlugin`n"),$utf8)
Copy-Item (Join-Path $out 'SofaRelay.exe') (Join-Path $out 'Installer.exe') -Force
foreach($name in @('scripts','assets','locales','manifests','docs')) { $destination=Join-Path $out $name;New-Item -ItemType Directory -Force -Path $destination | Out-Null;Copy-Item -Path (Join-Path $root ($name+'\*')) -Destination $destination -Recurse -Force }
foreach($name in @('VERSION','README.md','LICENSE.txt','THIRD-PARTY.md','CHANGELOG.md','CONTRIBUTING.md','SECURITY.md')) {Copy-Item -LiteralPath (Join-Path $root $name) $out -Force}
$sourceFiles=@(Get-PublicSourceFiles $root)
[IO.File]::WriteAllLines((Join-Path $out 'SOURCE-FILES.txt'),$sourceFiles,$utf8)
$commit=if(Test-Path (Join-Path $root '.git')) {(& git -C $root rev-parse HEAD)}else{'source-archive'}
[IO.File]::WriteAllText((Join-Path $out 'BUILD-INFO.json'),(@{Version=$version;Commit=$commit;Repository='ozi-dev/sofarelay'}|ConvertTo-Json -Compress),$utf8)
Write-Output "Build ready: $out"
