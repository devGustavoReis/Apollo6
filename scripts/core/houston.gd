extends CanvasLayer
## Comunicações de rádio (autoload "Houston").
## Fala em inglês com legenda em português. Os diálogos são fictícios.
## Para usar vozes gravadas, passe o caminho do áudio em say(..., voice_path).

signal line_finished
signal queue_empty

var _queue: Array = []
var _current: Dictionary = {}
var _time_left := 0.0
var _panel: PanelContainer
var _speaker: Label
var _english: Label
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
	_english = _label(19, Color(0.93, 0.89, 0.78))
	_subtitle = _label(17, Color(0.75, 0.85, 0.75))
	for node in [_speaker, _english, _subtitle]:
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


func say(english: String, portuguese: String, speaker := "HOUSTON", voice_path := "") -> void:
	_queue.append({"en": english, "pt": portuguese, "speaker": speaker, "voice": voice_path})
	if _current.is_empty():
		_next()


func is_busy() -> bool:
	return not _current.is_empty()


func clear() -> void:
	_queue.clear()
	_current = {}
	_panel.visible = false
	_voice.stop()


func skip_line() -> void:
	if not _current.is_empty():
		_time_left = 0.0


func _next() -> void:
	if _queue.is_empty():
		_current = {}
		_panel.visible = false
		queue_empty.emit()
		return
	_current = _queue.pop_front()
	_speaker.text = "▌ " + _current["speaker"] + " — RÁDIO"
	_english.text = _current["en"]
	_subtitle.text = _current["pt"]
	_panel.visible = true
	_time_left = 2.5 + (_current["en"].length() + _current["pt"].length()) * 0.035
	if _current["voice"] != "" and ResourceLoader.exists(_current["voice"]):
		_voice.stream = load(_current["voice"])
		_voice.play()
		_time_left = maxf(_time_left, _voice.stream.get_length() + 0.5)
	if _current["speaker"] == "HOUSTON":
		_tone.play()


func _process(delta: float) -> void:
	if _current.is_empty():
		return
	_time_left -= delta
	if _time_left <= 0.0:
		line_finished.emit()
		_next()


func _unhandled_input(event: InputEvent) -> void:
	if not _current.is_empty() and event.is_action_pressed("advance"):
		skip_line()
