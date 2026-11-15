# Áudio do APOLLO6

## Faixa e mixagem

- assets/audio/music/descent_to_tranquility.ogg — "Launch - Descent to Tranquility - Apollo6", faixa fornecida pelo projeto. O arquivo recebido é Ogg Opus; o recurso do jogo foi convertido para Ogg Vorbis, estéreo a 48 kHz, sem alterar andamento, duração ou estrutura. O original foi preservado no local de origem. Confirme a licença de distribuição da faixa com seu autor antes de publicar uma build.
- A faixa dura aproximadamente 4 min 03 s. A análise em janelas de 20 s mostrou um início mais contido, crescimento em 1:00–1:40, novo crescimento em 2:20–3:40 e queda de volume no final. As transições do jogo preservam a posição da faixa na ida do menu ao planejamento. A faixa termina naturalmente e pode voltar após um intervalo nas telas de interface ou nas cutscenes. A cabine mantém seu ambiente quando isso acontecer.
- Os efeitos do catálogo CUES e os loops de ventilação, motor e pulso são sínteses originais em scripts/core/mission_audio.gd. Não usam gravações externas. O menu e o rádio mantêm seus tons sintetizados anteriores. As falas continuam disponíveis como texto na ausência de gravação.
- Music controla tema e pulso. Ambience controla a cabine. SFX controla motor, efeitos espaciais e áudio dos vídeos. Interface envia para SFX. Voice preserva rádio e alertas prioritários. Master controla a saída. Os controles do menu gravam as preferências em user://audio_settings.cfg. Zero silencia o bus.
- No pouso, o alerta e o pulso entram abaixo de 20% de combustível. O nível de recuperação é 25%, e o pulso termina ao concluir ou abortar a manobra. Rádio e alertas reduzem temporariamente música e sons contínuos.
- Com microgravidade na cabine, o contato com superfícies usa o movimento e a colisão do corpo. O áudio não imita passos de caminhada quando o personagem flutua.

- Transições usam o nível de interface e mantêm o tema. A reentrada tem nível próprio: o motor sintetizado marca o plasma e os estabilizadores, e alertas e cues de sucesso ou aborto marcam a janela dos paraquedas.

## Trilha da descida lunar

Cosmic Ascent — Apollo 13 — Treblo foi fornecida pelo projeto e convertida de Ogg Opus para Vorbis. A música entra ao iniciar a descida pilotada, volta ao começo a cada tentativa e sai após o toque ou aborto. A faixa termina naturalmente em descidas longas. Vozes e alertas mantêm prioridade na mixagem. Descent to Tranquility continua como tema das demais etapas.

## Cutscenes

As cenas usam o áudio do vídeo quando ele está disponível, com redução do tema. Os cartões de fallback dão espaço para ignição, vibração, encaixe e aborto conforme o evento. Ao pular o vídeo, seu player é interrompido e a próxima cena define o ambiente.

## Minigames da cabine

As tarefas da cabine usam switch ao abrir, warning para falha, success para acerto direto e assist para conclusão assistida. O resultado de MissionState.resolve_minigame_attempt determina a mensagem e o som. A tela de resultado identifica a ferramenta quando ela recupera uma tentativa.

| Tarefa | Som de ação a considerar |
| --- | --- |
| Prender objetos | Clique de encaixe e trava de cinta |
| Abastecer água | Conector e fluxo durante o enchimento |
| Recuperar sinal | Chiado breve e canal estável |
| Conector do traje | Encaixe e trava confirmada |
| Preparar descanso | Tecido e clique de fixação |
| Guardar embalagens | Papel e fechamento da bolsa |

## Vozes do rádio

As 24 falas do fluxo atual foram pré-renderizadas em inglês americano, com WAV mono a 24 kHz. Houston usa a voz am_michael e Eagle usa am_eric na confirmação de contato. São vozes sintetizadas do catálogo do modelo. As legendas em português e o controle de volume Vozes continuam disponíveis.

A geração foi feita localmente com [Kokoro-82M v1.0](https://huggingface.co/hexgrad/Kokoro-82M) (pesos Apache-2.0) e [kokoro-onnx](https://github.com/thewh1teagle/kokoro-onnx) (MIT). Cada fala recebeu filtragem leve de rádio e normalização. As falas de Houston incluem espaço inicial para o tom de chamada. O modelo e suas dependências ficam fora do projeto e da distribuição do jogo.

Os clipes ficam em assets/audio/voice. Use Houston.say_recorded com o identificador do arquivo sem extensão e forneça a fala em inglês e a legenda em português. O sistema aceita falas sem arquivo e exibe o texto nesses casos. ENTER pula a fala atual. A autorização para descida, o aviso de propelente baixo e a confirmação de pouso integram-se aos estados já existentes. O aviso de combustível é falado uma vez por tentativa de pouso. As confirmações de separação e pouso têm tempo para concluir antes da próxima cena.

Na descida lunar, a música começa no segundo 48 a cada tentativa. A cabine pulsa uma luz vermelha e toca um alarme de cinco segundos após uma escolha arriscada. A pausa suspende ambos.

As operações na superfície usam os clipes ingleses `surface_*.wav` e um efeito de obturador separado no barramento SFX.
Os avisos do astronauta têm clipes ingleses próprios, com o sufixo `_en`. A legenda de rádio segue apenas o idioma selecionado.
