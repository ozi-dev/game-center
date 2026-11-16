param([string]$OutputDirectory='build',[string]$CacheDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$fixture=Join-Path $root ('reports\smoke '+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'data\downloads'),(Join-Path $fixture 'ROMs'),(Join-Path $fixture 'emulator-data\play_time') | Out-Null
Add-Type -Path (Join-Path $root ($OutputDirectory+'\SofaRelay.Core.dll'))
$settings=[SofaRelay.CenterSettings]::new();$settings.InstallRoot=Join-Path $fixture 'runtime';$settings.Libraries=@();$settings.AutoInstallStoreClients=$false
$emu=[SofaRelay.EmulatorConfig]::new();$emu.Name='QA Switch';$emu.Executable=Join-Path $env:WINDIR 'System32\cmd.exe';$emu.RomDirectory=Join-Path $fixture 'ROMs';$emu.DataDirectory=Join-Path $fixture 'emulator-data';$settings.Emulators.Add($emu)
[SofaRelay.Data]::Write((Join-Path $fixture 'settings.json'),$settings)
[IO.File]::WriteAllText((Join-Path $emu.RomDirectory 'Fixture [0100000000001234].nsp'),'This is a scanner fixture, not a game; never launch it.')
$stream=[IO.File]::Create((Join-Path $emu.DataDirectory 'play_time\playtime.bin'));$writer=[IO.BinaryWriter]::new($stream);try{$writer.Write([uint64]0x0100000000001234);$writer.Write([uint64]1234)}finally{$writer.Dispose();$stream.Dispose()}
if($CacheDirectory){foreach($item in (Get-Content (Join-Path $root 'manifests\packages.json') -Raw -Encoding UTF8 | ConvertFrom-Json).Packages){$from=Join-Path $CacheDirectory $item.FileName;if(Test-Path $from){Copy-Item -LiteralPath $from -Destination (Join-Path $fixture ('data\downloads\'+$item.FileName))}}}
[IO.File]::WriteAllText((Join-Path $root 'reports\latest-smoke.txt'),$fixture)
Write-Host $fixture
