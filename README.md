# APOLLO6

Projeto da equipe para o NASA Space Apps Challenge, em Godot 4. A equipe combina a ordem de trabalho e usa a branch `main`.

## Jogar

Abra o projeto no Godot 4.7.2 e pressione F5. O jogo começa no menu principal.
Fluxo, controles, arquitetura, instalação de modelos e nomes dos vídeos: [docs/gameplay_prototype.md](docs/gameplay_prototype.md).
Fontes científicas e simplificações: [docs/nasa_sources.md](docs/nasa_sources.md).

## Objetivo científico

Escolha no planejamento entre coleta de amostras, medição da distância Terra–Lua e fotografia estéreo do regolito. Acrescente à carga o instrumento correspondente. Após o pouso, confirme a atividade científica antes de preparar a partida. O relatório apresenta o resultado científico e a situação da tripulação.

## Áudio

Ajuste o volume em **Configurações** no menu. A trilha, os eventos sonoros e a integração com os minigames estão em [docs/audio.md](docs/audio.md).

## Ferramentas para os minigames de cabine

A aba **Ferramentas** do planejamento oferece quatro itens opcionais. Eles entram no orçamento e na massa da carga e ajudam nas tarefas opcionais da cabine. Mire na estação e pressione **F**. **Esc** abandona a tentativa em andamento.

| Ferramenta | Minigames previstos |
| --- | --- |
| Kit de fixação | M01 — Prender objetos soltos e M06 — Guardar embalagens da refeição |
| Kit de vedação e encaixe | M02 — Abastecer a bolsa de água e M04 — Encaixar o conector do traje |
| Medidor de sinal | M03 — Recuperar o sinal da antena |
| Kit de escurecimento | M05 — Preparar a cabine para descanso |

Cada minigame pode ser concluído sem equipamento. Após um erro, a ferramenta correspondente, se embarcada, dá **80% de chance** de recuperar a tentativa. Em caso de recuperação, o jogo deve mostrar **Tarefa concluída com ajuda** e informar que o jogador errou e qual ferramenta concluiu a tarefa. Se a recuperação falhar, a tarefa fica pendente e pode ser tentada novamente. Bateria auxiliar, reserva de propelente e kit de reparos continuam disponíveis na aba **Reservas** para seus efeitos na missão.

Ao adicionar ou alterar uma tarefa, chame `MissionState.resolve_minigame_attempt(task_id, attempt_id, played_well)` ao finalizar uma tentativa, com um ID positivo e único por tarefa. Use `title` e `message` para informar o desfecho de uma `new_attempt`. Use `new_completion` para registrar a conclusão uma vez e `assisted`/`played_well` para preservar a diferença entre assistência e acerto direto. A mesma tentativa reutiliza o resultado anterior, inclusive ao retomar um checkpoint que a contenha.

As seis tarefas ficam distribuídas pelos cinco dias jogáveis:

| Dia | Estações e tarefas |
| --- | --- |
| 1 | Armário para prender objetos (M01). Dispensador para abastecer a bolsa (M02), separado do consumo de água. |
| 2 | Estação de repouso para preparar as coberturas antes de dormir (M05). |
| 3 | Descarte para guardar embalagens (M06). |
| 4 | Bancada de ferramentas para encaixar o conector do traje (M04), já na volta. |
| 5 | Rádio para recuperar o sinal (M03), antes da reentrada. |

## Missão completa e suprimentos

A missão tem 5 dias jogáveis e 3 transições (A órbita lunar, B operações lunares, C aproximação da Terra). Cada dia pede 1 comida e 1 água, e cada transição cobra mais 1 de cada, então o plano mínimo é 8/8. Comer e beber são livres: pegue com E e consuma com E (Q devolve sem gastar, G solta em microgravidade e E recolhe). As barras FOME e SEDE caem no tempo ativo da cabine (20 e 30 pontos por dia jogável), cada consumo soma 50 e qualquer barra em zero encerra a missão. Dormir depois de um dia sem comer acorda o astronauta em estado crítico: as duas barras ficam em 5% e zeram em 10 s se ele não comer e beber. Para sair da Lua é preciso ter 3/3. O relatório mostra um veredito único e blocos por etapa. Detalhes em [docs/gameplay_prototype.md](docs/gameplay_prototype.md).

O relatório registra 100 pontos por tarefa concluída, inclusive com assistência, em um subtotal de 600 pontos das tarefas da tripulação. Avançar sem concluir uma delas a deixa pendente.

## Primeiro acesso

1. Aceite o convite do GitHub com sua conta pessoal.
2. Clone o repositório com `git clone https://github.com/devGustavoReis/Apollo6.git`.
3. Configure seu nome e e-mail de commit no clone. Use o endereço verificado ou o endereço privado fornecido pelo GitHub.
4. Quando chegar sua vez, sincronize e importe o `project.godot` da raiz do clone no gerenciador do Godot 4. Use o Godot 4.7.2, a versão usada para validar o projeto inicial.

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
