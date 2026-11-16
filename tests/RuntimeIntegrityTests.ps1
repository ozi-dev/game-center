param([string]$OutputDirectory='build')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$build=Join-Path $project $OutputDirectory
$fixture=Join-Path $project ('reports\integrity-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
foreach($name in @('SofaRelay.exe','SofaRelay.Core.dll','SofaRelay.Native.dll','SofaRelay.Broker.exe','SofaRelay.Broker.exe.config','VERSION','scripts','manifests','locales')){Copy-Item -LiteralPath (Join-Path $build $name) -Destination $fixture -Recurse}
function Verify-Runtime { (Start-Process -FilePath (Join-Path $fixture 'SofaRelay.exe') -ArgumentList '--verify-runtime' -WindowStyle Hidden -Wait -PassThru).ExitCode }
if((Verify-Runtime) -ne 0){throw 'An unchanged runtime was rejected.'}
$worker=Join-Path $fixture 'scripts\Worker.ps1'
$bytes=[IO.File]::ReadAllBytes($worker)
[IO.File]::AppendAllText($worker,"`n# altered worker")
if((Verify-Runtime) -eq 0){throw 'An altered worker was accepted.'}
[IO.File]::WriteAllBytes($worker,$bytes)
$manifest=Join-Path $fixture 'manifests\packages.json'
$bytes=[IO.File]::ReadAllBytes($manifest)
[IO.File]::AppendAllText($manifest,"`n ")
if((Verify-Runtime) -eq 0){throw 'An altered package manifest was accepted.'}
[IO.File]::WriteAllBytes($manifest,$bytes)
[IO.File]::WriteAllText((Join-Path $fixture 'scripts\operations\injected.ps1'),'throw "must not run"')
if((Verify-Runtime) -eq 0){throw 'An injected operation was accepted.'}
Write-Host 'PASS unchanged runtime; altered worker, altered manifest and injected operation rejected before setup.'
