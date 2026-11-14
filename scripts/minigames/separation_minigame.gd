extends Control
## Injeção translunar (TLI) e separação do CSM do terceiro estágio S-IVB.
## Ordem inspirada na Apollo 11: o S-IVB faz a TLI e só depois o CSM se separa
## para a transposição e o acoplamento com o módulo lunar.

const STARFIELD := preload("res://scripts/ui/starfield.gd")
const START_KMS := 7.8
const MAX_KMS := 11.6
const RATE_KMS := 0.2
const SWITCHES := [
	["SEP ARM", "Armar os pirotécnicos de separação"],
	["SLA PANELS", "Abrir os painéis do adaptador (SLA)"],
	["CSM SEP", "Separar o CSM do S-IVB"],
]

var phase := "intro"
var velocity_kms := START_KMS
var target := MissionState.TLI_TARGET_KMS
var tol := 0.08
var sep_step := 0
var sep_time_left := 30.0
var _gauge: Control
var _status: Label
var _title: Label
var _body: Label
var _switch_row: HBoxContainer
var _switch_buttons: Array[Button] = []
var _checklist: Label
var _panel: PanelContainer
var _panel_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var s := MissionState.settings()
	tol = s["tli_tol"]
	sep_time_left = s["sep_time"]
	var bg := Control.new()
	bg.set_script(STARFIELD)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var console := PanelContainer.new()
	console.custom_minimum_size = Vector2(900, 480)
	center.add_child(console)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	console.add_child(box)
	_title = Game.make_label("PAINEL DE MANOBRA · INJEÇÃO TRANSLUNAR", 26, Game.AMBER)
	box.add_child(_title)
	_body = Game.make_label("", 17)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_body)
	_gauge = Control.new()
	_gauge.custom_minimum_size = Vector2(0, 110)
	_gauge.draw.connect(_draw_gauge)
	box.add_child(_gauge)
	_status = Game.make_label("", 22, Game.CREAM)
	box.add_child(_status)
	_checklist = Game.make_label("", 17)
	box.add_child(_checklist)
	_switch_row = HBoxContainer.new()
	_switch_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_switch_row.add_theme_constant_override("separation", 20)
	box.add_child(_switch_row)
	var order := [0, 1, 2]
	order.shuffle()
	for key_index in order.size():
		var switch_index: int = order[key_index]
		var button := Button.new()
		button.text = "[%d] %s" % [key_index + 1, SWITCHES[switch_index][0]]
		button.custom_minimum_size = Vector2(220, 60)
		button.pressed.connect(_on_switch.bind(switch_index))
		_switch_row.add_child(button)
		_switch_buttons.append(button)
	_switch_row.visible = false
	if MissionState.last_failure.get("stage", "") == "separation":
		_show_failure()
	else:
		_show_intro()


func _make_panel(title: String, text: String) -> void:
	if _panel:
		_panel.queue_free()
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(640, 0)
	_panel.position = Vector2(-320, -170)
	add_child(_panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 12)
	_panel.add_child(_panel_box)
	_panel_box.add_child(Game.make_label(title, 24, Game.AMBER))
	var body := Game.make_label(text, 17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_box.add_child(body)


func _panel_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(callback)
	_panel_box.add_child(button)
	button.grab_focus()


func _show_intro() -> void:
	_make_panel("PROCEDIMENTO CRÍTICO",
		"A nave está em órbita da Terra. O terceiro estágio (S-IVB) vai acelerar a nave rumo à Lua: é a injeção translunar.\n\n" +
		"1. Observe a velocidade subir. Pressione ESPAÇO quando o ponteiro estiver na faixa VERDE para desligar o motor.\n" +
		"2. Depois, acione os 3 interruptores de separação na ordem do checklist (clique ou teclas 1, 2, 3).\n\n" +
		"Um corte fora da faixa verde ainda pode funcionar, mas exige correções de rota que gastam combustível.")
	_panel_button("INICIAR MANOBRA", _start_tli)
	_body.text = "Checkpoint salvo. Em caso de falha você recomeça aqui, sem refazer o planejamento."


func _show_failure() -> void:
	var failure := MissionState.last_failure
	var text := ""
	for reason in failure.get("reasons", []):
		text += "• " + reason + "\n"
	text += "\nDica:\n"
	for tip in failure.get("tips", []):
		text += "• " + tip + "\n"
	_make_panel(failure.get("title", "FALHA"), text)
	_panel_button("REPETIR ETAPA", func():
		MissionState.last_failure = {}
		Game.retry_from_checkpoint("separation", "separation"))


func _start_tli() -> void:
	_panel.queue_free()
	_panel = null
	phase = "tli"
	_body.text = "Motor do S-IVB aceso. Tempo acelerado para o jogo (a queima real durou cerca de 6 minutos)."
	Houston.say("Apollo, Houston. You are go for TLI. Watch for cutoff.",
		"Apollo, aqui é Houston. Autorizados para a TLI. Atenção ao corte do motor.")


func _process(delta: float) -> void:
	if phase == "tli":
		velocity_kms += RATE_KMS * delta
		_status.text = "VELOCIDADE: %.2f km/s   ·   ALVO: %.2f km/s   ·   [ESPAÇO] DESLIGAR MOTOR" % [velocity_kms, target]
		if velocity_kms > target + tol * 2.5 + 0.05:
			_fail_tli(true)
		_gauge.queue_redraw()
	elif phase == "sep":
		sep_time_left -= delta
		_status.text = "JANELA DE SEPARAÇÃO: %.0f s" % maxf(sep_time_left, 0.0)
		if sep_time_left <= 0.0:
			_fail_sep()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if phase == "tli" and event.physical_keycode == KEY_SPACE:
		_cutoff()
	elif phase == "sep" and event.physical_keycode in [KEY_1, KEY_2, KEY_3]:
		var position_index: int = event.physical_keycode - KEY_1
		_switch_buttons[position_index].emit_signal("pressed")


func _cutoff() -> void:
	var delta_v := velocity_kms - target
	if delta_v < -tol * 2.5:
		_fail_tli(false)
		return
	var error := clampf(absf(delta_v) / (tol * 2.5), 0.0, 1.0)
	MissionState.trajectory_error = error
	var rating := "PRECISO" if absf(delta_v) <= tol else "ACEITÁVEL"
	_status.text = "CORTE: %.2f km/s · %s (desvio de trajetória: %.0f%%)" % [velocity_kms, rating, error * 100.0]
	if rating == "PRECISO":
		Houston.say("Good cutoff. You are on your way.", "Corte perfeito. Vocês estão a caminho.")
	else:
		Houston.say("Cutoff confirmed. We'll need a small course correction later.",
			"Corte confirmado. Vamos precisar de uma pequena correção de rota depois.")
	_start_sep()


func _start_sep() -> void:
	phase = "sep"
	sep_step = 0
	_title.text = "PAINEL DE MANOBRA · SEPARAÇÃO DO CSM"
	_body.text = "Siga o checklist. A ordem importa: os interruptores estão embaralhados no painel."
	_switch_row.visible = true
	_switch_buttons[0].grab_focus()
	_update_checklist()


func _update_checklist() -> void:
	var text := "CHECKLIST:\n"
	for i in SWITCHES.size():
		var mark := "[x]" if i < sep_step else ("[>]" if i == sep_step else "[ ]")
		text += "  %s %d. %s — %s\n" % [mark, i + 1, SWITCHES[i][0], SWITCHES[i][1]]
	_checklist.text = text


func _on_switch(index: int) -> void:
	if phase != "sep":
		return
	if index != sep_step:
		MissionState.separation_mistakes += 1
		_body.text = "Fora de ordem! %s não pode vir agora. Siga o checklist." % SWITCHES[index][0]
		return
	sep_step += 1
	_update_checklist()
	if sep_step >= SWITCHES.size():
		phase = "done"
		_status.text = "SEPARAÇÃO CONFIRMADA"
		MissionState.add_event("separation", "Injeção translunar e separação",
			"Concluída com desvio de trajetória de %.0f%% e %d erro(s) de ordem." % [MissionState.trajectory_error * 100.0, MissionState.separation_mistakes])
		Houston.say("We confirm separation. Proceed with transposition and docking.",
			"Separação confirmada. Prossigam com a transposição e o acoplamento.")
		get_tree().create_timer(3.0).timeout.connect(Game.separation_success)


func _fail_tli(too_fast: bool) -> void:
	phase = "failed"
	if too_fast:
		MissionState.set_failure("separation", "TLI ABORTADA · VELOCIDADE EXCESSIVA",
			["O motor ficou ligado tempo demais (%.2f km/s). A nave passaria longe da Lua." % velocity_kms],
			["Pressione ESPAÇO assim que o ponteiro entrar na faixa verde.", "A faixa amarela também é aceita, mas gasta combustível em correções depois."])
	else:
		MissionState.set_failure("separation", "TLI ABORTADA · CORTE PREMATURO",
			["O motor foi desligado cedo demais (%.2f km/s). A nave não teria energia para chegar à Lua." % velocity_kms],
			["Espere o ponteiro chegar à faixa verde, perto de %.2f km/s." % target])
	Game.separation_failed()


func _fail_sep() -> void:
	phase = "failed"
	MissionState.set_failure("separation", "SEPARAÇÃO NÃO CONCLUÍDA",
		["A janela de separação terminou antes de completar o checklist."],
		["Leia o checklist: o item marcado com [>] é o próximo.", "Use as teclas 1, 2 e 3 ou clique nos interruptores."])
	Game.separation_failed()


func _draw_gauge() -> void:
	var w := _gauge.size.x
	var h := 46.0
	var y := 30.0
	var to_x := func(v: float) -> float: return (v - START_KMS) / (MAX_KMS - START_KMS) * w
	_gauge.draw_rect(Rect2(0, y, w, h), Color(0.12, 0.12, 0.11))
	var yellow_a: float = to_x.call(target - tol * 2.5)
	var yellow_b: float = to_x.call(target + tol * 2.5)
	_gauge.draw_rect(Rect2(yellow_a, y, yellow_b - yellow_a, h), Color(0.55, 0.45, 0.1))
	var green_a: float = to_x.call(target - tol)
	var green_b: float = to_x.call(target + tol)
	_gauge.draw_rect(Rect2(green_a, y, green_b - green_a, h), Color(0.2, 0.65, 0.25))
	_gauge.draw_rect(Rect2(0, y, w, h), Game.AMBER.darkened(0.3), false, 2.0)
	var needle: float = to_x.call(velocity_kms)
	_gauge.draw_rect(Rect2(needle - 2, y - 14, 4, h + 28), Game.CREAM)
	var font := ThemeDB.fallback_font
	for v in [8.0, 9.0, 10.0, 11.0]:
		_gauge.draw_string(font, Vector2(to_x.call(v) - 18, y + h + 26), "%.0f km/s" % v, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.7, 0.65))
