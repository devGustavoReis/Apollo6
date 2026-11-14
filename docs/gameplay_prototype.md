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
| Cabine | Mouse olha · ESPAÇO solta o cinto/sobe · CTRL desce · WASD move · E interage · TAB checklist · ENTER pula fala/dica · ESC pausa |
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
| `scripts/player/zero_g_player.gd` | Thomas em microgravidade |
| `scripts/landing/landing_game.gd` | Física e HUD do pouso |
| `scripts/ui/*` | Menu, planejamento, HUD da cabine e relatório |

Nenhum sistema guarda recurso próprio: tudo lê e escreve em `MissionState`.
Os checkpoints copiam os campos de `MissionState.SAVED_FIELDS`. Contadores de tentativas
ficam fora, para o relatório registrar quantas vezes cada etapa foi repetida.

O 3D da cabine e do pouso é renderizado em um `SubViewport` com metade da resolução
(640×360) e filtro *nearest*, para o visual pixelado. A interface fica em resolução cheia.

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
```

`flow_test` verifica o planejamento, os 3 dias com cada evento, o raio de interação,
os checkpoints e se um piloto automático simples consegue pousar em todas as
dificuldades sem a reserva de propelente. `scene_flow_test` percorre as trocas de cena
reais, inclusive falha e repetição da separação e do pouso.

## Pendências conhecidas

- Modelos dos equipamentos, módulo lunar definitivo e cenário lunar.
- Vídeos `.ogv`, trilha musical, vozes e efeitos sonoros (os barramentos já existem).
- Música de exploração e redução de volume durante as falas.
- O renderizador ainda é Forward Plus. O documento de design sugere testar o Compatibility.
