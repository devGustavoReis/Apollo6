extends CanvasLayer
## Comunicações de rádio (autoload "Houston").
## A legenda segue o idioma selecionado. Os diálogos são fictícios.
## As falas gravadas são WAVs locais; mensagens novas podem usar só legenda.

const RADIO_AUDIO := "res://assets/audio/voice/"

signal line_finished
signal queue_empty

var _queue: Array = []
var _current: Dictionary = {}
var _time_left := 0.0
var _panel: PanelContainer
var _speaker: Label
var _subtitle: Label
var _voice: AudioStreamPlayer
var _tone: AudioStreamPlayer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -430
	_panel.offset_right = 430
	_panel.offset_top = -130
	_panel.offset_bottom = -16
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_speaker = _label(15, Color(0.96, 0.74, 0.36))
	_subtitle = _label(17, Color(0.75, 0.85, 0.75))
	for node in [_speaker, _subtitle]:
		box.add_child(node)
	_panel.visible = false
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)
	_tone = AudioStreamPlayer.new()
	_tone.bus = "Voice"
	_tone.volume_db = -18.0
	_tone.stream = _make_quindar_tone()
	add_child(_tone)


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## Tom de 2525 Hz usado nas transmissões reais do programa Apollo ("Quindar tone").
func _make_quindar_tone() -> AudioStreamWAV:
	var rate := 22050
	var samples := int(rate * 0.22)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var envelope := minf(1.0, minf(i, samples - i) / 200.0)
		var value := int(sin(TAU * 2525.0 * i / rate) * 9000.0 * envelope)
		data.encode_s16(i * 2, value)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


func say_recorded(id: String, english: String, portuguese: String, speaker := "HOUSTON") -> void:
	say(english, portuguese, speaker, RADIO_AUDIO + id + ".wav")


func say(english: String, portuguese: String, speaker := "HOUSTON", voice_path := "", channel := "RADIO") -> void:
	var stream: AudioStream
	if not voice_path.is_empty() and ResourceLoader.exists(voice_path, "AudioStream"):
		stream = load(voice_path) as AudioStream
	var caption := portuguese if Game.language == "pt_BR" else english
	var duration := 2.5 + caption.length() * 0.035
	if stream != null:
		duration = maxf(2.0, maxf(caption.length() * 0.038, stream.get_length() + 0.35))
	_queue.append({"en": english, "pt": portuguese, "speaker": speaker, "stream": stream, "duration": duration, "channel": channel})
	if _current.is_empty():
		_next()


## Fala do astronauta pelo mesmo painel e fila do rádio.
## Usa assets/audio/voice/<id>.wav quando existir; sem o arquivo, mostra só a legenda.
func astronaut_say(id: String, portuguese: String) -> void:
	var english := "I’m hungry." if id == "thomas_hungry" else "I’m thirsty."
	var voice_id := id if Game.language == "pt_BR" else id + "_en"
	say(english, portuguese, "THOMAS WALKER", RADIO_AUDIO + voice_id + ".wav", "CABIN")


func is_busy() -> bool:
	return not _current.is_empty()


func radio_time_remaining() -> float:
	var remaining := maxf(_time_left, 0.0) if is_busy() else 0.0
	for entry: Dictionary in _queue:
		remaining += entry["duration"]
	return remaining


func clear() -> void:
	_queue.clear()
	_current = {}
	_panel.visible = false
	_voice.stop()
	_tone.stop()


func skip_line() -> void:
	if not _current.is_empty():
		_time_left = 0.0


func _next() -> void:
	_voice.stop()
	_tone.stop()
	if _queue.is_empty():
		_current = {}
		_panel.visible = false
		queue_empty.emit()
		return
	_current = _queue.pop_front()
	var channel: String = _current.get("channel", "RADIO")
	_speaker.text = "▌ %s — %s" % [_current["speaker"], tr(channel)]
	_subtitle.text = _current["pt"] if Game.language == "pt_BR" and not str(_current["pt"]).is_empty() else _current["en"]
	_panel.visible = true
	_time_left = _current["duration"]
	_voice.stream = _current["stream"]
	# A duração e as legendas seguem disponíveis nos testes sem dispositivo de áudio.
	if _voice.stream != null and DisplayServer.get_name() != "headless":
		_voice.play()
	if _current["speaker"] == "HOUSTON" and DisplayServer.get_name() != "headless":
		_tone.play()


func _process(delta: float) -> void:
	var paused := get_tree().paused
	_voice.stream_paused = paused
	_tone.stream_paused = paused
	if paused:
		return
	if _current.is_empty():
		return
	_time_left -= delta
	if _time_left <= 0.0:
		line_finished.emit()
		_next()


func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().paused and not _current.is_empty() and event.is_action_pressed("advance"):
		skip_line()
