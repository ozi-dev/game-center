function Invoke-ConfigurationTransaction {
    param([string[]]$Files,[scriptblock]$Operation)
    $snapshot=@()
    foreach($file in $Files) {
        $record=[pscustomobject]@{Path=$file;Existed=(Test-Path -LiteralPath $file);Bytes=$null}
        if($record.Existed) { $record.Bytes=[IO.File]::ReadAllBytes($file) }
        $snapshot+=@($record)
    }
    try { return (& $Operation) }
    catch {
        $failure=$_
        foreach($record in $snapshot) {
            if($record.Existed) { Write-BytesAtomic $record.Path $record.Bytes }
            elseif(Test-Path -LiteralPath $record.Path) { Remove-Item -LiteralPath $record.Path -Force }
        }
        throw $failure
    }
}
