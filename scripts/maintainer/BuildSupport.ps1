$ErrorActionPreference = 'Stop'

function Get-PinnedBuildTool {
    param([string]$Id,[string]$Root)
    $manifest = Get-Content -LiteralPath (Join-Path $Root 'manifests\build-tools.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $item = @($manifest.Tools | Where-Object Id -eq $Id)[0]
    $cache = Join-Path $Root 'downloads\ci-tools'
    New-Item -ItemType Directory -Force -Path $cache | Out-Null
    $archive = Join-Path $cache $item.FileName
    if(!(Test-Path -LiteralPath $archive)) {
        $previous = $ProgressPreference
        try { $ProgressPreference='SilentlyContinue';[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;Invoke-WebRequest -Uri $item.Url -OutFile $archive -UseBasicParsing -TimeoutSec 300 }
        finally { $ProgressPreference=$previous }
    }
    if((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $item.Sha256) { throw "Pinned build-tool checksum failed: $Id" }
    $destination = Join-Path $cache $Id
    if(!(Test-Path -LiteralPath $destination)) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($archive,$destination)
    }
    return $destination
}

function New-DeterministicZip {
    param([string]$Destination,[System.Collections.IDictionary]$Files)
    Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
    $stream = [IO.File]::Open($Destination,[IO.FileMode]::Create,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $zip = [IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$false)
    try {
        $names=[string[]]@($Files.Keys)
        [Array]::Sort($names,[StringComparer]::Ordinal)
        foreach($name in $names) {
            $entry = $zip.CreateEntry($name.Replace('\','/'),[IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(2020,1,1,0,0,0,[TimeSpan]::Zero)
            $input = [IO.File]::OpenRead([string]$Files[$name])
            $output = $entry.Open()
            try { $input.CopyTo($output) } finally { $input.Dispose();$output.Dispose() }
        }
    } finally { $zip.Dispose();$stream.Dispose() }
}

function Get-PublicSourceFiles {
    param([string]$Root)
    if(Test-Path -LiteralPath (Join-Path $Root '.git')) {
        $names = @(& git -C $Root ls-files)
        if($LASTEXITCODE) { throw 'Cannot enumerate the tracked public source.' }
    } else {
        $list = Join-Path $Root 'SOURCE-FILES.txt'
        if(!(Test-Path -LiteralPath $list)) { throw 'Build from a Git checkout or the complete release source directory.' }
        $names = @(Get-Content -LiteralPath $list -Encoding UTF8)
    }
    return @($names | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $Root $_) -PathType Leaf) })
}
