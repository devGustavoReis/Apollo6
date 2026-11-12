# APOLLO6

Projeto da equipe para o NASA Space Apps Challenge, em Godot 4. A equipe combina a ordem de trabalho e usa a branch `main`.

## Primeiro acesso

1. Aceite o convite do GitHub com sua conta pessoal.
2. Clone o repositório com `git clone https://github.com/devGustavoReis/Apollo6.git`.
3. Configure seu nome e e-mail de commit no clone. Use o endereço verificado ou o endereço privado fornecido pelo GitHub.
4. Quando os arquivos do jogo estiverem publicados e chegar sua vez, sincronize e importe o `project.godot` no gerenciador do Godot 4. Combine com a equipe a mesma versão do motor.

## Começar e terminar

No PowerShell, a partir da raiz do clone, com o Godot fechado:

```powershell
./scripts/iniciar.ps1
```

Abra o projeto após a confirmação. Ao terminar, salve, rode o jogo com F5 e exercite o comportamento alterado. Use F6 para testar a cena aberta. Feche o Godot, revise as mudanças e registre os arquivos selecionados:

```powershell
git status --short
git diff
git add -- <arquivos>
git diff --cached
git commit -m "Descreva a alteração"
./scripts/enviar.ps1
```

Se o PowerShell bloquear scripts por política de execução, use os comandos Git descritos em [AGENTS.md](AGENTS.md) e confira o hash remoto com `git ls-remote --exit-code origin refs/heads/main` e o local com `git rev-parse HEAD`.

Ao receber a confirmação do envio, passe ao próximo integrante o hash, o resumo, os testes e o próximo passo. Se uma verificação falhar, mantenha os arquivos e os commits locais e informe a equipe antes de prosseguir.
