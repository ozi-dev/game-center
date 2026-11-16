param([string]$BuildDirectory='build')
$ErrorActionPreference='Stop'
$root=$PSScriptRoot;$build=Join-Path $root $BuildDirectory
$release=Join-Path $root ('dist\SofaRelay-2.2.0-'+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Force -Path $release | Out-Null
foreach($name in @('Installer.exe','SofaRelay.exe','SofaRelay.Core.dll','scripts','assets','locales','manifests','docs','README.md','LICENSE.txt','THIRD-PARTY.md','CHANGELOG.md','CONTRIBUTING.md','SECURITY.md')){Copy-Item -LiteralPath (Join-Path $build $name) -Destination $release -Recurse}
$source=Join-Path $release 'source';New-Item -ItemType Directory -Force -Path $source | Out-Null
foreach($name in @('.gitignore','.gitattributes','.github','Build.ps1','Package.ps1','src','tests','scripts','assets','locales','manifests','docs','README.md','LICENSE.txt','THIRD-PARTY.md','CHANGELOG.md','CONTRIBUTING.md','SECURITY.md')){
    $from=Join-Path $root $name
    if(!(Get-Item -LiteralPath $from -Force).PSIsContainer){Copy-Item -LiteralPath $from -Destination $source;continue}
    foreach($file in Get-ChildItem -LiteralPath $from -Recurse -File -Force){
        $relative=$file.FullName.Substring($root.Length+1)
        if($relative -match '^(src|tests|assets\\plugin|assets\\compat)\\.*\.(dll|exe)$'){continue}
        $destination=Join-Path $source $relative;New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
}
@'
SOFARELAY 2.2.0

1. Extract the entire ZIP archive to a writable folder.
2. Run Installer.exe and follow the seven guided pages.
3. Project: README.md (English), docs/readme/tr.md, fr.md, es.md.
   Offline help: docs/guides/en.html, tr.html, fr.html, es.html.
   Extended Turkish manual: docs/guides/manual.tr.html.
   Installer languages: English, Turkce, Francais, Espanol.

Complete store sign-in and initial Moonlight PIN pairing on your own devices.
For NVIDIA Shield, start with 4K at 60 Hz.
Start menu: SofaRelay > SofaRelay Settings / Restore Display.
Source code and tests are in the source directory.
No games, credentials, saves or another user's configuration are included.
Internet access downloads the selected components.
Existing installation folders and emulator paths are preserved during upgrade.
'@ | Set-Content -LiteralPath (Join-Path $release 'START-HERE.txt') -Encoding UTF8
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
$zip=Join-Path $root 'dist\SofaRelay-2.2.0-Windows-x64.zip'
if(Test-Path -LiteralPath $zip){throw 'Release ZIP already exists; review or rename it before packaging.'}
[IO.Compression.ZipFile]::CreateFromDirectory($release,$zip,[IO.Compression.CompressionLevel]::Optimal,$false)
$digest=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText(($zip+'.sha256'),$digest+'  '+[IO.Path]::GetFileName($zip)+"`r`n",[Text.UTF8Encoding]::new($false))
@{Zip=$zip;Folder=$release;Files=$files.Count;Size=(Get-Item $zip).Length;SHA256=$digest} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'reports\release.json') -Encoding UTF8
Write-Host "Ready: $zip ($([Math]::Round((Get-Item $zip).Length/1MB,2)) MB), $($files.Count) files; privacy allowlist passed."
