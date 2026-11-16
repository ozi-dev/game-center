param([string]$BuildDirectory='build')
$ErrorActionPreference='Stop'
$root=$PSScriptRoot;$build=Join-Path $root $BuildDirectory
$release=Join-Path $root ('dist\Oyun-Merkezi-2.0.0-'+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Force -Path $release | Out-Null
foreach($name in @('Kurulum.exe','OyunMerkezi.exe','GamingCenter.Core.dll','scripts','assets','manifests','docs','README.html','README.md','README.tr.md','README.fr.md','README.es.md','LICENSE.txt','THIRD-PARTY.md','CHANGELOG.md','CONTRIBUTING.md','SECURITY.md')){Copy-Item -LiteralPath (Join-Path $build $name) -Destination $release -Recurse}
$source=Join-Path $release 'source';New-Item -ItemType Directory -Force -Path $source | Out-Null
foreach($name in @('.gitignore','.gitattributes','.github','Build.ps1','Package.ps1','src','tests','scripts','assets','manifests','docs','README.html','README.md','README.tr.md','README.fr.md','README.es.md','LICENSE.txt','THIRD-PARTY.md','CHANGELOG.md','CONTRIBUTING.md','SECURITY.md')){Copy-Item -LiteralPath (Join-Path $root $name) -Destination $source -Recurse}
@'
OYUN MERKEZI 2.0.0

1. ZIP dosyasinin tamamini bir klasore cikarin.
2. Kurulum.exe dosyasini acin ve yedi adimi izleyin.
3. Guides: README.md (English), README.tr.md, README.fr.md, README.es.md.
   Full Turkish manual: README.html.
   Installer UI is currently Turkish; translated guides explain its labels.

Girisler ve ilk Moonlight PIN eslestirmesi kendi hesap/cihazinizda yapilir.
NVIDIA Shield desteklenir; 4K icin 60 Hz secin.
Kaynak kod ve testler source klasorundedir.
Paket oyunlarinizi, sifrelerinizi veya baska birinin ayarlarini icermez.
Internet, secilen bilesenleri indirmek icin gerekir.
'@ | Set-Content -LiteralPath (Join-Path $release 'BURADAN-BASLA.txt') -Encoding UTF8
$files=@(Get-ChildItem -LiteralPath $release -Recurse -File)
$blocked=@([Environment]::GetFolderPath('UserProfile'))
$localSettings=Join-Path $root 'data\settings.json'
if(Test-Path $localSettings){$private=Get-Content $localSettings -Raw -Encoding UTF8 | ConvertFrom-Json;foreach($property in @('DisplayId','DeviceAddress')){if($private.$property){$blocked+=@([string]$private.$property)}}}
foreach($file in $files){
    $relative=$file.FullName.Substring($release.Length+1)
    if($relative -match '(?i)(^|\\)(data|downloads|reports|library|ExtensionsData)(\\|$)' -or $relative -match '(?i)\.(nsp|nup|xci|rom|sav|db)$' -or $relative -match '(?i)(prod\.keys|title\.keys|playtime\.bin|sunshine_state\.json)'){throw "Private payload forbidden: $relative"}
    if($file.Extension -in '.cs','.ps1','.psm1','.py','.json','.yaml','.html','.md','.txt'){
        $text=[IO.File]::ReadAllText($file.FullName)
        $normalized=$text.Replace('\\','\').Replace('/','\')
        foreach($marker in $blocked){if($marker -and $normalized.IndexOf($marker,[StringComparison]::OrdinalIgnoreCase) -ge 0){throw "Personal data detected: $relative"}}
    }
}
$hashes=@($files | ForEach-Object {((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())+'  '+$_.FullName.Substring($release.Length+1)})
[IO.File]::WriteAllLines((Join-Path $release 'SHA256SUMS.txt'),$hashes,[Text.UTF8Encoding]::new($false))
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=Join-Path $root 'dist\Oyun-Merkezi-2.0.0-Windows-x64.zip'
if(Test-Path -LiteralPath $zip){throw 'Release ZIP already exists; review or rename it before packaging.'}
[IO.Compression.ZipFile]::CreateFromDirectory($release,$zip,[IO.Compression.CompressionLevel]::Optimal,$false)
$digest=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText(($zip+'.sha256'),$digest+'  '+[IO.Path]::GetFileName($zip)+"`r`n",[Text.UTF8Encoding]::new($false))
@{Zip=$zip;Folder=$release;Files=$files.Count;Size=(Get-Item $zip).Length;SHA256=$digest} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'reports\release.json') -Encoding UTF8
Write-Host "Ready: $zip ($([Math]::Round((Get-Item $zip).Length/1MB,2)) MB), $($files.Count) files; privacy allowlist passed."
