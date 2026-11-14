# Protótipo jogável do APOLLO6

## Fluxo

```text
Menu (dificuldade) → Planejamento (orçamento, massa, energia)
→ Cutscenes de lançamento → TLI + separação do CSM [checkpoint "separation"]
→ Cutscene de acoplamento → Cabine: 3 dias de viagem com tarefas, decisões e 1 evento aleatório
→ Inserção em órbita lunar → Escotilha do LM [checkpoint "landing"]
→ Pouso lunar (falha = repete só o pouso) → Relatório final
```

A cena principal é `scenes/menu/main_menu.tscn`. `scenes/main.tscn` continua abrindo
a cabine com o controlador de inspeção do Gustavo, útil para revisar a arquitetura.

## Controles

| Etapa | Controles |
| --- | --- |
| Menu | Setas ou mouse escolhem · ENTER confirma · ←/→ mudam a dificuldade · ESC fecha o painel |
| Cabine | Mouse olha · ESPAÇO solta o cinto/sobe · CTRL desce · WASD move · E interage · TAB checklist · ENTER pula fala/dica · ESC pausa |
| Comida e água | E em FOOD ou WATER pega o item do suporte · E de novo come ou bebe |
| Correção de rota | Clique na nave e arraste pela linha tracejada até a Lua · setas também movem · ESC pausa |
| Separação | ESPAÇO desliga o motor · 1, 2, 3 ou clique nos interruptores |
| Pouso | W/S potência · A/D e setas inclinam · sem teclas o módulo se nivela |
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
```

`cabin_controls_test` cobre regressões de controle: o jogador em microgravidade não sai
pela escotilha aberta e continua mirando nela encostado no teto, o Enter do teclado
numérico funciona na cena de inspeção e um segundo ESPAÇO após o corte da TLI não aciona
interruptores da separação. `flow_test` verifica o planejamento, os 3 dias com cada evento, o raio de interação,
o minigame de correção de rota, os checkpoints e se um piloto automático simples
consegue pousar em todas as dificuldades sem a reserva de propelente. `scene_flow_test` percorre as trocas de cena
reais, inclusive falha e repetição da separação e do pouso.

## Pendências conhecidas

- Modelos de TOOLS, STORAGE, CHECKLIST e REST, instrumentos científicos e crateras com relevo.
- Vídeos `.ogv`, trilha musical, vozes e efeitos sonoros (os barramentos já existem).
- Música de exploração e redução de volume durante as falas.
- O renderizador ainda é Forward Plus. O documento de design sugere testar o Compatibility.
