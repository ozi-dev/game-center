param([string]$OutputDirectory='build')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$package=Join-Path $project $OutputDirectory
Add-Type -Path (Join-Path $package 'SofaRelay.Native.dll')
$fixture=Join-Path $project ('reports\broker-boundary-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'runtime\data') | Out-Null
$script:checks=0
function Must-Reject([scriptblock]$Operation){$failed=$false;try{& $Operation | Out-Null}catch{$failed=$true};if(!$failed){throw 'A broker boundary accepted an unsafe request.'};$script:checks++}
$runtime=Join-Path $fixture 'runtime'
Must-Reject {[SofaRelay.Security.BrokerPaths]::ContainedFile($runtime,(Join-Path $runtime '..\outside'))}
Must-Reject {[SofaRelay.Security.BrokerPaths]::ResultFile($runtime,(Join-Path $runtime 'data\settings.json'))}
$result=Join-Path $runtime ('data\broker-result-'+[guid]::NewGuid().ToString('N')+'.json')
[IO.File]::WriteAllText($result,'existing')
Must-Reject {[SofaRelay.Security.BrokerPaths]::ResultFile($runtime,$result)}
Must-Reject {[SofaRelay.Security.BrokerPaths]::UserRuntime($runtime,'S-1-5-18')}
Must-Reject {[SofaRelay.Security.BrokerPaths]::UserRuntime($env:WINDIR,[Security.Principal.WindowsIdentity]::GetCurrent().User.Value)}
$junction=Join-Path $fixture 'linked'
New-Item -ItemType Junction -Path $junction -Target $runtime | Out-Null
Must-Reject {[SofaRelay.Security.BrokerPaths]::NoLinks((Join-Path $junction 'data'))}
$lease=[SofaRelay.Security.BrokerPaths]::PinRuntime($runtime)
try{Must-Reject {Rename-Item -LiteralPath $runtime -NewName 'moved' -ErrorAction Stop};[IO.File]::WriteAllText((Join-Path $runtime 'data\child-test'),'ok')}
finally{$lease.Dispose()}
Write-Host "PASS $script:checks broker path/owner/junction/directory-lock boundary checks; no elevation performed."
