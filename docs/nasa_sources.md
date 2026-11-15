# Fontes e simplificações

## Dados reais usados

| Dado no jogo | Valor | Fonte |
| --- | --- | --- |
| Duração da missão (suprimentos) | 8 dias (Apollo 11: 8 d 3 h 18 min) | [NASA — Apollo 11 Mission Overview](https://www.nasa.gov/missions/apollo-11-mission-overview/) |
| Viagem até a Lua | 3 dias jogáveis | NASA — Apollo 11 Mission Overview |
| Ordem TLI → separação do CSM → acoplamento ao LM | Sequência da separação | [NASA SP-4029 — Apollo 11 Timeline](https://www.nasa.gov/wp-content/uploads/static/history/SP-4029/Apollo_11i_Timeline.htm) |
| Velocidade alvo da TLI | 10,83 km/s (35.545,6 ft/s) | [NASA SP-4029 — Apollo 11 Summary](https://www.nasa.gov/wp-content/uploads/static/history/SP-4029/Apollo_11a_Summary.htm) |
| Duração real da queima da TLI | cerca de 6 min (o jogo acelera o tempo) | NASA — Apollo 11 Mission Overview |
| Gravidade lunar no pouso | 1,62 m/s² | Valor físico padrão |
| Limites do pouso (velocidades e inclinação) | Inspirados nos fatores de projeto do trem de pouso | [NASA TN D-6850 — LM Landing Gear Subsystem](https://ntrs.nasa.gov/citations/19720018253) |
| Instrumentos científicos | Sismômetro, retrorrefletor, vento solar, câmera e amostras da Apollo 11. Magnetômetro a partir da Apollo 12 | NASA — Apollo 11 Mission Overview |
| Cartucho de LiOH, cabine a ~5 psi de O₂, tom Quindar, controle térmico passivo | Procedimentos e equipamentos do programa Apollo | Referências gerais do programa Apollo (NASA) |
| M01: itens soltos presos por velcro, presilhas, cintas e elásticos, cada um com lugar marcado | Explicação do minigame | [NASA TN D-7434 — Apollo Experience Report: Crew Station Integration, Stowage](https://www.nasa.gov/wp-content/uploads/static/history/alsj/tnD7434Stowage.pdf) |
| M02: dispensador que libera meia onça (cerca de 15 ml) de água quente ou fria por aperto, encaixado na válvula da embalagem | Explicação do minigame | [Smithsonian NASM — Dispenser, Water, Apollo, Training](https://www.airandspace.si.edu/es/collection-objects/dispenser-water-apollo-training/nasm_A19781909000) |
| M03: antena de alto ganho apontada à mão em pitch e yaw. Na Apollo 11, Houston pediu o modo manual e passou os ângulos | Explicação do minigame | [Electronics, 1º de maio de 1967 — antena de banda S do CSM](https://bitsavers.mirrorservice.org/magazines/Electronics/Electronics_V40_N09_19670501_CM_S-Band_Antenna.pdf) e [transcrição ar-solo da Apollo 11](https://apollo11.spacelog.org/03:13:28:42/03:22:56:37) |
| M04: conectores azuis para o gás que entra no traje e vermelhos para o que sai | Explicação do minigame | [Smithsonian — Connectors, Gemini IV Type](https://si.edu/es/object/connectors-gemini-iv-type%3Anasm_A19781495000) |
| M05: cortinas removíveis presas com velcro, sacos de dormir sob os assentos e luz vazando em volta das cortinas do módulo lunar na Apollo 11 | Explicação do minigame | [Smithsonian NASM — Shade, Rendezvous Window, Apollo 11](https://www.airandspace.si.edu/es/collection-objects/shade-rendezvous-window-right-apollo-11/nasm_A19791579000), [Smithsonian — Sleep Restraint, Apollo 11](https://dashboard.si.edu/object/sleep-restraint-apollo-11:nasm_A19980082000) e [NASA ALSJ — Working on the Moon: Sleep](https://www.nasa.gov/history/alsj/WOTM/WOTM-Sleep.html) |
| M06: pastilha germicida nas embalagens vazias, guardadas no compartimento de lixo | Explicação do minigame | [NASA TN D-7720 — Apollo Experience Report: Food Systems](https://www.nasa.gov/wp-content/uploads/static/history/alsj/AERTND7720Food.pdf) |

## Simplificações de gameplay

- Custos (milhões de dólares fictícios), massas e consumo de energia dos itens são valores de balanceamento.
  Cada item informa a origem no campo `source` de `data/equipment/equipment.json`.
- Água: na Apollo real, as células de combustível produziam água potável. No jogo, ela é uma reserva embarcada.
- Limites de pouso por dificuldade (V. vertical de 2,0 a 3,0 m/s, V. horizontal de 1,0 a 1,5 m/s, inclinação de 8° a 12°)
  são valores de jogo próximos da ordem de grandeza do projeto real, não reproduções exatas.
- Propelente do CSM em % e do LM em segundos de motor são abstrações.
- Eventos (falha de rádio, vazamento de água, controle térmico, alerta de energia) são plausíveis, mas fictícios nesta missão.
- Correção de rota: as missões Apollo previam janelas de correção de meio de curso na ida à Lua. O minigame de arrastar a nave
  pela rota é uma abstração: a correção real era uma queima curta de motor calculada com Houston.
- Minigames de cabine (M01 a M06): mecânicas, tempos e limites são abstrações de jogo. A fonte de M04 descreve os conectores
  do traje Gemini; o jogo usa o mesmo código de cores no traje da missão fictícia. As explicações educativas mostradas depois
  de cada conclusão (`scripts/mission/cabin_briefings.gd`) usam só as fontes públicas acima, sem citar entrevistas.
- Diálogos de Houston são fictícios e não reproduzem registros históricos.
