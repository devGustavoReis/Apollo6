. (Join-Path $PSScriptRoot 'verificar.ps1')

Invoke-Sync {
    $remote = Get-RemoteMain
    $local = Invoke-Git rev-parse HEAD
    if ($remote -ne $local) {
        Invoke-Git fetch --no-tags origin main | Out-Null
        Assert-FastForward (Invoke-Git rev-parse FETCH_HEAD) $local
        Assert-CleanMain
        Invoke-Git push origin main | Out-Host
    }
    Confirm-Synced
}
