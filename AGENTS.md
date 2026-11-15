# APOLLO6

- Leia este arquivo e o README antes de trabalhar. Confirme com a equipe que chegou sua vez. Uma pessoa e sua IA por vez, sempre em `main`, com envio direto e sem PR no fluxo diário.
- Antes de editar, salve e feche o Godot e execute `./scripts/iniciar.ps1`. O script verifica a branch e o estado local, executa `git pull --ff-only origin main` e compara o commit local com o GitHub. Só comece após a confirmação.
- Trabalhe sobre os arquivos existentes. Preserve os sistemas do jogo e limite o diff à tarefa. Mantenha cenas, scripts, modelos, texturas, animações, áudio, cutscenes, interfaces, configurações e documentação nos diretórios adotados pelo projeto. Preserve os arquivos `.uid` e os metadados de importação junto dos assets.
- Ao terminar, salve as alterações, teste a cena principal e o comportamento alterado no Godot e feche o editor. Revise `git status --short`, `git diff` e os arquivos novos. Adicione apenas os arquivos da tarefa com `git add -- <arquivos>`, revise `git diff --cached` e crie um commit claro.
- Com a árvore limpa, execute `./scripts/enviar.ps1`. Só entregue a vez após o script confirmar o mesmo commit local e remoto. Informe ao próximo integrante o hash, o que mudou, os testes executados e o próximo passo.
- Se houver conflito, divergência ou mudanças locais inesperadas, interrompa e explique a situação antes de tentar resolvê-la. Preserve as alterações de todos. Nunca use `git push --force` nem `--force-with-lease`. Operações destrutivas do Git exigem aprovação.
- Execute a sincronização manualmente entre sessões, com o Godot fechado e sem outros processos editando os arquivos.

## Ferramentas e minigames da cabine

- Mantenha o catálogo de assistência em `data/equipment/equipment.json` e siga a associação de M01 a M06 descrita no README. As seis tarefas opcionais estão ligadas aos cinco dias jogáveis: M01 e M02 no Dia 1, M05 no Dia 2, M06 no Dia 3, M04 no Dia 4 e M03 no Dia 5.
- Permita concluir qualquer minigame sem ferramenta. Ao finalizar uma tentativa, use `MissionState.resolve_minigame_attempt` com o mesmo ID quando o evento se repetir. A ferramenta correspondente dá 80% de chance de recuperar cada tentativa legítima que terminar em erro. Uma tarefa concluída mantém seu desfecho.
- Apresente `title` e `message` em uma nova tentativa resolvida. Use `new_completion` para registrar a conclusão uma vez. Exiba o nome da ferramenta em conclusões assistidas e preserve a distinção entre acerto direto e assistência em qualquer relatório.
- Ao mudar a assistência, teste erro sem ferramenta, ferramenta incompatível, recuperação, falha da assistência, acerto direto, repetição do sinal e restauração de checkpoint.
