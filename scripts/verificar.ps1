function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) {
        throw "Git falhou ($LASTEXITCODE): git $args"
    }
}

function Assert-CleanMain {
    if ((Invoke-Git branch --show-current) -ne 'main') {
        throw 'A sessao precisa estar na branch main.'
    }
    foreach ($operation in 'MERGE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD', 'rebase-merge', 'rebase-apply', 'sequencer') {
        if (Test-Path -LiteralPath (Invoke-Git rev-parse --git-path $operation)) {
            throw "Existe uma operacao Git pendente: $operation."
        }
    }
    $changes = Invoke-Git status --porcelain --untracked-files=normal
    if ($changes) {
        $changes | Out-Host
        throw 'Existem alteracoes locais. Revise os arquivos antes de sincronizar.'
    }
}

function Get-RemoteMain {
    $ref = Invoke-Git ls-remote --exit-code origin refs/heads/main
    return ($ref -split '\s+')[0]
}

function Assert-FastForward($ancestor, $descendant) {
    & git merge-base --is-ancestor $ancestor $descendant
    if ($LASTEXITCODE -eq 1) {
        throw 'A main local e a remota nao permitem esta operacao por fast-forward. Preserve os commits e converse com a equipe.'
    }
    if ($LASTEXITCODE -ne 0) {
        throw 'Falha ao verificar o historico da main.'
    }
}

function Confirm-Synced {
    Assert-CleanMain
    $local = Invoke-Git rev-parse HEAD
    if ($local -ne (Get-RemoteMain)) {
        throw 'Os commits local e remoto diferem. Confira a main antes de passar a vez.'
    }
    Write-Host "main sincronizada com origin: $local"
}

function Invoke-Sync([scriptblock]$action) {
    $ErrorActionPreference = 'Stop'
    Push-Location (Split-Path -Parent $PSScriptRoot)
    try {
        Assert-CleanMain
        if ((Invoke-Git remote get-url origin) -ne (Invoke-Git remote get-url --push origin)) {
            throw 'O origin tem enderecos diferentes para leitura e envio.'
        }
        & $action
    } catch {
        Write-Error $_ -ErrorAction Continue
        exit 1
    } finally {
        Pop-Location
    }
}
