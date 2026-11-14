extends Control
## Menu principal: iniciar, dificuldade, configurações, créditos e sair.

const STARFIELD := preload("res://scripts/ui/starfield.gd")
const DIFF_KEYS := ["easy", "normal", "hard"]

var _difficulty := 1
var _diff_info: Label
var _sub_panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Control.new()
	bg.set_script(STARFIELD)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(520, 0)
	center.add_child(box)
	var title := Game.make_label("APOLLO6", 72, Game.AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Game.make_label("Uma missão lunar fictícia · 1969", 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(Control.new())
	_button(box, "INICIAR MISSÃO", _on_start).grab_focus()
	var diff_row := HBoxContainer.new()
	box.add_child(diff_row)
	diff_row.add_child(Game.make_label("DIFICULDADE", 18))
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in DIFF_KEYS:
		option.add_item(MissionState.DIFFICULTIES[key]["name"])
	option.select(_difficulty)
	option.item_selected.connect(_on_difficulty)
	diff_row.add_child(option)
	_diff_info = Game.make_label("", 15, Color(0.7, 0.7, 0.65))
	_diff_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_diff_info)
	_on_difficulty(_difficulty)
	_button(box, "CONFIGURAÇÕES", _on_settings)
	_button(box, "CRÉDITOS", _on_credits)
	_button(box, "SAIR", func(): get_tree().quit())
	var footer := Game.make_label("NASA Space Apps Challenge 2026 · Equipe Apollo 6 · UNIFAGOC", 14, Color(0.55, 0.55, 0.5))
	footer.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	footer.position = Vector2(-300, -36)
	add_child(footer)


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _on_difficulty(index: int) -> void:
	_difficulty = index
	var s: Dictionary = MissionState.DIFFICULTIES[DIFF_KEYS[index]]
	_diff_info.text = "%s Orçamento: US$ %.0f mi · Carga máx.: %.0f kg" % [s["summary"], s["budget"], s["mass_limit"]]


func _on_start() -> void:
	Game.start_new_mission(DIFF_KEYS[_difficulty])


func _open_panel(title: String) -> VBoxContainer:
	if _sub_panel:
		_sub_panel.queue_free()
	_sub_panel = PanelContainer.new()
	_sub_panel.set_anchors_preset(Control.PRESET_CENTER)
	_sub_panel.custom_minimum_size = Vector2(620, 0)
	_sub_panel.position = Vector2(-310, -220)
	add_child(_sub_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_sub_panel.add_child(box)
	box.add_child(Game.make_label(title, 26, Game.AMBER))
	return box


func _on_settings() -> void:
	var box := _open_panel("CONFIGURAÇÕES")
	for bus_name in ["Master", "Music", "Voice", "SFX", "Ambience"]:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus < 0:
			continue
		var row := HBoxContainer.new()
		var label := Game.make_label(bus_name.to_upper(), 16)
		label.custom_minimum_size = Vector2(140, 0)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(v): AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.001))))
		row.add_child(slider)
		box.add_child(row)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Tela cheia"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	box.add_child(fullscreen)
	_button(box, "FECHAR", func(): _sub_panel.queue_free())


func _on_credits() -> void:
	var box := _open_panel("CRÉDITOS")
	var text := Game.make_label(
		"APOLLO6 — Equipe Apollo 6\nCiência da Computação · UNIFAGOC · Ubá, MG\n\n" +
		"Missão, personagens e diálogos fictícios, inspirados no programa Apollo da NASA.\n" +
		"Thomas Walker não é um astronauta real.\n" +
		"Dados de referência: NASA (ver docs/nasa_sources.md).\n" +
		"Feito em Godot 4, com auxílio de ferramentas de IA.", 16)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	_button(box, "FECHAR", func(): _sub_panel.queue_free())
