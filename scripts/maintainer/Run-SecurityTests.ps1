param([string]$OutputDirectory='build')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot 'BuildSupport.ps1')
$pester=Get-PinnedBuildTool 'pester' $root
Import-Module (Join-Path $pester 'Pester.psd1') -Force
$result=Invoke-Pester -Path (Join-Path $root 'tests\Security.Tests.ps1') -PassThru -Output Detailed
if($result.FailedCount -or $result.FailedContainersCount) { throw 'Security regression tests failed.' }
