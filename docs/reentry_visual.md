# Reentrada e amerissagem em 3D

A lógica continua em `scripts/reentry/reentry_game.gd`, que mantém fases, controles, janela de 2 s,
resultados, HUD e transições. A apresentação 3D fica em `scripts/reentry/reentry_visual.gd`, que só
lê o estado (`phase`, `phase_time`, `altitude`, `attitude`, `paused`, `result`) e nunca o altera.
O visual é um `SubViewportContainer` (meia resolução, filtro *nearest*, como no pouso lunar)
inserido como primeiro filho da cena, atrás dos indicadores.

## Modelos (Blender)

- Fonte editável: `assets/source/reentry/apollo6_reentrada.blend`
- Script que gera tudo: `assets/source/reentry/modelar_reentrada.py`
  (`blender --background --python assets/source/reentry/modelar_reentrada.py -- <raiz do projeto>`)
- Exportado: `assets/models/reentry/reentry_set.glb`

| Peça | Uso |
| --- | --- |
| `CommandModule` | Casco cônico com chapas (textura), juntas rebaixadas, escotilha, janelas e portas do RCS. A escotilha marca a frente |
| `HeatShield` | Escudo separado, convexo, com anel periférico. Shader `heat_shield` (grafite, brilho na borda, manchas de queima) |
| `ServiceModule` | Afasta-se na fase `separation` |
| `HeatEnvelope`, `HeatEnvelopeOuter` | Envelopes de ar aquecido (shader `plasma`) |
| `ReentryTrail` | Filamentos cruzados do rastro (shader `trail`) |
| `DrogueChute`, `MainChute` | Cúpulas com gomos e faixas laranja e creme. Os cabos são recalculados a cada quadro no Godot |
| `EarthSphere`, `AtmosphereShell` | Terra (oceano, nuvens e ondas no shader `earth`) e faixa atmosférica |
| `CloudLayer`, `FoamDisc` | Camadas de nuvens a 6.500, 4.500 e 2.000 m, e a espuma da amerissagem |

## Ligação com o estado

| Estado do jogo | Resposta visual |
| --- | --- |
| `separation` + `phase_time` | Módulo de serviço se afasta |
| `entry` + `phase_time / ENTRY_TIME` | Calor nasce, atinge o pico (28% a 62% da fase) e some: escudo, envelope, rastro, faíscas, luz quente e tremor leve da câmera |
| `altitude` | Distância visual até o mar: comprimida acima de 3.050 m para mostrar a curvatura, linear abaixo. Também controla céu, névoa, nuvens e ondas |
| `drogue`/`window` + `attitude` | Estabilizadores abertos. A cápsula balança para o lado da marca do medidor |
| `mains` + `phase_time / 0.8` | Abertura dos três principais (mesmo tempo da versão 2D). Os estabilizadores são soltos |
| `splash` | Contato no nível do mar, respingos, espuma que se expande e cúpulas que caem na água |
| `paused` | Animações congeladas |

## Testes

`godot --headless --path . --script tests/reentry_visual_test.gd`

## Limitações

- Sem distorção de calor (custo alto no renderizador do jogo).
- As capturas foram feitas no renderizador Compatibility. Confira no Forward+ (F5 no editor).
