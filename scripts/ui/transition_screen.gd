extends Control

const STARFIELD := preload("res://scripts/ui/starfield.gd")
const MIN_READ := 2.0
const TEXTS := {
	"A": {
		"title": "Órbita lunar · 4 dias e 6 horas desde o lançamento",
		"body": "• Cerca de 3 dias e 4 horas após o lançamento, a queima de inserção colocou a nave em órbita da Lua.\n• Durante quase um dia, a tripulação verificou os sistemas e preparou o módulo lunar.\n• Na Apollo 11, Armstrong e Aldrin passaram para o módulo lunar [i]Eagle[/i] e Collins ficou no [i]Columbia[/i]. No APOLLO6, Thomas Walker pilota a descida.\n• Depois da confirmação, o [i]Eagle[/i] se desacopla e começa a descida final motorizada.",
		"confirm": "COMEÇAR A DESCIDA FINAL",
		"back": "VOLTAR À CABINE",
	},
	"B": {
		"title": "Pouso lunar confirmado · 4 dias e 7 horas desde o lançamento",
		"body": "• Superfície: a tripulação passou cerca de 21 h e 36 min na Lua, saiu em atividade extraveicular, coletou amostras e instalou os instrumentos. Dados científicos registrados: [b]%s[/b].\n• Decolagem: o estágio de ascensão do [i]Eagle[/i] partiu da Lua. A base do módulo lunar ficou na superfície.\n• Reencontro: o [i]Eagle[/i] acoplou ao [i]Columbia[/i]. Tripulação e amostras passaram para o módulo de comando e o estágio de ascensão foi descartado.\n• Partida: cerca de 5 dias e 15 horas após o lançamento, o motor do módulo de serviço colocou o [i]Columbia[/i] no caminho de volta à Terra.",
		"confirm": "CONFIRMAR A PARTIDA PARA A TERRA",
		"back": "",
	},
	"C": {
		"title": "Aproximação da Terra · cerca de 8 dias desde o lançamento",
		"body": "• Quase 12 horas de voo comprimidas: a nave chega perto da Terra.\n• O módulo de serviço será separado e ficará para trás.\n• O [i]Columbia[/i], com os três astronautas, fará sozinho a reentrada e a amerissagem no Oceano Pacífico.\n• Na abertura dos paraquedas principais, você fará o acionamento manual de contingência criado para o jogo.",
		"confirm": "PREPARAR REENTRADA",
		"back": "VOLTAR À CABINE",
	},
}

var id := ""
var _title: Label
var _body: RichTextLabel
var _buttons: HBoxContainer
var _busy := false
var _wait := 0.0
var _locked: Array = []


func _ready() -> void:
	Sound.enter_scene("transition")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	id = Game.transition_id
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Control.new()
	bg.set_script(STARFIELD)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_title = Game.make_label("", 26, Game.AMBER)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.add_theme_font_size_override("normal_font_size", 17)
	_body.add_theme_font_size_override("italics_font_size", 17)
	_body.add_theme_font_size_override("bold_font_size", 17)
	box.add_child(_body)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 12)
	box.add_child(_buttons)
	if not TEXTS.has(id):
		_show_end("Etapa desconhecida.")
		return
	_show_offer()


func _process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			for b: Button in _locked:
				b.disabled = false
			if not _locked.is_empty():
				_locked[0].grab_focus()
			_locked = []


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 46)
	b.disabled = true
	b.pressed.connect(action)
	_buttons.add_child(b)
	_locked.append(b)
	return b


func _clear_buttons() -> void:
	for child in _buttons.get_children():
		child.queue_free()
	_locked = []


func _lock(seconds: float) -> void:
	_wait = seconds


func cost_text() -> String:
	var ms := MissionState
	var p := ms.jump_preview(id)
	var t := "\n[color=#f5bd5c]SUPRIMENTOS[/color]\nEste salto consome [b]1 comida e 1 água[/b].\n"
	t += "Saldo agora: [b]%s comida · %s água[/b]\n" % [ms.amount_text(ms.food_days), ms.amount_text(ms.water_days)]
	if p["ok"]:
		t += "Depois do salto: [b]%s comida · %s água[/b]\n" % [ms.amount_text(p["food_after"]), ms.amount_text(p["water_after"])]
	else:
		t += "[color=#ff8866]Saldo insuficiente para este salto.[/color]\n"
	if id == "B":
		var ok: bool = p["ok"] and p["food_after"] >= ms.DEPARTURE_RESERVE - 0.0001 and p["water_after"] >= ms.DEPARTURE_RESERVE - 0.0001
		t += "Para partir rumo à Terra, devem sobrar [b]%d de cada[/b] depois deste salto: 2 para os dias de volta e 1 para a aproximação da Terra.\n" % ms.DEPARTURE_RESERVE
		t += "[color=#77ee77]Reserva suficiente.[/color]" if ok else "[color=#ff8866]A reserva não basta para voltar.[/color]"
	return t


func _show_offer() -> void:
	var data: Dictionary = TEXTS[id]
	_title.text = data["title"]
	var body: String = data["body"]
	if id == "B":
		body = body % ("%.0f" % MissionState.science_potential())
	_body.text = body + "\n" + cost_text()
	_clear_buttons()
	if data["back"] != "":
		_button(data["back"], _go_back)
	var confirm := _button(data["confirm"], _confirm)
	_locked.erase(confirm)
	_locked.push_front(confirm)
	_lock(0.6)


func _go_back() -> void:
	if _busy:
		return
	_busy = true
	Game.go("cabin")


func _confirm() -> void:
	if _busy:
		return
	_busy = true
	var paid := Game.confirm_jump(id)
	if not paid["ok"]:
		_show_end("[color=#ff8866]%s · %s[/color]\n\nA missão termina aqui. O relatório mostra o que foi alcançado e o que faltou." % [MissionState.JUMPS[id]["title"], MissionState.jump_text(id)])
		return
	if id == "A":
		Game.start_descent()
	elif id == "B":
		if not MissionState.departure["ok"]:
			_show_end("[color=#77ee77]Pouso lunar confirmado.[/color]\n[color=#ff8866]Partida para a Terra · %s[/color]\n\nSem a reserva mínima, a volta não pode começar. A missão termina aqui." % MissionState.departure_text())
			return
		_show_day_four()
	else:
		Game.start_reentry()


func _show_day_four() -> void:
	_title.text = "Dia 4 · Volta à Terra"
	_body.text = "Primeiro dia jogável da volta.\nA Lua fica para trás e a Terra se aproxima pela janela.\n\nReserva verificada na partida: [b]%s comida · %s água[/b]." % [
		MissionState.amount_text(MissionState.departure["food"]), MissionState.amount_text(MissionState.departure["water"])]
	_clear_buttons()
	_busy = false
	_button("COMEÇAR O DIA 4", func():
		if _busy:
			return
		_busy = true
		Game.begin_return())
	_lock(MIN_READ)


func _show_end(text: String) -> void:
	_title.text = "Missão interrompida"
	_body.text = text
	_clear_buttons()
	_busy = false
	_button("VER RELATÓRIO", func():
		if _busy:
			return
		_busy = true
		Game.finish_mission())
	_lock(0.6)
