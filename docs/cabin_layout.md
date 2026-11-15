# Cabine do APOLLO6

Consulte [Cabine 3D](cabin_art.md) para os assets do Blender, o mapa de montagem e a reexportação.

## Uso

A cena principal instancia `scenes/spacecraft_interior.tscn`. Abra essa cena para
editar a arquitetura e instalar equipamentos. Todos os meshes e colisores estão
salvos como nós editáveis. A geometria é independente do controlador de inspeção.

A cena `scenes/main.tscn` (F6) abre a cabine com o controlador de inspeção e Thomas sentado. O jogo completo (F5) começa no menu e usa `scenes/spacecraft/cabin_game.tscn`. Enter (principal ou do teclado numérico) alterna entre a câmera sentada e a posição de
exploração. Clique captura o mouse, WASD move e Esc libera o cursor. A troca de
posição é instantânea e serve para inspeção. O controlador é
`scripts/cabin_preview.gd`, no nó `PreviewPlayer`. Ao integrar o jogador
definitivo, substitua esse nó e use os marcadores de `PlayerStart`.

## Referência e adaptação

As imagens das cutscenes do Google Flow não estavam disponíveis neste checkout.
A arquitetura usa formas simplificadas do módulo de comando Apollo, com paredes
facetadas, teto inclinado, três janelas e abertura superior de acoplamento.
A escala foi ampliada para permitir exploração em primeira pessoa. A cabine é
uma adaptação para a missão fictícia, com piso horizontal e gravidade de teste.
O módulo real possuía cinco janelas e duas escotilhas. A correspondência exata
com a cutscene precisa ser ajustada quando a referência estiver disponível.

Referência consultada — [NASA, Command Module Overview](https://www.nasa.gov/wp-content/uploads/static/history/alsj/CSM06_Command_Module_Overview_pp39-52.pdf).

## Hierarquia

```text
SpacecraftInterior
  CabinStructure
    Walls
    Floor
    Ceiling
    Windows
    HatchOpening
      DockingAnchor
    Supports
  CollisionStructure
  EquipmentSlots
    SeatLeft / SeatCenter / SeatRight
    MainConsole / NavigationPanel / RadioPanel
    FoodStorage / WaterStorage / GeneralStorage
    LifeSupport / PowerPanel / ToolsStorage / MedicalStorage
    Checklist / RestArea
  PlayerStart
    SeatedEye
    ExplorationStart
  ExteriorBackdrop
  Lighting
    CabinEnvironment
    CabinLight0 / CabinLight1
  PreviewPlayer
```

## Dimensões e coordenadas

Uma unidade equivale a um metro. +Y aponta para cima, -Z para o painel frontal,
-X para a esquerda do astronauta sentado e +X para a direita.
O piso está em Y=0. O contorno mede 4,0 m em X por 3,8 m em Z, com cantos
recortados em 0,65 m. As paredes chegam a Y=1,65 m. O teto sobe em facetas
até Y=2,60 m, com contorno superior reduzido a 78% do contorno do piso.
As paredes têm 0,12 m de espessura, centradas no contorno nominal.

As três janelas têm vão de 0,72 × 0,48 m, entre Y=1,05 e 1,53 m.
Uma fica na parede frontal e duas nas laterais. O vidro transparente possui
colisão. `ExteriorBackdrop` recebe futuramente o cenário espacial.

A abertura no teto mede 0,88 × 0,96 m e está centrada em (0, 2,60, 0,60).
`DockingAnchor` fica em (0, 2,78, 0,60). Seu eixo +Y aponta para o futuro túnel.
A travessia vertical exige o sistema futuro de escalada ou deslocamento em
microgravidade. A inspeção atual permite caminhar até a área sob a abertura.

## Instalação dos modelos

Todos os slots têm escala (1,1,1). O pivô do modelo deve ficar no centro da base
e sua frente deve apontar para -Z local. Instancie o modelo como filho do
marcador com posição e rotação locais zeradas. As dimensões são máximas
recomendadas nos eixos locais largura × altura × profundidade.
As rotações abaixo são em graus em torno de Y. Os slots também armazenam
`max_size_m`, `model_origin` e `model_front` como metadados.

| Slot | Posição X, Y, Z (m) | Rotação Y | Dimensões locais (m) |
| --- | --- | --- | --- |
| SeatLeft | -0,85; 0; -0,45 | 0° | 0,66 × 1,05 × 1,00 |
| SeatCenter | 0; 0; -0,45 | 0° | 0,66 × 1,05 × 1,00 |
| SeatRight | 0,85; 0; -0,45 | 0° | 0,66 × 1,05 × 1,00 |
| MainConsole | 0; 0,65; -1,50 | 180° | 2,40 × 0,45 × 0,48 |
| NavigationPanel | -0,97; 1,70; -1,48 | 180° | 0,55 × 0,32 × 0,15 |
| RadioPanel | 0,97; 1,70; -1,48 | 180° | 0,55 × 0,32 × 0,15 |
| FoodStorage | -1,72; 0,15; 0,35 | -90° | 0,55 × 0,65 × 0,38 |
| WaterStorage | -1,72; 0,85; 0,35 | -90° | 0,55 × 0,65 × 0,38 |
| GeneralStorage | -1,65; 0,15; 1,00 | -90° | 0,45 × 0,65 × 0,32 |
| LifeSupport | 1,72; 0,15; 0,35 | 90° | 0,55 × 0,65 × 0,38 |
| PowerPanel | 1,72; 0,85; 0,35 | 90° | 0,55 × 0,65 × 0,38 |
| ToolsStorage | 1,65; 0,15; 1,00 | 90° | 0,45 × 0,55 × 0,32 |
| MedicalStorage | 1,65; 0,85; 1,00 | 90° | 0,45 × 0,55 × 0,32 |
| Checklist | 0; 1,15; 1,73 | 0° | 0,45 × 0,40 × 0,08 |
| RestArea | 0; 0,10; 1,45 | 0° | 1,80 × 0,50 × 0,42 |

As cadeiras ocupam Z=-0,95 até +0,05. Preserve a passagem atrás delas,
principalmente Z=0,35 até 1,15 e X=-1,20 até 1,20. Os intervalos entre as
cadeiras são de 0,19 m e servem à separação dos modelos. A passagem do jogador
acontece por trás. `RestArea` reserva uma rede dobrada ou suporte compacto.
Uma superfície de descanso aberta deve ser recolhida durante a circulação.
Os painéis laterais apontam para o centro da cabine.

## Câmera e colisões

`SeatedEye` fica em (0, 1,12, -0,30), olhando para -Z, com FOV de 78° e
plano próximo de 0,04 m na câmera de inspeção. A posição é uma referência para
o raccord com a cutscene. O encosto da cadeira central deve respeitar esse ponto.
`ExplorationStart` fica em (0, 0,04, 0,72). Na exploração, os olhos estão
1,55 m acima dos pés. A cápsula de colisão tem raio de 0,22 m e altura de 1,65 m.

`CollisionStructure` contém corpos estáticos em layer 1, com nomes
correspondentes às peças visuais. Paredes e armações usam caixas. Piso e teto
usam triângulos com colisão nas duas faces. Mantenha as transformações das
peças visuais e dos colisores correspondentes ao modificar a arquitetura.
O vão da escotilha está livre na cena. No jogo, `cabin_game.gd` cria o tampão
invisível `HatchBarrier` na base do colar, na camada 8, que só o jogador em
microgravidade enxerga: assim ele não sai da nave pelo vão, e os raios de
interação e o volume reservado ao acoplamento continuam livres. As janelas usam peças de parede separadas
ao redor do vidro, sem parede contínua atravessando os vãos.

Adicione colisões dos equipamentos às próprias cenas dos modelos. Respeite
os envelopes e a passagem descritos acima. Para a postura sentada, o controlador
de inspeção desativa sua cápsula. Ao retornar à exploração, ele usa o ponto livre
atrás das cadeiras. O controlador definitivo deve integrar essa transição.

## Verificação

Execute `godot --headless --path . --script tests/cabin_layout_test.gd`.
O teste verifica câmera inicial, abertura da escotilha, vidro frontal,
suporte do piso, parada na parede traseira, folga da cápsula na passagem e
interseção dos envelopes dos equipamentos com o casco.
`tests/cabin_controls_test.gd` cobre os controles da cabine do jogo e da inspeção.
Em execução gráfica, também salva uma imagem em `.godot/cabin_review.png`.
Execute F5 para revisar o interior visualmente e experimentar os controles.
