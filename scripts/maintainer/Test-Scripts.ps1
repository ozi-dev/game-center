param([string]$Root=(Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference='Stop'
. (Join-Path $Root 'scripts\maintainer\BuildSupport.ps1')
$analyzer=Get-PinnedBuildTool 'analyzer' $Root
Import-Module (Join-Path $analyzer 'PSScriptAnalyzer.psd1') -Force
$findings=@()
foreach($name in @(& git -C $Root ls-files '*.ps1' '*.psm1')) {
    $findings+=@(Invoke-ScriptAnalyzer -Path (Join-Path $Root $name) -Settings (Join-Path $Root '.github\PSScriptAnalyzerSettings.psd1'))
}
if($findings.Count) { $findings | Format-Table RuleName,ScriptName,Line,Message -Wrap;throw 'Security-focused PowerShell analysis failed.' }
Write-Output 'PASS security-focused PSScriptAnalyzer rules'
