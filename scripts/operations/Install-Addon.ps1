function Install-Addon([string]$Id,[string]$Folder,[string]$Playnite) {
    $archive=Get-Component $Id $PackageRoot $DataRoot
    $destination=Join-Path $Playnite ('Extensions\'+$Folder)
    Expand-ZipSafe $archive $destination
}