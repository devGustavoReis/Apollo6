# Protótipo jogável do APOLLO6

## Fluxo

```text
Menu (dificuldade) → Planejamento (orçamento, massa, energia)
→ Cutscenes de lançamento → TLI + separação do CSM [checkpoint "separation"]
→ Cutscene de acoplamento → Cabine Dias 1–3 (ida): tarefas, decisões e 1 evento aleatório
→ Inserção em órbita lunar → Escotilha do LM → Transição A (cobra 1/1) [checkpoint "landing"]
→ Pouso lunar (falha = repete só o pouso) → Transição B (cobra 1/1 e confere a reserva 3/3)
→ Cartela do Dia 4 → Cabine Dias 4–5 (volta): correção de trajetória, M04 e M03
→ Console do Dia 5 → Transição C (cobra 1/1) [checkpoint "reentry"]
→ Reentrada com janela dos paraquedas (falha = repete só a reentrada) → Relatório final
```

### Suprimentos

- Unidade: cota. 1 cota = 1 dia de comida ou água para a tripulação.
- Cada dia jogável pede 1 comida e 1 água. O dia é selado no descanso (Dias 1, 2 e 4) ou na transição (Dias 3 e 5). Consumo depois do selo conta para o dia seguinte.
- Cada transição cobra 1 de cada uma só vez. Se faltar, a missão termina naquela etapa e o relatório diz quanto faltou.
- Na transição B a nave precisa de 3/3 (Dias 4 e 5 mais a transição C). Plano exato 8/8 termina em 0/0.
- Comer mais que 1 por dia é permitido e gasta estoque. Pular um dia com estoque vira falha diária no relatório.

### Decisões

Escolhas adequadas têm 95% de desfecho favorável e escolhas ruins têm 5%. O sorteio usa `MissionState.sample()`, que lê `test_samples` nos testes. Cada decisão é resolvida uma vez só.

### Reentrada

Os paraquedas de estabilização abrem a 7.300 m e a cápsula desce a 470 m/s. Ao cruzar 3.050 m abre uma janela de 2,0 s para apertar ESPAÇO. Toque antes só mostra aviso. Perder a janela leva à tela de falha, com opção de repetir só a reentrada sem perder o pouso, os suprimentos e as decisões.

### Pouso

ESPAÇO segurado sobe o motor aos poucos e soltar baixa aos poucos. WASD inclina e soltar nivela. O radar fica centrado no alvo, com +X à direita e a frente (−Z) para cima, e mostra a seta de deslizamento. Falhas listam as causas na ordem vertical, lateral, inclinação, área e propelente, cada uma com uma dica. O valor exato do limite ainda é aceito.

### Corpo em primeira pessoa

O jogador vê as duas mãos e, olhando para baixo, o corpo com o traje. ESPAÇO empurra uma vez por toque na direção do olhar, só encostado ou segurando um apoio. No ar a velocidade se conserva. O contato com superfícies perde 75% da velocidade normal. Ao comer, a mão leva o item à boca e a cota é gasta no meio da animação. No descanso o jogador flutua até a área REST antes da cartela da noite.

A cena principal é `scenes/menu/main_menu.tscn`. `scenes/main.tscn` continua abrindo
a cabine com o controlador de inspeção do Gustavo, útil para revisar a arquitetura.

## Controles

| Etapa | Controles |
| --- | --- |
| Menu | Setas ou mouse escolhem · ENTER confirma · ←/→ mudam a dificuldade · ESC fecha o painel |
| Cabine | Mouse olha · ESPAÇO solta o cinto e empurra na direção do olhar · WASD dá impulsos curtos encostado · E interage · F tarefa · TAB checklist · ENTER pula fala/dica · ESC pausa |
| Comida e água | E em FOOD ou WATER pega o item · E de novo come ou bebe · Q devolve sem gastar |
| Transições | Botões liberam depois do tempo de leitura · VOLTAR À CABINE na transição A |
| Reentrada | ESPAÇO dentro da janela de 2 s abre os paraquedas principais · ESC pausa |
| Correção de rota | Clique na nave e arraste pela linha tracejada até a Lua · setas também movem · ESC pausa |
| Separação | ESPAÇO desliga o motor · 1, 2, 3 ou clique nos interruptores |
| Pouso | ESPAÇO segurado acelera o motor · W/S/A/D e setas inclinam · sem teclas o módulo se nivela |
| Cutscenes | ESPAÇO, ENTER, ESC ou clique pulam |

## Arquitetura

| Arquivo | Responsabilidade |
| --- | --- |
| `scripts/core/mission_state.gd` | Autoload `MissionState`: estado único da missão, planejamento, validação e checkpoints |
| `scripts/core/game.gd` | Autoload `Game`: troca de etapas, lista de cutscenes, controles e tema visual |
| `scripts/core/houston.gd` | Autoload `Houston`: rádio em inglês com legenda em português e tom Quindar |
| `data/equipment/equipment.json` | Catálogo do planejamento (custo, massa, energia, ciência e origem dos números) |
| `scripts/mission/mission_decisions.gd` | Decisões e eventos, com efeitos e explicações |
| `scripts/mission/cabin_game.gd` | Tutorial, tarefas por dia, interação e checklist de aproximação |
| `scripts/minigames/trajectory_minigame.gd` | Minigame de correção de rota, aberto pelo painel NAVIGATION no dia 1 |
| `scripts/mission/cabin_briefings.gd` | Textos dos minigames M01 a M06: instruções mostradas antes de começar (objetivo, controles e cuidado), fala de Houston e explicação educativa mostrada depois da conclusão |
| `scripts/player/zero_g_player.gd` | Thomas em microgravidade |
| `scripts/landing/landing_game.gd` | Física e HUD do pouso |
| `scripts/ui/landing_radar.gd` | Radar do pouso: alvo visto de cima e deslizamento do módulo |
| `scripts/ui/main_menu.gd` | Menu principal: itens, dificuldade, painéis, tema de pixels e filtro de TV |
| `scripts/ui/menu_backdrop.gd` | Cenário 3D do menu: módulo lunar, solo, pedras, bandeira e Terra |
| `scripts/ui/menu_logo.gd` | Logotipo APOLLO6 desenhado por polígonos |
| `scripts/ui/pixel_font.gd` | Fonte de pixels 5×7 montada em tempo de execução |
| `assets/shaders/menu/*` | Shaders do menu: solo, Terra, bandeira, manta dourada, estrelas, paleta e TV |
| `scripts/ui/*` | Planejamento, HUD da cabine e relatório |

Nenhum sistema guarda recurso próprio: tudo lê e escreve em `MissionState`.
Os checkpoints copiam os campos de `MissionState.SAVED_FIELDS`. Contadores de tentativas
ficam fora, para o relatório registrar quantas vezes cada etapa foi repetida.

## Menu principal

O menu não usa imagens prontas: o cenário é a cena 3D de `menu_backdrop.gd` (com o
`lunar_module.glb` do pouso), o logotipo e a fonte são desenhados por código e a Terra,
o solo e a bandeira saem de shaders. Para ajustar:

- Enquadramento: `CAMERA_POS`, `CAMERA_PITCH`, `LM_YAW` e a lista `ROCKS` em `menu_backdrop.gd`.
  As posições usam frações da tela 16:9.
- Textos e ordem dos itens: `_build_interface()` em `main_menu.gd`.
- Letras novas na fonte: tabela `GLYPHS` em `pixel_font.gd`. Só há maiúsculas, e o que
  faltar aparece na fonte do sistema.
- Filtro de TV: parâmetros no topo de `assets/shaders/menu/crt.gdshader`. O jogador pode
  desligá-lo em CONFIGURAÇÕES.

O 3D da cabine e do pouso é renderizado em um `SubViewport` com metade da resolução
(640×360) e filtro *nearest*, para o visual pixelado. A interface fica em resolução cheia.

## Correção de rota

Na volta, no Dia 4, o painel NAVIGATION mostra o desvio da trajetória de retorno e o minigame leva a nave até a Terra. Na ida, a correção de meio de curso é só uma decisão. As regras abaixo valem para o minigame.

No dia 1, o painel NAVIGATION mostra o desvio deixado pela TLI. Ao escolher corrigir
agora, abre o minigame: o jogador arrasta a nave pela rota até a Lua. Sair da faixa
(`traj_tol` em `MissionState.DIFFICULTIES`: 50, 36 e 26 px) conta um desvio e devolve
a nave ao último ponto. A correção custa `2 + 10 × desvio da TLI` % do propelente do
CSM, mais 1,5% por desvio (até 6). Sem desvios, o erro de trajetória zera. Cada desvio
mantém 25% dele. Até 1 desvio conta como decisão adequada no relatório.

## Como instalar os modelos dos equipamentos

`cabin_game.gd` cria, em tempo de execução, uma zona de interação invisível
(`StaticBody3D` na camada 2) e uma etiqueta `Label3D` em cada marcador de
`EquipmentSlots`. A interação é encontrada subindo a hierarquia até o marcador
com o metadado `interact_id`. Então:

1. Instancie o modelo como filho do marcador em `scenes/spacecraft_interior.tscn`,
   seguindo `docs/cabin_layout.md` (pivô no centro da base, frente para -Z).
2. As colisões do modelo podem ficar na camada 1. Mirar no modelo já aciona a interação.
3. Se a etiqueta flutuante atrapalhar, ajuste `_add_zone()` em `cabin_game.gd`.

FOOD e WATER ficam em `FoodStorage` e `WaterStorage`.

Já instalados: `scenes/spacecraft/equipment/food_rack.tscn` (8 pacotes de biscoito e bacon),
`water_rack.tscn` (8 bolsas de água) e `medical_rack.tscn` (bolsa MEDICAL KIT), com os modelos
de `assets/models/equipment/`. Os suportes não têm colisão. `cabin_game.gd` esconde um pacote
e uma bolsa a cada dia consumido (`_update_supplies`), seguindo `food_days` e `water_days`.

Também instalados: `main_console.tscn` em `MainConsole` (modelo `assets/models/cabin/main_console.glb`
com colisão do painel e do gabinete inferior) e `assets/models/cabin/crew_seat.glb` nos três assentos
(sem colisão). `nav_panel`, `radio_panel`, `life_support` e `power_panel` estão nos seus slots e
`lm_hatch` fecha a abertura do teto, todos sem colisão. O painel POWER é baixo para não tapar a
janela direita. O pouso usa `assets/models/landing/lunar_module.glb`. Se o arquivo faltar,
`landing_game.gd` monta o módulo provisório de caixas.
A escotilha do LM usa o marcador criado em `CabinStructure/HatchOpening/DockingAnchor`.

## Cutscenes

Converta os vídeos para Ogg Theora (`.ogv`) e salve com estes nomes em `assets/videos/`.
Sem o arquivo, o jogo mostra um cartão de texto no lugar.

| Arquivo | Momento |
| --- | --- |
| `01_launchpad.ogv`, `02_family_tv.ogv`, `03_liftoff.ogv` | Antes da separação |
| `separation_success.ogv`, `04_space_cabin.ogv` | Depois da separação, antes da cabine |
| `separation_fail.ogv` | Falha na TLI/separação |
| `undocking.ogv` | Entrada no módulo lunar |
| `landing_fail.ogv`, `landing_success.ogv` | Resultado do pouso |

Exemplo de conversão: `ffmpeg -i cena.mp4 -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 01_launchpad.ogv`.

## Testes

```powershell
godot --headless --path . --script tests/cabin_layout_test.gd
godot --headless --path . --script tests/flow_test.gd
godot --headless --path . --script tests/scene_flow_test.gd
godot --headless --path . --script tests/cabin_controls_test.gd
godot --headless --path . --script tests/cabin_minigames_integration_test.gd
godot --headless --path . --script tests/minigames_test.gd
godot --headless --path . --script tests/mission_rules_test.gd
```

`mission_rules_test` cobre os exemplos de suprimentos, saltos, reserva de partida, os quatro quadrantes das decisões com amostras controladas, a janela da reentrada (0; 1; 1,999; 2,000; 2,001 s, toque antecipado e cruzamento dentro de um quadro), as causas do pouso nos limites e a projeção do radar.

`cabin_controls_test` cobre regressões de controle: o jogador em microgravidade não sai
pela escotilha aberta e continua mirando nela encostado no teto, o Enter do teclado
numérico funciona na cena de inspeção e um segundo ESPAÇO após o corte da TLI não aciona
interruptores da separação. Também cobre o empurrão por toque, a deriva sem perda a 30, 60 e 120 FPS e a ajuda quando o jogador para no ar. `flow_test` verifica o planejamento, os 5 dias com cada evento e o saldo exato, o raio de interação,
o minigame de correção de rota, os checkpoints e se um piloto automático simples
consegue pousar em todas as dificuldades sem a reserva de propelente. `scene_flow_test` percorre as trocas de cena
reais do menu ao relatório, inclusive voltar da transição A, falha e repetição da separação, do pouso e da reentrada, e o saldo 8/8 → 0/0.

## Pendências conhecidas

- Modelos de TOOLS, STORAGE, CHECKLIST e REST, instrumentos científicos e crateras com relevo.
- Vídeos `.ogv`, trilha musical, vozes e efeitos sonoros (os barramentos já existem).
- Música de exploração e redução de volume durante as falas.
- O renderizador ainda é Forward Plus. O documento de design sugere testar o Compatibility.
