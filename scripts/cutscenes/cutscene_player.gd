extends Control
## Sistema universal de cutscenes. Lê a sequência em Game.cutscene_entries.
## Toca o vídeo .ogv quando existe. Caso contrário, mostra um cartão de texto.
## ESPAÇO, ENTER ou ESC pulam a sequência inteira e aplicam o estado final.

var _index := -1
var _time_left := 0.0
var _video: VideoStreamPlayer
var _card: VBoxContainer
var _title: Label
var _caption: Label
var _done := false


func _ready() -> void:
	Sound.enter_scene("cutscene")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_video = VideoStreamPlayer.new()
	_video.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video.expand = true
	_video.bus = "SFX"
	_video.finished.connect(_next)
	add_child(_video)
	_card = VBoxContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.custom_minimum_size = Vector2(900, 200)
	_card.position = Vector2(-450, -100)
	add_child(_card)
	_title = Game.make_label("", 44, Game.AMBER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption = Game.make_label("", 22)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(_title)
	_card.add_child(_caption)
	var hint := Game.make_label(str(TranslationServer.translate("ESPAÇO · pular")), 16, Color(0.6, 0.6, 0.55))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-200, -40)
	add_child(hint)
	if Game.cutscene_entries.is_empty():
		_finish()
		return
	_next()


func _next() -> void:
	if _done:
		return
	_index += 1
	if _index >= Game.cutscene_entries.size():
		_finish()
		return
	var entry: Dictionary = Game.cutscene_entries[_index]
	var path: String = entry.get("video", "")
	var has_video := path != "" and ResourceLoader.exists(path)
	Sound.cutscene_segment(Game.cutscene_id, _index, has_video)
	if has_video:
		_card.visible = false
		_video.visible = true
		_video.stream = load(path)
		_video.play()
		_time_left = -1.0
	else:
		_video.visible = false
		_card.visible = true
		_title.text = entry.get("title", "")
		_caption.text = entry.get("caption", "")
		_card.modulate.a = 0.0
		create_tween().tween_property(_card, "modulate:a", 1.0, 0.4)
		_time_left = entry.get("duration", 3.0)


func _process(delta: float) -> void:
	if _time_left > 0.0:
		_time_left -= delta
		if _time_left <= 0.0:
			_next()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			_finish()
	elif event is InputEventMouseButton and event.pressed:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	_video.stop()
	Sound.end_maneuver()
	Game.finish_cutscene()
