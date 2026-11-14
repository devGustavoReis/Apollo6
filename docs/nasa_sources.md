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

## Simplificações de gameplay

- Custos (milhões de dólares fictícios), massas e consumo de energia dos itens são valores de balanceamento.
  Cada item informa a origem no campo `source` de `data/equipment/equipment.json`.
- Água: na Apollo real, as células de combustível produziam água potável. No jogo, ela é uma reserva embarcada.
- Limites de pouso por dificuldade (V. vertical de 2,0 a 3,0 m/s, V. horizontal de 1,0 a 1,5 m/s, inclinação de 8° a 12°)
  são valores de jogo próximos da ordem de grandeza do projeto real, não reproduções exatas.
- Propelente do CSM em % e do LM em segundos de motor são abstrações.
- Eventos (falha de rádio, vazamento de água, controle térmico, alerta de energia) são plausíveis, mas fictícios nesta missão.
- Diálogos de Houston são fictícios e não reproduzem registros históricos.
