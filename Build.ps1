param([string]$PlayniteSdkPath,[string]$OutputDirectory='build')
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(!(Test-Path $compiler)){throw '.NET Framework 4.8 geliştirme araçları bulunamadı.'}
if(!$PlayniteSdkPath){$PlayniteSdkPath=Join-Path $root 'downloads\Playnite\Playnite.SDK.dll'}
if(!(Test-Path -LiteralPath $PlayniteSdkPath)){throw 'Build.ps1 -PlayniteSdkPath <Playnite.SDK.dll> kullanın; SDK temiz Playnite dağıtımında bulunur.'}
$out=Join-Path $root $OutputDirectory;New-Item -ItemType Directory -Force -Path $out | Out-Null
function Compile([string[]]$Arguments){& $compiler @Arguments;if($LASTEXITCODE){throw 'C# derlemesi başarısız.'}}
Compile @('/nologo','/optimize+','/target:library',('/out:'+(Join-Path $out 'SofaRelay.Core.dll')),'/reference:System.Web.Extensions.dll',(Join-Path $root 'src\Core.cs'),(Join-Path $root 'src\Localization.cs'))
Compile @('/nologo','/optimize+','/target:winexe','/platform:x64',('/win32manifest:'+(Join-Path $root 'src\app.manifest')),('/out:'+(Join-Path $out 'SofaRelay.exe')),('/reference:'+(Join-Path $out 'SofaRelay.Core.dll')),'/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll',(Join-Path $root 'src\App.cs'),(Join-Path $root 'src\LocalizedControls.cs'))
$wpf=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\WPF'
Compile @('/nologo','/optimize+','/target:library',('/out:'+(Join-Path $out 'SofaRelay.Plugin.dll')),('/reference:'+(Join-Path $out 'SofaRelay.Core.dll')),('/reference:'+$PlayniteSdkPath),'/reference:System.Drawing.dll','/reference:System.Xaml.dll',('/reference:'+(Join-Path $wpf 'PresentationFramework.dll')),('/reference:'+(Join-Path $wpf 'PresentationCore.dll')),('/reference:'+(Join-Path $wpf 'WindowsBase.dll')),(Join-Path $root 'src\Plugin.cs'),(Join-Path $root 'src\Artwork.cs'))
Compile @('/nologo','/optimize+','/target:winexe',('/out:'+(Join-Path $out 'SteamTvInstall.exe')),('/reference:'+(Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\Accessibility.dll')),(Join-Path $root 'src\SteamTvInstall.cs'))
Compile @('/nologo','/optimize+','/target:winexe','/reference:System.Windows.Forms.dll','/reference:System.Core.dll',('/out:'+(Join-Path $out 'LegacyLauncher.exe')),(Join-Path $root 'src\LegacyLauncher.cs'))
Compile @('/nologo','/target:exe',('/out:'+(Join-Path $out 'CoreTests.exe')),('/reference:'+(Join-Path $out 'SofaRelay.Core.dll')),(Join-Path $root 'tests\CoreTests.cs'))
& (Join-Path $out 'CoreTests.exe');if($LASTEXITCODE){throw 'Çekirdek testleri başarısız.'}
Compile @('/nologo','/target:exe',('/out:'+(Join-Path $out 'LocalizationTests.exe')),('/reference:'+(Join-Path $out 'SofaRelay.Core.dll')),'/reference:System.Core.dll',(Join-Path $root 'tests\LocalizationTests.cs'))
& (Join-Path $out 'LocalizationTests.exe') $root;if($LASTEXITCODE){throw 'Localization tests failed.'}
$plugin=Join-Path $root 'assets\plugin';New-Item -ItemType Directory -Force -Path $plugin | Out-Null
foreach($legacyName in @('GamingCenter.Core.dll','GamingCenter.Plugin.dll')){$legacyPath=Join-Path $plugin $legacyName;if(Test-Path -LiteralPath $legacyPath){Remove-Item -LiteralPath $legacyPath}}
$compat=Join-Path $root 'assets\compat';New-Item -ItemType Directory -Force -Path $compat | Out-Null;Copy-Item -LiteralPath (Join-Path $out 'LegacyLauncher.exe') -Destination $compat -Force
Copy-Item (Join-Path $out 'SofaRelay.Core.dll'),(Join-Path $out 'SofaRelay.Plugin.dll'),(Join-Path $out 'SteamTvInstall.exe') $plugin -Force
@'
Id: GamingCenter_15378b45-7634-47ed-8570-69ad2d7a9067
Name: SofaRelay Companion
Author: SofaRelay
Version: 2.2.0
Module: SofaRelay.Plugin.dll
Type: GenericPlugin
'@ | Set-Content -LiteralPath (Join-Path $plugin 'extension.yaml') -Encoding UTF8
Copy-Item (Join-Path $out 'SofaRelay.exe') (Join-Path $out 'Installer.exe') -Force
foreach($name in @('scripts','assets','locales','manifests','docs')){$dest=Join-Path $out $name;New-Item -ItemType Directory -Force -Path $dest | Out-Null;Copy-Item -Path (Join-Path $root ($name+'\*')) -Destination $dest -Recurse -Force}
foreach($name in @('README.md','LICENSE.txt','THIRD-PARTY.md','CHANGELOG.md','CONTRIBUTING.md','SECURITY.md')){if(Test-Path (Join-Path $root $name)){Copy-Item (Join-Path $root $name) $out -Force}}
Write-Output "Derleme hazır: $out"
