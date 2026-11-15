extends CanvasLayer
## Interface da cabine: mira, objetivo, recursos, checklist, painéis e pausa.

signal modal_closed

const NEED_COLORS := {"food": Color(0.96, 0.74, 0.36), "water": Color(0.38, 0.68, 1.0)}
const NEED_LABELS := {"food": "FOME", "water": "SEDE"}
var _needs: Control
## Valor mostrado de cada barra: acompanha o real em uma animação curta (só visual).
var _needs_shown := {"food": 100.0, "water": 100.0}
var _needs_flash := {"food": 0.0, "water": 0.0}
var _needs_clock := 0.0
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
var _note: Label
var _note_time := 0.0
var _critical: PanelContainer
var _critical_title: Label
var _critical_text: Label
var _critical_time: Label
var _critical_clock := 0.0


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
	var status_box := VBoxContainer.new()
	status_panel.add_child(status_box)
	status_box.add_child(_status)
	# FOME e SEDE: o quanto da necessidade está atendida (o estoque fica nas linhas acima).
	_needs = Control.new()
	_needs.custom_minimum_size = Vector2(260, 64)
	_needs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_needs.draw.connect(_draw_needs)
	_needs_shown = {"food": MissionState.need("food"), "water": MissionState.need("water")}
	status_box.add_child(_needs)

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
	pbox.add_child(Game.make_label(str(TranslationServer.translate("PAUSA")), 26, Game.AMBER))
	for entry in [[str(TranslationServer.translate("CONTINUAR")), toggle_pause], [str(TranslationServer.translate("MENU PRINCIPAL")), func(): Game.go("menu")], [str(TranslationServer.translate("SAIR DO JOGO")), func(): get_tree().quit()]]:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(0, 42)
		b.pressed.connect(entry[1])
		pbox.add_child(b)

	_note = Game.make_label("", 18, Game.CREAM)
	_note.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.size = Vector2(760, 30)
	_note.position = Vector2(-380, -190)
	_note.add_theme_color_override("font_outline_color", Color.BLACK)
	_note.add_theme_constant_override("outline_size", 6)
	add_child(_note)

	_critical = PanelContainer.new()
	_critical.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_critical.position = Vector2(-330, 110)
	_critical.custom_minimum_size = Vector2(660, 0)
	_critical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var critical_style := StyleBoxFlat.new()
	critical_style.bg_color = Color(0.1, 0.0, 0.0, 0.92)
	critical_style.border_color = Game.BAD
	critical_style.set_border_width_all(3)
	critical_style.set_corner_radius_all(8)
	critical_style.set_content_margin_all(16)
	_critical.add_theme_stylebox_override("panel", critical_style)
	_critical.visible = false
	add_child(_critical)
	var cbox := VBoxContainer.new()
	cbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cbox.add_theme_constant_override("separation", 6)
	_critical.add_child(cbox)
	_critical_title = Game.make_label(str(TranslationServer.translate("⚠ ESTADO CRÍTICO ⚠")), 30, Game.BAD)
	_critical_text = Game.make_label("", 19, Game.CREAM)
	_critical_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_critical_text.custom_minimum_size = Vector2(620, 0)
	_critical_time = Game.make_label("", 44, Game.BAD)
	for label: Label in [_critical_title, _critical_text, _critical_time]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		cbox.add_child(label)

	MissionState.changed.connect(refresh_status)
	refresh_status()


func show_note(text: String, seconds := 3.0) -> void:
	_note.text = text
	_note_time = seconds


func note_text() -> String:
	return _note.text if _note_time > 0.0 else ""


func _process(delta: float) -> void:
	if _note_time > 0.0:
		_note_time -= delta
		if _note_time <= 0.0:
			_note.text = ""
	_animate_needs(delta)
	_update_critical(delta)


func critical_visible() -> bool:
	return _critical.visible and _critical.modulate.a > 0.0


func critical_text() -> String:
	return _critical_text.text


func _update_critical(delta: float) -> void:
	var ms := MissionState
	if ms.need_critical.is_empty() or not ms.ended.is_empty():
		if _critical.visible:
			_critical.modulate.a = maxf(0.0, _critical.modulate.a - delta * 3.0)
			if _critical.modulate.a <= 0.0:
				_critical.visible = false
		return
	if not _critical.visible:
		_critical.visible = true
		_critical_clock = 0.0
	var left := ms.critical_seconds()
	for kind: String in ms.need_critical:
		left = minf(left, ms.critical_left(kind))
	if ms.need_critical.size() == 2:
		_critical_text.text = str(TranslationServer.translate("Você dormiu sem se alimentar.\nComa e beba água em %d SEGUNDOS ou a missão termina em GAME OVER.\nVá até a estação de comida e de água.")) % int(ms.critical_seconds())
	elif ms.need_critical.has("water"):
		_critical_text.text = str(TranslationServer.translate("Agora beba água em %d s ou a missão termina em GAME OVER.\nVá até a estação de água.")) % int(ceilf(left))
	else:
		_critical_text.text = str(TranslationServer.translate("Agora coma em %d s ou a missão termina em GAME OVER.\nVá até a estação de comida.")) % int(ceilf(left))
	_critical_time.text = "%d s" % int(ceilf(left))
	_critical_clock += delta
	var speed := 9.0 if left <= 5.0 else 4.0
	_critical.modulate.a = 1.0
	var glow := 0.5 + 0.5 * sin(_critical_clock * speed)
	_critical_title.modulate = Color(1, 1, 1, 0.55 + 0.45 * glow)
	_critical_time.modulate = Color(1, 1, 1, 0.55 + 0.45 * glow)


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
	_needs.queue_redraw()
	var lines := str(TranslationServer.translate("[color=#f5bd5c]DIA %d/%d · %s[/color]\n")) % [ms.day, ms.PLAY_DAYS, ms.phase_title()]
	lines += _line(str(TranslationServer.translate("COMIDA")), "%s cotas" % ms.amount_text(ms.food_days), not ms.can_consume("food"), ms.food_days < 3.0)
	lines += _line(str(TranslationServer.translate("ÁGUA")), "%s cotas" % ms.amount_text(ms.water_days), not ms.can_consume("water"), ms.water_days < 3.0)
	var use := ms.power_use()
	lines += _line(str(TranslationServer.translate("ENERGIA")), "%.0f/%.0f W" % [use, ms.power_capacity], use > ms.power_capacity, use > ms.power_capacity * 0.8)
	lines += _line("PROPEL. CSM", "%.0f%%" % ms.sps_fuel, ms.sps_fuel < 45, ms.sps_fuel < 70)
	lines += _line(str(TranslationServer.translate("SUPORTE VIDA")), "%.0f%%" % ms.life_support, ms.life_support < 50, ms.life_support < 85)
	lines += _line(str(TranslationServer.translate("INTEGRIDADE")), "%.0f%%" % ms.integrity, ms.integrity < 60, ms.integrity < 90)
	_status.text = lines


func _animate_needs(delta: float) -> void:
	if _needs == null:
		return
	_needs_clock += delta
	for kind: String in _needs_shown:
		var real: float = MissionState.need(kind)
		if real > _needs_shown[kind] + 1.0:
			_needs_flash[kind] = 1.0
		# Subidas animam rápido; descidas acompanham o valor real sem atraso perceptível.
		_needs_shown[kind] = lerpf(_needs_shown[kind], real, 1.0 - exp(-delta * 9.0)) if real > _needs_shown[kind] else real
		_needs_flash[kind] = maxf(0.0, _needs_flash[kind] - delta * 1.5)
	_needs.queue_redraw()


## Duas linhas: ícone, rótulo, barra, percentual e, na janela crítica, os segundos restantes.
func _draw_needs() -> void:
	var font := _needs.get_theme_default_font()
	var ms := MissionState
	for i in 2:
		var kind: String = ["food", "water"][i]
		var y := 4.0 + i * 30.0
		var value: float = ms.need(kind)
		var color: Color = NEED_COLORS[kind]
		var low := value < ms.NEED_LOW
		var critical := ms.need_critical.has(kind)
		var pulse := 0.5 + 0.5 * sin(_needs_clock * (3.0 if critical else 5.0))
		var alert := Game.BAD.lerp(Game.CREAM, pulse * 0.4)
		_draw_need_icon(kind, Vector2(8, y + 9), alert if low else color)
		_needs.draw_string(font, Vector2(20, y + 15), tr(NEED_LABELS[kind]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, alert if low else color)
		var bar := Rect2(77, y + 3, 117, 14)
		_needs.draw_rect(bar, Color(0.08, 0.08, 0.09))
		var fill := clampf(_needs_shown[kind] / ms.NEED_MAX, 0.0, 1.0)
		var bar_color := color.lerp(Color.WHITE, _needs_flash[kind] * 0.6)
		if low:
			bar_color = Game.BAD.lerp(color, pulse * 0.35)
		_needs.draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), bar_color)
		# Marca de 25%: abaixo dela o astronauta reclama.
		var mark := bar.position.x + bar.size.x * ms.NEED_LOW / ms.NEED_MAX
		_needs.draw_line(Vector2(mark, bar.position.y - 2), Vector2(mark, bar.end.y + 2), Color(1, 1, 1, 0.35), 1.0)
		_needs.draw_rect(bar, (alert if low else color.darkened(0.3)), false, 2.0 if critical else 1.0)
		var text := "<1%" if value > 0.0 and value < 1.0 else "%d%%" % int(value)
		if critical:
			text += " %.0f s" % ceilf(ms.critical_left(kind))
		_needs.draw_string(font, Vector2(200, y + 15), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, alert if low or critical else Game.CREAM)


func _draw_need_icon(kind: String, center: Vector2, color: Color) -> void:
	if kind == "food":
		# Ração: pacote com faixa.
		_needs.draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), color)
		_needs.draw_rect(Rect2(center - Vector2(6, 1), Vector2(12, 2)), Color(0.05, 0.05, 0.05))
	else:
		# Gota.
		_needs.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -8), center + Vector2(5, 1), center + Vector2(0, 7), center + Vector2(-5, 1)]), color)
		_needs.draw_circle(center + Vector2(0, 2), 5.0, color)


func _line(name: String, value: String, bad: bool, warn: bool) -> String:
	var color := "#ff5f50" if bad else ("#ffcc44" if warn else "#77ee77")
	return "%s [color=%s]%s[/color]\n" % [str(tr(name)).rpad(13), color, value]


func show_checklist(tasks: Array) -> void:
	var text := str(TranslationServer.translate("[color=#f5bd5c]CHECKLIST · DIA %d[/color]\n")) % MissionState.day
	for task in tasks:
		var done: bool = task["done"]
		var mark := "[color=#77ee77][x][/color]" if done else "[ ]"
		var optional := " (opcional)" if task.get("optional", false) else ""
		text += "%s [b]%s[/b] — %s%s\n" % [mark, tr(task["station"]), tr(task["text"]), optional]
	text += str(TranslationServer.translate("\n[color=#999]TAB fecha · F inicia tarefas na estação[/color]"))
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
		b.text = "%d. %s" % [i + 1, tr(buttons[i])] if buttons.size() > 1 else buttons[i]
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
	var title := Game.make_label(str(TranslationServer.translate("Dia %d · Volta à Terra")) % next_day if next_day >= 4 else str(TranslationServer.translate("Dia %d")) % next_day, 36, Game.CREAM)
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
	_night_tween.tween_interval(1.4)
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
