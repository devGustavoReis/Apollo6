. (Join-Path $PSScriptRoot 'verificar.ps1')

Invoke-Sync {
    $local = Invoke-Git rev-parse HEAD
    $remote = Get-RemoteMain
    if ($local -ne $remote) {
        # Fetch allows ancestry checks without changing the worktree.
        Invoke-Git fetch --no-tags origin main | Out-Null
        Assert-FastForward $local (Invoke-Git rev-parse FETCH_HEAD)
    }
    Assert-CleanMain
    Invoke-Git -c pull.rebase=false -c merge.autostash=false pull --ff-only origin main | Out-Host
    Confirm-Synced
}
