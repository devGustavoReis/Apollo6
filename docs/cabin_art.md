# Cabine 3D do APOLLO6

A cabine do módulo de comando usa módulos modelados no Blender 5.3. A referência foi o interior Apollo de 1969, adaptado às três janelas, aos volumes de circulação e às interações do jogo. Os instrumentos físicos são cenográficos. Os dados operacionais continuam nos painéis do jogo.

## Montagem

| Coleção Blender / GLB | Instância no Godot |
| --- | --- |
| `main_console` | `EquipmentSlots/MainConsole/Console/Model`. Os colisores do gabinete estão na cena `scenes/spacecraft/equipment/main_console.tscn`. |
| `nav_panel`, `radio_panel` | `NavigationPanel/Model` e `RadioPanel/Model`. |
| `life_support`, `power_panel` | `LifeSupport/Model` e `PowerPanel/Model`. |
| `crew_seat` | `SeatLeft/Seat`, `SeatCenter/Seat` e `SeatRight/Seat`. |
| `cabin_wall_panels`, `cabin_deck_panels`, `cabin_roof_trim` | Revestimentos sob `CabinStructure/Walls`, `Floor` e `Ceiling`, em coordenadas da cabine. |
| `cabin_hatch_trim` | Arremates sob `CabinStructure/HatchOpening`. A porta e a barreira mantêm a gestão do jogo. |
| `cabin_markings` | Placas no gabinete frontal e na parede traseira, sob `CabinStructure`. |
| `lunar_flag` | `scripts/ui/menu_backdrop.gd`, no cenário em que o módulo já está pousado. A escala do mastro segue o ponto de composição do menu. |

A fonte `assets/source/cabin/apollo6_cabine.blend` abre na cena **Cabine montada**. Edite os componentes na cena **Peças editáveis**, com escala métrica e uma coleção por modelo. O GLB agrupa cada coleção em uma malha com superfícies por material. Inscrições, bandeiras e indicadores têm geometria própria e materiais PBR, com UV de projeção e sem texturas externas. O arquivo `.gdignore` impede a importação automática da fonte na árvore de recursos do jogo.

Para exportar um `.blend` editado, a partir da raiz do projeto:

```powershell
$blender = 'C:\Program Files\Blender Foundation\Blender 5.3\blender.exe'
$source = (Resolve-Path assets/source/cabin/apollo6_cabine.blend).Path
$script = (Resolve-Path assets/source/cabin/modelar_cabine.py).Path
& $blender --background $source --python-exit-code 1 --python $script -- (Get-Location).Path reexport
```

O modo `reexport` mantém a fonte e exporta as coleções editadas. Para gerar a fonte do zero, use `--factory-startup`, tire o caminho da fonte e o argumento `reexport`, e use uma cópia de trabalho para preservar edições já feitas no Blender. Os GLBs vão para `assets/models/cabin/`. A bandeira lunar vai para `assets/models/landing/`. Salve os metadados de importação junto dos recursos.

## Referências e autoria

- Formas e disposição dos instrumentos, assentos e baias. [Diagramas do programa Apollo — NASA](https://www.nasa.gov/history/diagrams/apollo.html) · [Columbia em 3D — Smithsonian](https://airandspace.si.edu/stories/editorial/3d-command-module-columbia)
- Bandeiras dos EUA construídas com 13 listras e 50 estrelas. Peça lunar com haste, travessa e dobras fixas. [Proporções da bandeira dos EUA](https://www.govinfo.gov/content/pkg/USCODE-2024-title4/pdf/USCODE-2024-title4-chap1-sec2.pdf) · [Implantação da bandeira lunar — NASA](https://www.nasa.gov/history/50-years-ago-one-small-step-one-giant-leap/)
- Geometria, inscrições e placas APOLLO6 produzidas para o projeto no Blender com assistência do Codex. A NASA aparece como fonte histórica. As placas de cabine usam a identificação original em letras do APOLLO6. [Diretrizes de mídia da NASA](https://www.nasa.gov/nasa-brand-center/images-and-media/)
