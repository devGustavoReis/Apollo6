# APOLLO6

- Leia este arquivo e o README antes de trabalhar. Confirme com a equipe que chegou sua vez. Uma pessoa e sua IA por vez, sempre em `main`, com envio direto e sem PR no fluxo diário.
- Antes de editar, salve e feche o Godot e execute `./scripts/iniciar.ps1`. O script verifica a branch e o estado local, executa `git pull --ff-only origin main` e compara o commit local com o GitHub. Só comece após a confirmação.
- Trabalhe sobre os arquivos existentes. Preserve os sistemas do jogo e limite o diff à tarefa. Mantenha cenas, scripts, modelos, texturas, animações, áudio, cutscenes, interfaces, configurações e documentação nos diretórios adotados pelo projeto. Preserve os arquivos `.uid` e os metadados de importação junto dos assets.
- Ao terminar, salve as alterações, teste a cena principal e o comportamento alterado no Godot e feche o editor. Revise `git status --short`, `git diff` e os arquivos novos. Adicione apenas os arquivos da tarefa com `git add -- <arquivos>`, revise `git diff --cached` e crie um commit claro.
- Com a árvore limpa, execute `./scripts/enviar.ps1`. Só entregue a vez após o script confirmar o mesmo commit local e remoto. Informe ao próximo integrante o hash, o que mudou, os testes executados e o próximo passo.
- Se houver conflito, divergência ou mudanças locais inesperadas, interrompa e explique a situação antes de tentar resolvê-la. Preserve as alterações de todos. Nunca use `git push --force` nem `--force-with-lease`. Operações destrutivas do Git exigem aprovação.
- Execute a sincronização manualmente entre sessões, com o Godot fechado e sem outros processos editando os arquivos.
