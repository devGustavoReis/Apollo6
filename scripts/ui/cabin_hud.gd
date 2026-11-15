extends CanvasLayer
## Interface da cabine: mira, objetivo, recursos, checklist, painéis e pausa.

signal modal_closed

var _prompt: Label
var _objective_title: Label
var _objective_text: Label
var _tutorial: Label
var _status: RichTextLabel
var _checklist: PanelContainer
var _checklist_text: RichTextLabel
var _modal: PanelContainer
var _modal_title: Label
var _modal_body: RichTextLabel
var _modal_buttons: VBoxContainer
var _modal_callback: Callable
var _pause: PanelContainer
var _dim: ColorRect
var minigame: Control
var _minigame_cancel: Callable
var _night: ColorRect
var _night_tween: Tween


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cross := Game.make_label("+", 22, Color(1, 1, 1, 0.75))
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-6, -15)
	add_child(cross)
	_prompt = Game.make_label("", 20, Game.AMBER)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(700, 30)
	_prompt.position = Vector2(-350, 24)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 6)
	add_child(_prompt)

	var objective := PanelContainer.new()
	objective.position = Vector2(16, 16)
	objective.custom_minimum_size = Vector2(430, 0)
	add_child(objective)
	var obox := VBoxContainer.new()
	objective.add_child(obox)
	_objective_title = Game.make_label("", 17, Game.AMBER)
	_objective_text = Game.make_label("", 16)
	_objective_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_text.custom_minimum_size = Vector2(400, 0)
	_tutorial = Game.make_label("", 16, Color(0.6, 0.95, 0.75))
	_tutorial.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial.custom_minimum_size = Vector2(400, 0)
	obox.add_child(_objective_title)
	obox.add_child(_objective_text)
	obox.add_child(_tutorial)
	var keys := Game.make_label("TAB checklist · E interagir · F tarefa · ESC pausa", 13, Color(0.6, 0.6, 0.55))
	obox.add_child(keys)

	var status_panel := PanelContainer.new()
	status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status_panel.position = Vector2(-300, 16)
	status_panel.custom_minimum_size = Vector2(284, 0)
	add_child(status_panel)
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.scroll_active = false
	_status.custom_minimum_size = Vector2(260, 0)
	_status.add_theme_font_size_override("normal_font_size", 15)
	status_panel.add_child(_status)

	_checklist = PanelContainer.new()
	_checklist.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_checklist.position = Vector2(-440, -170)
	_checklist.custom_minimum_size = Vector2(420, 0)
	_checklist.visible = false
	add_child(_checklist)
	_checklist_text = RichTextLabel.new()
	_checklist_text.bbcode_enabled = true
	_checklist_text.fit_content = true
	_checklist_text.custom_minimum_size = Vector2(390, 0)
	_checklist.add_child(_checklist_text)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.7)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	add_child(_dim)

	_modal = PanelContainer.new()
	_modal.set_anchors_preset(Control.PRESET_CENTER)
	_modal.custom_minimum_size = Vector2(720, 0)
	_modal.position = Vector2(-360, -230)
	_modal.visible = false
	add_child(_modal)
	var mbox := VBoxContainer.new()
	mbox.add_theme_constant_override("separation", 12)
	_modal.add_child(mbox)
	_modal_title = Game.make_label("", 24, Game.AMBER)
	mbox.add_child(_modal_title)
	_modal_body = RichTextLabel.new()
	_modal_body.bbcode_enabled = true
	_modal_body.fit_content = true
	_modal_body.custom_minimum_size = Vector2(680, 0)
	mbox.add_child(_modal_body)
	_modal_buttons = VBoxContainer.new()
	_modal_buttons.add_theme_constant_override("separation", 8)
	mbox.add_child(_modal_buttons)

	_pause = PanelContainer.new()
	_pause.set_anchors_preset(Control.PRESET_CENTER)
	_pause.position = Vector2(-200, -120)
	_pause.custom_minimum_size = Vector2(400, 0)
	_pause.visible = false
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause)
	var pbox := VBoxContainer.new()
	pbox.add_theme_constant_override("separation", 10)
	_pause.add_child(pbox)
	pbox.add_child(Game.make_label("PAUSA", 26, Game.AMBER))
	for entry in [["CONTINUAR", toggle_pause], ["MENU PRINCIPAL", func(): Game.go("menu")], ["SAIR DO JOGO", func(): get_tree().quit()]]:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(0, 42)
		b.pressed.connect(entry[1])
		pbox.add_child(b)

	MissionState.changed.connect(refresh_status)
	refresh_status()


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_objective(title: String, text: String) -> void:
	_objective_title.text = title
	_objective_text.text = text


func set_tutorial(text: String) -> void:
	_tutorial.text = text
	_tutorial.visible = text != ""


func refresh_status() -> void:
	var ms := MissionState
	var needed := ms.days_still_needed()
	var lines := "[color=#f5bd5c]DIA %d/%d · VIAGEM À LUA[/color]\n" % [ms.day, ms.TRAVEL_DAYS]
	lines += _line("COMIDA", "%.1f dias" % ms.food_days, ms.food_days < needed, ms.food_days < needed + 1)
	lines += _line("ÁGUA", "%.1f dias" % ms.water_days, ms.water_days < needed, ms.water_days < needed + 1)
	var use := ms.power_use()
	lines += _line("ENERGIA", "%.0f/%.0f W" % [use, ms.power_capacity], use > ms.power_capacity, use > ms.power_capacity * 0.8)
	lines += _line("PROPEL. CSM", "%.0f%%" % ms.sps_fuel, ms.sps_fuel < 45, ms.sps_fuel < 70)
	lines += _line("SUPORTE VIDA", "%.0f%%" % ms.life_support, ms.life_support < 50, ms.life_support < 85)
	lines += _line("INTEGRIDADE", "%.0f%%" % ms.integrity, ms.integrity < 60, ms.integrity < 90)
	_status.text = lines


func _line(name: String, value: String, bad: bool, warn: bool) -> String:
	var color := "#ff5f50" if bad else ("#ffcc44" if warn else "#77ee77")
	return "%s [color=%s]%s[/color]\n" % [name.rpad(13), color, value]


func show_checklist(tasks: Array) -> void:
	var text := "[color=#f5bd5c]CHECKLIST · DIA %d[/color]\n" % MissionState.day
	for task in tasks:
		var done: bool = task["done"]
		var mark := "[color=#77ee77][x][/color]" if done else "[ ]"
		var optional := " (opcional)" if task.get("optional", false) else ""
		text += "%s [b]%s[/b] — %s%s\n" % [mark, task["station"], task["text"], optional]
	text += "\n[color=#999]TAB fecha · F inicia tarefas na estação[/color]"
	_checklist_text.text = text


func toggle_checklist(tasks: Array) -> bool:
	_checklist.visible = not _checklist.visible
	if _checklist.visible:
		show_checklist(tasks)
	return _checklist.visible


func checklist_visible() -> bool:
	return _checklist.visible


func show_modal(title: String, body: String, buttons: Array, callback: Callable = Callable()) -> void:
	_modal_title.text = title
	_modal_body.text = body
	for child in _modal_buttons.get_children():
		child.queue_free()
	_modal_callback = callback
	for i in buttons.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, buttons[i]] if buttons.size() > 1 else buttons[i]
		b.custom_minimum_size = Vector2(0, 42)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_modal_button.bind(i))
		_modal_buttons.add_child(b)
		if i == 0:
			b.call_deferred("grab_focus")
	_modal.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_modal_button(index: int) -> void:
	_modal.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var callback := _modal_callback
	_modal_callback = Callable()
	modal_closed.emit()
	if callback.is_valid():
		callback.call(index)


func modal_open() -> bool:
	return _modal.visible or minigame != null or _night != null


func open_minigame(node: Control, cancel := Callable()) -> void:
	minigame = node
	_minigame_cancel = cancel
	_dim.visible = true
	add_child(node)
	move_child(node, _modal.get_index())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_minigame() -> void:
	if minigame == null:
		return
	minigame.set_process(false)
	minigame.hide()
	minigame.queue_free()
	minigame = null
	_minigame_cancel = Callable()
	_dim.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func cancel_minigame() -> void:
	if minigame == null or not _minigame_cancel.is_valid():
		return
	var cancel := _minigame_cancel
	close_minigame()
	cancel.call()


func show_night(next_day: int, camera: Camera3D, on_next_day: Callable, on_finish: Callable) -> void:
	if _night != null:
		return
	_night = ColorRect.new()
	_night.color = Color(0.0, 0.0, 0.0, 0.0)
	_night.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_night)
	var title := Game.make_label("Dia %d" % next_day, 36, Game.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.modulate.a = 0.0
	_night.add_child(title)
	var original_rotation := camera.rotation
	var original_position := camera.position
	_night_tween = create_tween()
	_night_tween.tween_property(_night, "color:a", 1.0, 0.55)
	_night_tween.parallel().tween_property(camera, "rotation", original_rotation + Vector3(-0.14, 0.0, 0.09), 0.5)
	_night_tween.parallel().tween_property(camera, "position", original_position + Vector3(0.0, -0.06, 0.0), 0.5)
	_night_tween.tween_property(title, "modulate:a", 1.0, 0.25)
	_night_tween.tween_interval(1.0)
	_night_tween.tween_property(title, "modulate:a", 0.0, 0.2)
	_night_tween.tween_callback(func():
		camera.rotation = original_rotation
		camera.position = original_position
		on_next_day.call())
	_night_tween.tween_property(_night, "color:a", 0.0, 0.45)
	_night_tween.tween_callback(func():
		_night.queue_free()
		_night = null
		on_finish.call())


func paused() -> bool:
	return _pause.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and minigame != null and _minigame_cancel.is_valid():
		cancel_minigame()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and not _modal.visible and _night == null:
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	_pause.visible = not _pause.visible
	get_tree().paused = _pause.visible
	if _pause.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not modal_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
