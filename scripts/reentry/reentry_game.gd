extends Control

const TARGET := 3050.0
const WINDOW := 2.0
const DROGUE_ALT := 7300.0
const DROGUE_RATE := 470.0
const MAIN_TIME := 6.0
const SEPARATION_TIME := 2.5
const ENTRY_TIME := 5.0

var phase := "intro"
var attitude := 0.65
var stable_time := 0.0
var stabilization := 0.0
var altitude := 120000.0
var phase_time := 0.0
var window_time := 0.0
var window_opened := false
var paused := false
var early_note := 0.0
var attempt := 1
var result := {}
var _view: Control
var _alt_label: Label
var _status: Label
var _hint: Label
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _pause_label: Label
var _ended := false
## Apresentação 3D (cápsula, Terra, calor, paraquedas e oceano). Só lê o estado desta cena.
var visual: Node


func _ready() -> void:
	Sound.enter_scene("reentry")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	attempt = MissionState.reentry_attempts + 1
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visual = preload("res://scripts/reentry/reentry_visual.gd").new()
	visual.name = "ReentryVisual"
	add_child(visual)
	visual.setup(self)
	_view = Control.new()
	_view.size = Vector2(960, 540)
	_view.draw.connect(_draw_view)
	add_child(_view)
	_alt_label = Game.make_label("", 34, Game.CREAM)
	_alt_label.position = Vector2(560, 20)
	_alt_label.size = Vector2(300, 44)
	_alt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_view.add_child(_alt_label)
	_status = Game.make_label("", 18, Game.AMBER)
	_status.position = Vector2(24, 18)
	_view.add_child(_status)
	_hint = Game.make_label("", 22, Game.CREAM)
	_hint.position = Vector2(24, 338)
	_hint.size = Vector2(912, 40)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_view.add_child(_hint)
	# contorno escuro: o texto continua legível sobre o céu claro e o calor da cena 3D
	for label in [_alt_label, _status, _hint]:
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.9))
		label.add_theme_constant_override("outline_size", 6)
	_pause_label = Game.make_label(str(TranslationServer.translate("PAUSADO · ESC para continuar")), 26, Game.AMBER)
	_pause_label.position = Vector2(270, 240)
	_pause_label.visible = false
	_view.add_child(_pause_label)
	_panel = PanelContainer.new()
	_panel.position = Vector2(150, 110)
	_panel.custom_minimum_size = Vector2(660, 0)
	_view.add_child(_panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_panel_box)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_show_intro()


func _fit() -> void:
	var screen := get_viewport_rect().size
	var k := minf(screen.x / 960.0, screen.y / 540.0)
	_view.scale = Vector2(k, k)
	_view.position = (screen - Vector2(960, 540) * k) / 2.0


func _show_panel(title: String, text: String, buttons: Array) -> void:
	for child in _panel_box.get_children():
		child.queue_free()
	_panel_box.add_child(Game.make_label(title, 24, Game.AMBER))
	var body := Game.make_label(text, 16)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(620, 0)
	_panel_box.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	_panel_box.add_child(row)
	var first: Button
	for entry: Array in buttons:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(220, 44)
		b.disabled = true
		b.pressed.connect(entry[1])
		row.add_child(b)
		if first == null:
			first = b
		var unlock := Timer.new()
		unlock.one_shot = true
		b.add_child(unlock)
		unlock.timeout.connect(_unlock_button.bind(b, b == first))
		unlock.start(0.5)
	_panel.visible = true


func _show_intro() -> void:
	var text := str(TranslationServer.translate("O módulo de serviço vai se separar e o Columbia entra sozinho na atmosfera, com os três astronautas.\n\n"))
	text += str(TranslationServer.translate("Os paraquedas de estabilização abrem sozinhos perto de 7.300 m (24.000 pés).\n"))
	text += str(TranslationServer.translate("Os três paraquedas principais da Apollo abriam perto de 3.050 m (10.000 pés). No jogo, você faz o acionamento manual de contingência:\n\n"))
	text += str(TranslationServer.translate("• Após os estabilizadores, use ←/→ ou A/D para manter a marca no centro. Essa preparação melhora a amerissagem.\n"))
	text += str(TranslationServer.translate("• Quando a cápsula cruzar 3.050 m, aparece ESPAÇO · ABRIR PARAQUEDAS.\n"))
	text += str(TranslationServer.translate("• Você tem 2 segundos para apertar ESPAÇO.\n"))
	text += str(TranslationServer.translate("• Apertar antes da hora não gasta a tentativa.\n\n"))
	text += str(TranslationServer.translate("Tentativa %d. O tempo da queda é comprimido para o jogo.")) % attempt
	_show_panel(str(TranslationServer.translate("REENTRADA E AMERISSAGEM")), text, [[str(TranslationServer.translate("INICIAR REENTRADA")), start]])


func start() -> void:
	if phase != "intro":
		return
	_panel.visible = false
	phase = "separation"
	attitude = 0.65
	stable_time = 0.0
	stabilization = 0.0
	phase_time = 0.0
	altitude = 120000.0
	Sound.play_cue("cutoff")
	Houston.say("Columbia, Houston. You are go for service module separation.", "Columbia, aqui é Houston. Autorizados a separar o módulo de serviço.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase in ["separation", "entry", "drogue", "window", "mains"]:
		set_paused(true)


func set_paused(value: bool) -> void:
	paused = value
	_pause_label.visible = paused
	Sound.set_motor(0.0 if paused else _rumble())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("pause") and phase in ["separation", "entry", "drogue", "window", "mains"]:
		set_paused(not paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("chute"):
		press()
		get_viewport().set_input_as_handled()


func press() -> void:
	if paused:
		return
	if phase in ["separation", "entry", "drogue"]:
		early_note = 1.5
		return
	if phase == "window" and window_time < WINDOW:
		_open_mains()


func _process(delta: float) -> void:
	if paused or delta <= 0.0:
		return
	step(delta)


func step(delta: float) -> void:
	early_note = maxf(early_note - delta, 0.0)
	phase_time += delta
	match phase:
		"separation":
			if phase_time >= SEPARATION_TIME:
				phase = "entry"
				phase_time = 0.0
				Sound.play_cue("ignition")
		"entry":
			altitude = lerpf(120000.0, DROGUE_ALT, minf(phase_time / ENTRY_TIME, 1.0))
			if phase_time >= ENTRY_TIME:
				altitude = DROGUE_ALT
				phase = "drogue"
				phase_time = 0.0
				Sound.play_cue("dock")
		"drogue":
			var available := clampf((altitude - TARGET) / DROGUE_RATE, 0.0, delta)
			var correction := Input.get_axis("tilt_left", "tilt_right")
			attitude = clampf(attitude + (correction * 1.1 + sin(phase_time * 2.5) * 0.18) * available, -1.0, 1.0)
			if absf(attitude) <= 0.22:
				stable_time += available
			stabilization = clampf(stable_time / 3.0, 0.0, 1.0)
			var before := altitude
			altitude -= DROGUE_RATE * delta
			if before > TARGET and altitude <= TARGET:
				var used := (before - TARGET) / DROGUE_RATE
				_open_window(maxf(delta - used, 0.0))
		"window":
			altitude -= DROGUE_RATE * delta
			window_time += delta
			if window_time >= WINDOW:
				_miss()
		"mains":
			altitude = maxf(altitude - result["altitude"] / lerpf(MAIN_TIME - 0.8, MAIN_TIME + 0.8, stabilization) * delta, 0.0)
			if altitude <= 0.0:
				_splash()
	Sound.set_motor(_rumble())
	_update_hud()
	_view.queue_redraw()


func _rumble() -> float:
	if phase == "entry":
		return 0.9
	if phase in ["drogue", "window"]:
		return 0.35
	return 0.0


func _open_window(already: float) -> void:
	if window_opened:
		return
	window_opened = true
	phase = "window"
	window_time = already
	Sound.play_cue("warning", "Interface", true)
	if window_time >= WINDOW:
		_miss()


func _open_mains() -> void:
	phase = "mains"
	phase_time = 0.0
	result = {"attempt": attempt, "target": TARGET, "altitude": altitude, "time": window_time, "success": true, "code": "ok"}
	result["stabilization"] = stabilization
	MissionState.reentry_result = result
	MissionState.reentry_history.append(result)
	Sound.play_cue("success", "Interface")
	Houston.say("Columbia, Houston. We see three good main chutes.", "Columbia, aqui é Houston. Vemos três paraquedas principais abertos.")


func _miss() -> void:
	if phase != "window":
		return
	phase = "failed"
	result = {"attempt": attempt, "target": TARGET, "altitude": altitude, "time": WINDOW, "success": false, "code": "window_missed"}
	MissionState.reentry_result = result
	MissionState.reentry_history.append(result)
	Sound.set_motor(0.0)
	Sound.play_cue("abort", "Voice", true)
	_show_panel(str(TranslationServer.translate("JANELA DE ABERTURA PERDIDA")),
		str(TranslationServer.translate("A cápsula passou de 3.050 m e o comando não veio nos 2 segundos da janela. Sem os paraquedas principais, o pouso na água seria violento.\n\nNa próxima tentativa, acompanhe o altímetro e aperte ESPAÇO assim que aparecer ESPAÇO · ABRIR PARAQUEDAS.\n\nO pouso lunar, os suprimentos e as decisões continuam registrados.")),
		[[str(TranslationServer.translate("TENTAR REENTRADA NOVAMENTE")), _retry], [str(TranslationServer.translate("ENCERRAR E VER RELATÓRIO")), _give_up]])


func _retry() -> void:
	if _ended:
		return
	_ended = true
	Game.retry_reentry()


func _give_up() -> void:
	if _ended:
		return
	_ended = true
	MissionState.end_mission("reentry", str(TranslationServer.translate("Janela de abertura dos paraquedas perdida.")))
	Game.finish_mission()


func _splash() -> void:
	if phase != "mains":
		return
	phase = "splash"
	phase_time = 0.0
	altitude = 0.0
	MissionState.splashdown = true
	MissionState.add_event("splashdown", "Amerissagem", str(TranslationServer.translate("Paraquedas abertos a %.0f m, %.2f s depois da abertura da janela. Contato com a água no Pacífico.")) % [result["altitude"], result["time"]])
	Sound.set_motor(0.0)
	Sound.play_cue("impact")
	Houston.say("Columbia, Houston. We have splashdown. Welcome home.", "Columbia, aqui é Houston. Amerissagem confirmada. Bem-vindos de volta.")
	_show_panel(str(TranslationServer.translate("AMERISSAGEM CONFIRMADA")),
		str(TranslationServer.translate("O Columbia tocou o Oceano Pacífico. Na Apollo 11, isso aconteceu 8 dias, 3 h e 19 min depois do lançamento.\n\nParaquedas principais abertos a %.0f m, %.2f s depois da abertura da janela.")) % [result["altitude"], result["time"]],
		[[str(TranslationServer.translate("VER RELATÓRIO")), func():
			if _ended:
				return
			_ended = true
			Game.finish_mission()]])


func _update_hud() -> void:
	_alt_label.text = "ALTITUDE %s m" % _thousands(altitude)
	var titles := {"separation": str(TranslationServer.translate("SEPARAÇÃO DO MÓDULO DE SERVIÇO")), "entry": str(TranslationServer.translate("REENTRADA · PLASMA E DESACELERAÇÃO")),
		"drogue": str(TranslationServer.translate("PARAQUEDAS DE ESTABILIZAÇÃO ABERTOS")), "window": str(TranslationServer.translate("PARAQUEDAS DE ESTABILIZAÇÃO ABERTOS")),
		"mains": str(TranslationServer.translate("PARAQUEDAS PRINCIPAIS ABERTOS")), "splash": str(TranslationServer.translate("AMERISSAGEM")), "failed": str(TranslationServer.translate("JANELA PERDIDA"))}
	_status.text = str(TranslationServer.translate("COLUMBIA · MÓDULO DE COMANDO\n")) + titles.get(phase, "")
	_hint.modulate = Game.CREAM
	if phase == "window":
		_hint.text = str(TranslationServer.translate("ESPAÇO · ABRIR PARAQUEDAS"))
		_hint.modulate = Game.WARN
	elif early_note > 0.0:
		_hint.text = "Aguarde a altitude de abertura: 3.050 m"
	elif phase == "drogue":
		_hint.text = str(TranslationServer.translate("←/→ ou A/D · Centralize a cápsula · Estabilidade %d%%")) % roundi(stabilization * 100.0)
	elif phase in ["separation", "entry"]:
		_hint.text = str(TranslationServer.translate("Aperte ESPAÇO quando a cápsula atingir 3.050 m"))
	else:
		_hint.text = ""


func _thousands(value: float) -> String:
	var n := int(roundf(value))
	var text := str(n)
	if n >= 1000:
		text = "%d.%03d" % [n / 1000, n % 1000]
	return text


func _draw_view() -> void:
	# Céu, mar, cápsula, calor e paraquedas são desenhados em 3D por reentry_visual.gd.
	# Aqui ficam só os indicadores do HUD.
	if phase == "drogue":
		var gauge := Rect2(280, 387, 400, 16)
		_view.draw_rect(gauge, Color(0.06, 0.08, 0.12, 0.9))
		_view.draw_rect(Rect2(436, 387, 88, 16), Game.GOOD.darkened(0.3))
		var cursor := Vector2(480 + 194 * attitude, 395)
		_view.draw_circle(cursor, 8, Game.CREAM)
	var bar := Rect2(880, 90, 30, 360)
	_view.draw_rect(bar, Color(0.05, 0.06, 0.06, 0.85))
	var top_alt := 9000.0
	var fill := clampf(altitude / top_alt, 0.0, 1.0)
	_view.draw_rect(Rect2(bar.position.x, bar.end.y - bar.size.y * fill, bar.size.x, bar.size.y * fill), Game.AMBER.darkened(0.2))
	var mark_y := bar.end.y - bar.size.y * TARGET / top_alt
	_view.draw_line(Vector2(860, mark_y), Vector2(920, mark_y), Game.GOOD, 3)
	_view.draw_string(get_theme_default_font(), Vector2(740, mark_y + 5), "3.050 m", HORIZONTAL_ALIGNMENT_RIGHT, 110, 16, Game.GOOD)
	_view.draw_rect(bar, Game.AMBER, false, 2)
	if phase == "window":
		var left := clampf(1.0 - window_time / WINDOW, 0.0, 1.0)
		_view.draw_rect(Rect2(230, 380, 500, 22), Color(0.05, 0.06, 0.06, 0.9))
		_view.draw_rect(Rect2(230, 380, 500 * left, 22), Game.WARN)
		_view.draw_rect(Rect2(230, 380, 500, 22), Game.CREAM, false, 2)


func _unlock_button(button: Button, focus: bool) -> void:
	if not is_instance_valid(button):
		return
	button.disabled = false
	if focus:
		button.grab_focus()
