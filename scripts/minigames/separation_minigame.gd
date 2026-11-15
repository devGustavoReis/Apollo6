extends Control
## Injeção translunar (TLI) e separação do CSM do terceiro estágio S-IVB.
## Ordem inspirada na Apollo 11: o S-IVB faz a TLI e só depois o CSM se separa
## para a transposição e o acoplamento com o módulo lunar.
##
## A nave aparece em 3D (tli_view.gd). Durante a queima o jogador mantém o nariz dentro do
## anel de orientação (WASD ou SETAS) e acompanha no mapa a trajetória prevista se esticar
## até a Lua; ESPAÇO corta o motor quando ela alcança a Lua. O desvio de trajetória soma o
## erro do corte e o da atitude e segue para a correção de rota da cabine. Depois vêm os
## alavancas, acionadas por procedimentos de teclas (QTE), e a saída da Terra rumo à Lua.
## step() avança a queima e é público para os testes.

const STARFIELD := preload("res://scripts/ui/starfield.gd")
const VIEW := preload("res://scripts/minigames/tli_view.gd")
const START_KMS := 7.8
## Velocidade de órbita circular usada no mapa: a órbita de espera.
const CIRCULAR_KMS := 7.8
## Ganho de velocidade no começo e no fim da queima, em km/s por segundo de jogo:
## o estágio acelera mais conforme gasta propelente e fica leve.
const RATE_START := 0.075
const RATE_END := 0.135
## Aceleração sentida pela tripulação, em g. Simplificação de gameplay.
const G_START := 0.7
const G_END := 1.5
const ATT_LIMIT := 15.0   ## desvio de atitude, em graus, que aborta a queima
const ATT_GOOD := 3.0
const ATT_WARN := 8.0
## Desvio médio, em graus, que ainda não custa trajetória. Aperta com a dificuldade.
const ATT_FREE := {"easy": 3.0, "normal": 2.2, "hard": 1.6}
const ATT_FULL := 8.0     ## desvio médio que custa o desvio máximo
const STEER_RATE := 9.0   ## graus por segundo com o comando no batente
const DRIFT := {"easy": 2.6, "normal": 4.0, "hard": 5.6}
const SILENCE := 2.5      ## segundos entre o corte e o início da janela de separação
const COUNTDOWN := 5.0
const FLIGHT_DELAY := 2.8 ## separação na tela antes do voo até a Lua
const AUTO_ADVANCE := 4.0 ## telemetria na tela antes de seguir sozinho
const ABORT_DELAY := 1.4
const INCIDENTS := ["alarm", "pogo", "static"]
const SWITCHES := [
	["SECS LOGIC", "Ligar a lógica dos eventos de separação"],
	["PYRO ARM", "Armar os pirotécnicos"],
	["CSM/LV SEP", "Separar o CSM do S-IVB"],
]
## Procedimento de cada alavanca, na ordem do checklist: [passo, tecla, "tap" ou "hold"].
## "hold" pede segurar a tecla até a barra encher.
const PROCEDURES := [
	[["LÓGICA 1", KEY_Q, "tap"], ["LÓGICA 2", KEY_W, "tap"], ["BARRA A", KEY_A, "tap"], ["BARRA B", KEY_S, "tap"]],
	[["TAMPA", KEY_E, "tap"], ["PIRO A", KEY_D, "tap"], ["PIRO B", KEY_F, "tap"], ["ARMAR", KEY_R, "hold"]],
	[["GUARDA", KEY_G, "tap"], ["ARMAR", KEY_H, "tap"], ["CONTAGEM", KEY_J, "tap"], ["SEPARAR", KEY_K, "hold"]],
]
## Tempo de cada passo do procedimento, em segundos, por dificuldade.
const QTE_TIME := {"easy": 2.6, "normal": 2.0, "hard": 1.5}
const HOLD_TIME := 0.9
const BANNER_BEEP := 0.45
## Cor da manopla de cada alavanca, na ordem do checklist.
const KNOB_COLORS := [Color(0.82, 0.83, 0.86), Color(0.96, 0.74, 0.36), Color(0.9, 0.3, 0.24)]
const LAMP_SIZE := Vector2(122, 24)
const ALARM_LAMP := Rect2(260, 0, 122, 24)
const MAP_SIZE := Vector2(320, 200)
const MAP_EARTH := Vector2(56, 128)
const MAP_MOON := Vector2(284, 60)
const MAP_PARK := 19.0
const CLUSTER_SIZE := Vector2(540, 132)

var phase := "intro"
var velocity_kms := START_KMS
var target := MissionState.TLI_TARGET_KMS
var tol := 0.08
var sep_step := 0
var sep_time_left := 30.0
## Sorteios da queima. Os testes fixam a semente antes de _start_tli().
var rng := RandomNumberGenerator.new()
## Desvio da direção da queima, em graus (x = guinada, y = arfagem).
var attitude := Vector2.ZERO
var burn_time := 0.0
var deviation_sum := 0.0
var cut_error := 0.0
## Imprevisto em andamento: "", "alarm", "pogo" ou "static".
var incident := ""
var incident_kind := ""
var incident_at := 0.5
var incident_time := 0.0
var incident_done := false
## Procedimento em andamento: índice da alavanca no checklist (-1 = nenhum), passo atual,
## tempo restante do passo e progresso de uma tecla segurada.
var qte_index := -1
var qte_step := 0
var qte_time_left := 0.0
var qte_hold := 0.0
var qte_holding := false
## Posição de cada alavanca no painel, de 0 (desligada) a 1 (acionada), pela posição.
var lever: Array[float] = [0.0, 0.0, 0.0]
var _lever_target: Array[float] = [0.0, 0.0, 0.0]
var _cell_error: Array[float] = [0.0, 0.0, 0.0]
var _qte_error := 0.0
var _qte_done_time := 0.0
var _qte_done_name := ""
## Aviso grande depois de um erro ("TECLA ERRADA!", "TEMPO ESGOTADO!", "ALAVANCA ERRADA!").
var _qte_alert := ""
## Afundamento curto da tecla desenhada quando o jogador acerta.
var _key_bounce := 0.0
var _sep_window := 30.0
var _order: Array = [0, 1, 2]
var _drift := Vector2.ZERO
var _drift_goal := Vector2.ZERO
var _drift_timer := 0.0
var _steer_rate := Vector2.ZERO
var _countdown := 0.0
var _silence := 0.0
var _cut_line := ""
var _clock := 0.0
var _kick := Vector2.ZERO
var _beep := 0.0
var _called := {}
var _go_said := false
var _finished := false
var _telemetry_shown := false
var _final_aim := 0.0
var _view: Node3D
var _hud: Control
var _alarm_flash: ColorRect
var _lamps: Control
var _map: Control
var _map_panel: PanelContainer
var _cluster: Control
var _cluster_panel: PanelContainer
var _switch_panel: PanelContainer
var _flight_box: VBoxContainer
var _flight_label: Label
var _clock_label: Label
var _status: Label
var _title: Label
var _body: Label
var _switch_row: HBoxContainer
var _switch_buttons: Array[Button] = []
var _checklist: Label
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _flight_timer: Timer
var _advance_timer: Timer
var _qte_panel: PanelContainer
var _qte: Control
var _banner: PanelContainer
var _banner_label: Label
var _banner_style: StyleBoxFlat
var _banner_state := ""
var _banner_beep := 0.0
var _cut_feedback := 0.0
var _cut_text := ""
var _cut_color := Color.WHITE
var _flash_rect: ColorRect


func _ready() -> void:
	Sound.enter_scene("separation")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var s := MissionState.settings()
	tol = s["tli_tol"]
	sep_time_left = s["sep_time"]
	_sep_window = sep_time_left
	rng.randomize()
	var bg := Control.new()
	bg.set_script(STARFIELD)
	add_child(bg)
	_build_world()
	_alarm_flash = ColorRect.new()
	_alarm_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_alarm_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alarm_flash.color = Color(0.8, 0.05, 0.03, 0.0)
	add_child(_alarm_flash)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(0.4, 1.0, 0.5, 0.0)
	add_child(_flash_rect)
	# Tudo que treme com o motor fica dentro de _hud.
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_build_info()
	_build_map_panel()
	_build_cluster()
	_build_switches()
	_build_qte()
	_build_banner()
	_build_flight_caption()
	_flight_timer = _timer(FLIGHT_DELAY, _start_flight)
	_advance_timer = _timer(AUTO_ADVANCE, _advance)
	_update_checklist()
	if MissionState.last_failure.get("stage", "") == "separation":
		_show_failure()
	else:
		_show_intro()


# ---------- Montagem da tela ----------

func _build_world() -> void:
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = 2
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var world := SubViewport.new()
	world.transparent_bg = true
	world.handle_input_locally = false
	container.add_child(world)
	_view = Node3D.new()
	_view.set_script(VIEW)
	world.add_child(_view)
	_view.flight_finished.connect(_show_telemetry)


func _style(alpha := 0.82) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.04, 0.045, alpha)
	box.border_color = Game.AMBER.darkened(0.25)
	box.set_border_width_all(2)
	box.set_content_margin_all(10)
	return box


func _timer(seconds: float, callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = seconds
	timer.timeout.connect(callback)
	add_child(timer)
	return timer


func _build_info() -> void:
	var info := PanelContainer.new()
	info.position = Vector2(16, 16)
	info.custom_minimum_size = Vector2(560, 0)
	info.add_theme_stylebox_override("panel", _style())
	_hud.add_child(info)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	info.add_child(box)
	_title = Game.make_label(str(TranslationServer.translate("PAINEL DE MANOBRA · INJEÇÃO TRANSLUNAR")), 21, Game.AMBER)
	box.add_child(_title)
	_lamps = Control.new()
	_lamps.custom_minimum_size = Vector2(LAMP_SIZE.x * 4 + 24, LAMP_SIZE.y)
	_lamps.draw.connect(_draw_lamps)
	_lamps.gui_input.connect(_on_lamps_input)
	box.add_child(_lamps)
	_body = Game.make_label("", 15)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(536, 0)
	box.add_child(_body)
	_status = Game.make_label("", 19, Game.CREAM)
	box.add_child(_status)
	_checklist = Game.make_label("", 15)
	box.add_child(_checklist)


func _build_map_panel() -> void:
	_map_panel = PanelContainer.new()
	_map_panel.anchor_left = 1.0
	_map_panel.anchor_right = 1.0
	_map_panel.offset_left = -MAP_SIZE.x - 36
	_map_panel.offset_right = -16
	_map_panel.offset_top = 16
	_map_panel.add_theme_stylebox_override("panel", _style())
	_hud.add_child(_map_panel)
	var box := VBoxContainer.new()
	_map_panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Game.make_label(str(TranslationServer.translate("TRAJETÓRIA PREVISTA")), 14, Game.AMBER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_clock_label = Game.make_label("T+ 00:00", 14, Game.CREAM)
	head.add_child(_clock_label)
	_map = Control.new()
	_map.custom_minimum_size = MAP_SIZE
	_map.draw.connect(_draw_map)
	box.add_child(_map)


func _build_cluster() -> void:
	_cluster_panel = PanelContainer.new()
	_cluster_panel.anchor_top = 1.0
	_cluster_panel.anchor_bottom = 1.0
	_cluster_panel.offset_left = 16
	_cluster_panel.offset_top = -CLUSTER_SIZE.y - 170
	_cluster_panel.offset_bottom = -150
	_cluster_panel.add_theme_stylebox_override("panel", _style())
	_hud.add_child(_cluster_panel)
	_cluster = Control.new()
	_cluster.custom_minimum_size = CLUSTER_SIZE
	_cluster.draw.connect(_draw_cluster)
	_cluster_panel.add_child(_cluster)


func _build_switches() -> void:
	_switch_panel = PanelContainer.new()
	_switch_panel.anchor_left = 1.0
	_switch_panel.anchor_right = 1.0
	_switch_panel.anchor_top = 1.0
	_switch_panel.anchor_bottom = 1.0
	_switch_panel.offset_left = -500
	_switch_panel.offset_right = -16
	_switch_panel.offset_top = -CLUSTER_SIZE.y - 170
	_switch_panel.offset_bottom = -150
	_switch_panel.add_theme_stylebox_override("panel", _style())
	_hud.add_child(_switch_panel)
	_switch_row = HBoxContainer.new()
	_switch_row.add_theme_constant_override("separation", 8)
	_switch_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_switch_panel.add_child(_switch_row)
	_order.shuffle()
	for position_index in _order.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, CLUSTER_SIZE.y)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		# Sem foco de teclado: ESPAÇO é a tecla do corte da TLI, e um segundo toque
		# acionaria o interruptor focado. Os interruptores usam as teclas 1-3 ou o mouse.
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_press_switch.bind(position_index))
		button.draw.connect(_draw_switch.bind(button, position_index))
		_switch_row.add_child(button)
		_switch_buttons.append(button)


## Faixa do procedimento, logo acima das alavancas: as teclas aparecem como teclas do painel.
func _build_qte() -> void:
	_qte_panel = PanelContainer.new()
	# Ocupa a coluna da direita, logo acima das alavancas, no lugar do mapa.
	_qte_panel.anchor_left = 1.0
	_qte_panel.anchor_right = 1.0
	_qte_panel.offset_left = -500
	_qte_panel.offset_right = -16
	_qte_panel.offset_top = 16
	_qte_panel.add_theme_stylebox_override("panel", _style(0.94))
	_qte_panel.visible = false
	_hud.add_child(_qte_panel)
	_qte = Control.new()
	_qte.custom_minimum_size = Vector2(464, 370)
	_qte.draw.connect(_draw_qte)
	_qte_panel.add_child(_qte)


## Alerta central do corte: aparece quando a trajetória chega à Lua.
func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_left = -330
	_banner.offset_right = 330
	_banner.offset_top = 186
	_banner.offset_bottom = 246
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_style = _style(0.92)
	_banner_style.set_border_width_all(3)
	_banner.add_theme_stylebox_override("panel", _banner_style)
	_banner.visible = false
	add_child(_banner)
	_banner_label = Game.make_label("", 22, Game.GOOD)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner_label.add_theme_constant_override("outline_size", 6)
	_banner.add_child(_banner_label)


func _build_flight_caption() -> void:
	_flight_box = VBoxContainer.new()
	_flight_box.anchor_left = 0.5
	_flight_box.anchor_right = 0.5
	_flight_box.offset_left = -360
	_flight_box.offset_right = 360
	_flight_box.offset_top = 24
	_flight_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flight_box.visible = false
	add_child(_flight_box)
	var title := Game.make_label(str(TranslationServer.translate("INJEÇÃO TRANSLUNAR CONCLUÍDA · RUMO À LUA")), 22, Game.AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	_flight_box.add_child(title)
	_flight_label = Game.make_label("", 17, Game.CREAM)
	_flight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flight_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_flight_label.add_theme_constant_override("outline_size", 6)
	_flight_box.add_child(_flight_label)


func _make_panel(title: String, text: String) -> void:
	if _panel:
		_panel.queue_free()
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(640, 0)
	_panel.position = Vector2(-320, -200)
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
	_make_panel(str(TranslationServer.translate("PROCEDIMENTO CRÍTICO")),
		str(TranslationServer.translate("A nave está em órbita da Terra. O terceiro estágio (S-IVB) vai acelerar a nave rumo à Lua: é a injeção translunar.\n\n")) +
		str(TranslationServer.translate("1. Durante a queima, mantenha o nariz da nave dentro do ANEL VERDE com WASD ou SETAS: o empuxo precisa apontar na direção certa.\n")) +
		str(TranslationServer.translate("2. Acompanhe a TRAJETÓRIA PREVISTA: ela se estica conforme a nave acelera. Quando ela alcançar a Lua com o nariz no anel, o painel avisa ALINHAMENTO CONFIRMADO: pressione ESPAÇO.\n")) +
		str(TranslationServer.translate("3. Depois do corte, escolha cada alavanca na ordem do checklist (teclas 1, 2, 3 ou clique) e execute o procedimento: pressione as teclas mostradas no painel antes de o tempo de cada passo acabar.\n\n")) +
		str(TranslationServer.translate("Um corte fora do ponto ou o nariz longe do anel ainda podem funcionar, mas exigem correções de rota que gastam combustível.")))
	_panel_button(str(TranslationServer.translate("ARMAR IGNIÇÃO")), _begin_countdown)
	_body.text = str(TranslationServer.translate("Checkpoint salvo. Em caso de falha você recomeça aqui, sem refazer o planejamento."))


func _show_failure() -> void:
	var failure := MissionState.last_failure
	var text := ""
	for reason in failure.get("reasons", []):
		text += "• " + reason + "\n"
	text += str(TranslationServer.translate("\nDica:\n"))
	for tip in failure.get("tips", []):
		text += "• " + tip + "\n"
	_make_panel(failure.get("title", str(TranslationServer.translate("FALHA"))), text)
	_panel_button(str(TranslationServer.translate("REPETIR ETAPA")), func():
		MissionState.last_failure = {}
		Game.retry_from_checkpoint("separation", "separation"))


# ---------- Contagem e queima ----------

func _begin_countdown() -> void:
	_panel.queue_free()
	_panel = null
	phase = "countdown"
	_countdown = COUNTDOWN
	_go_said = true
	_view.show_guide = true
	_body.text = str(TranslationServer.translate("Sistemas armados. Mãos nos controles: WASD ou SETAS mantêm o nariz no anel, ESPAÇO corta o motor."))
	Houston.say_recorded("go_for_tli", "Apollo, Houston. You are go for TLI. Watch for cutoff.",
		str(TranslationServer.translate("Apollo, aqui é Houston. Autorizados para a TLI. Atenção ao corte do motor.")))


func _start_tli() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	phase = "tli"
	incident_kind = INCIDENTS[rng.randi() % INCIDENTS.size()]
	incident_at = rng.randf_range(0.35, 0.62)
	_drift_timer = 0.0
	_kick = Vector2(0, 12)
	_view.show_guide = true
	_view.ignite()
	Sound.play_cue("ignition")
	Sound.set_motor(0.6)
	_body.text = str(TranslationServer.translate("Motor do S-IVB aceso. Tempo acelerado para o jogo (a queima real durou cerca de 6 minutos)."))
	if not _go_said:
		_go_said = true
		Houston.say_recorded("go_for_tli", "Apollo, Houston. You are go for TLI. Watch for cutoff.",
			str(TranslationServer.translate("Apollo, aqui é Houston. Autorizados para a TLI. Atenção ao corte do motor.")))


## Fração da queima concluída: 0 na ignição, 1 na velocidade alvo.
func progress() -> float:
	return (velocity_kms - START_KMS) / (target - START_KMS)


func mean_deviation() -> float:
	return deviation_sum / burn_time if burn_time > 0.0 else 0.0


## Parte do desvio de trajetória que vem da atitude, de 0 a 1.
func attitude_error() -> float:
	var free: float = ATT_FREE.get(MissionState.difficulty, 2.2)
	return clampf((mean_deviation() - free) / (ATT_FULL - free), 0.0, 1.0)


## Razão apogeu/perigeu de uma queima no perigeu da órbita circular: q / (2 - q), q = (v/vc)².
func _apogee_ratio(v: float) -> float:
	var q := (v / CIRCULAR_KMS) * (v / CIRCULAR_KMS)
	return q / maxf(2.0 - q, 0.0001)


## Apogeu previsto: 0 na órbita de espera, 1 na distância da Lua. Acima de 2, escape.
func apogee_fraction() -> float:
	return (_apogee_ratio(velocity_kms) - 1.0) / (_apogee_ratio(target) - 1.0)


## Avança a queima. `steer` é o comando de atitude, de -1 a 1 em cada eixo.
func step(delta: float, steer: Vector2) -> void:
	if phase != "tli" or delta <= 0.0:
		return
	burn_time += delta
	var done := clampf(progress(), 0.0, 1.0)
	velocity_kms += lerpf(RATE_START, RATE_END, done) * delta
	_update_incident(delta)
	# A deriva muda de direção a cada poucos segundos, como as perturbações do empuxo.
	_drift_timer -= delta
	if _drift_timer <= 0.0:
		_drift_timer = rng.randf_range(1.6, 3.0)
		_drift_goal = Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(0.5, 1.0)
	_drift = _drift.lerp(_drift_goal, 1.0 - exp(-delta * 1.5))
	var strength: float = DRIFT.get(MissionState.difficulty, 4.0) * (1.5 if incident == "alarm" else 1.0)
	_steer_rate = _steer_rate.lerp(steer.limit_length(1.0) * STEER_RATE, 1.0 - exp(-delta * 9.0))
	attitude += (_drift * strength + _steer_rate) * delta
	if incident == "pogo":
		attitude += Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * 5.0 * sqrt(delta)
	deviation_sum += attitude.length() * delta
	Sound.set_motor(lerpf(0.6, 1.0, done))
	_callouts()
	if attitude.length() >= ATT_LIMIT:
		_fail_attitude()
	elif velocity_kms > target + tol * 2.5 + 0.05:
		_fail_tli(true)


## Um imprevisto por queima, sorteado na ignição.
func _update_incident(delta: float) -> void:
	if incident == "" and not incident_done and progress() >= incident_at:
		incident = incident_kind
		incident_time = 3.5 if incident == "pogo" else 4.0
		_beep = 0.0
		match incident:
			"alarm":
				_body.text = str(TranslationServer.translate("MASTER ALARM! Pressione R ou clique na luz para silenciar. Enquanto ele toca, a nave deriva mais."))
			"pogo":
				Sound.play_cue("warning", "Voice", true)
				_body.text = str(TranslationServer.translate("Oscilação do motor! Segure o nariz no anel: ela passa em alguns segundos."))
			"static":
				Sound.play_cue("radio")
				_body.text = str(TranslationServer.translate("Ruído na telemetria: o mapa e o mostrador digital falham. Confie no ponteiro de velocidade."))
				Houston.say("...llo, Hous... ...ading you bro... stand b...",
					str(TranslationServer.translate("...lo, aqui é Hous... sinal ...ortado... aguard...")))
	elif incident == "alarm":
		_beep -= delta
		if _beep <= 0.0:
			_beep = 0.9
			Sound.play_cue("warning", "Voice", true)
	elif incident != "":
		incident_time -= delta
		if incident_time <= 0.0:
			_end_incident()


func _end_incident() -> void:
	incident = ""
	incident_done = true
	if phase == "tli":
		_body.text = str(TranslationServer.translate("Motor do S-IVB aceso. Tempo acelerado para o jogo (a queima real durou cerca de 6 minutos)."))


func _reset_alarm() -> void:
	if incident == "alarm":
		Sound.play_cue("switch")
		_end_incident()


func _callouts() -> void:
	if progress() >= 0.4 and not _called.has("thrust") and incident != "static":
		_called["thrust"] = true
		Houston.say("Apollo, Houston. Thrust is good. You are looking good.",
			str(TranslationServer.translate("Apollo, aqui é Houston. Empuxo normal. Tudo certo por aqui.")))
	if velocity_kms >= target - 0.5 and not _called.has("standby"):
		_called["standby"] = true
		Houston.say("Stand by for cutoff.", "Preparar para o corte do motor.")


func _guidance_color() -> Color:
	var deviation := attitude.length()
	return Game.GOOD if deviation < ATT_GOOD else (Game.WARN if deviation < ATT_WARN else Game.BAD)


func _process(delta: float) -> void:
	_clock += delta
	if phase == "countdown":
		var before := ceili(_countdown)
		_countdown -= delta
		if ceili(_countdown) != before and _countdown > 0.0:
			Sound.play_cue("switch")
		_status.text = str(TranslationServer.translate("IGNIÇÃO EM %d")) % maxi(ceili(_countdown), 0)
		if _countdown <= 0.0:
			_start_tli()
	elif phase == "tli":
		var steer := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		steer += Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		step(delta, steer)
		if phase == "tli":
			_status.text = str(TranslationServer.translate("[WASD/SETAS] NARIZ NO ANEL   ·   [ESPAÇO] CORTE"))
			if velocity_kms >= target - tol * 2.5:
				_status.text = str(TranslationServer.translate("NA JANELA · [ESPAÇO] DESLIGAR MOTOR"))
	elif phase == "sep":
		if _silence > 0.0:
			_silence -= delta
			if _silence <= 0.0:
				_say_cut_line()
		else:
			sep_time_left -= delta
		_update_qte(delta)
		_status.text = str(TranslationServer.translate("JANELA DE SEPARAÇÃO: %.0f s")) % maxf(sep_time_left, 0.0)
		if sep_time_left <= 0.0 and phase == "sep":
			_fail_sep()
	_animate_levers(delta)
	_update_banner(delta)
	_flash_rect.color.a = lerpf(_flash_rect.color.a, 0.0, 1.0 - exp(-delta * 4.0))
	_feed_view()
	_shake(delta)
	if phase == "countdown":
		_clock_label.text = "T- 00:%02d" % maxi(ceili(_countdown), 0)
	else:
		_clock_label.text = "T+ %02d:%02d" % [int(burn_time) / 60, int(burn_time) % 60]
	var alarm_alpha := 0.16 if incident == "alarm" and fmod(_clock, 0.9) < 0.3 else 0.0
	_alarm_flash.color.a = lerpf(_alarm_flash.color.a, alarm_alpha, 1.0 - exp(-delta * 18.0))
	if _flight_box.visible:
		_flight_label.text = _flight_caption(_view.flight_progress())
	_lamps.queue_redraw()
	_map.queue_redraw()
	_cluster.queue_redraw()
	_qte.queue_redraw()
	for button in _switch_buttons:
		button.queue_redraw()


## Legenda do voo: as primeiras horas da travessia e a linha do tempo até a Lua.
func _flight_caption(u: float) -> String:
	var share: float = VIEW.FLIGHT_REACH * (1.0 - pow(1.0 - u, 1.6))
	var hours := 3.0 * u
	var km := int(6556.0 + 377844.0 * share)
	var cells := 24
	var filled := clampi(int(round(share * cells)), 1, cells)
	var line := str(TranslationServer.translate("TERRA ")) + "━".repeat(filled) + "▶" + "┄".repeat(cells - filled) + str(TranslationServer.translate(" LUA"))
	return str(TranslationServer.translate("T+ %d h %02d min · %s km da Terra\n%s\nChegada à órbita lunar em cerca de 3 dias · [ESPAÇO] pular")) % [
		int(hours), int(fmod(hours, 1.0) * 60.0), _thousands(km), line]


## Alerta central do corte. Muda conforme o estado da manobra e some sozinho fora da janela.
func _update_banner(delta: float) -> void:
	var state := ""
	if phase == "tli":
		var delta_v := velocity_kms - target
		if absf(delta_v) <= tol:
			state = "go" if attitude.length() < ATT_GOOD else "steer"
		elif delta_v > tol:
			state = "late"
		elif delta_v >= -tol * 2.5:
			state = "soon"
	if _cut_feedback > 0.0:
		state = "cut"
		_cut_feedback = maxf(0.0, _cut_feedback - delta / 1.6)
	if state != _banner_state:
		_banner_state = state
		_banner_beep = 0.0
		if state == "go":
			Sound.play_cue("confirm")
			_banner_beep = BANNER_BEEP
	_banner.visible = state != ""
	if state == "":
		return
	var blink := fmod(_clock, 0.4) < 0.2
	var text := ""
	var color := Game.CREAM
	var pulse := 1.0
	match state:
		"go":
			text = str(TranslationServer.translate("ALINHAMENTO CONFIRMADO — PRESSIONE ESPAÇO!"))
			color = Game.GOOD if blink else Game.CREAM
			pulse = 1.0 + 0.045 * sin(_clock * 14.0)
			_banner_beep -= delta
			if _banner_beep <= 0.0:
				_banner_beep = BANNER_BEEP
				Sound.play_cue("add")
		"steer":
			text = str(TranslationServer.translate("TRAJETÓRIA NA LUA — VOLTE O NARIZ AO ANEL!"))
			color = Game.WARN
		"late":
			text = str(TranslationServer.translate("PASSOU DO PONTO — CORTE JÁ!"))
			color = Game.BAD if blink else Game.WARN
			pulse = 1.0 + 0.03 * sin(_clock * 22.0)
		"soon":
			text = str(TranslationServer.translate("QUASE LÁ · AGUARDE A TRAJETÓRIA FICAR VERDE"))
			color = Game.AMBER.darkened(0.15)
		"cut":
			text = _cut_text
			color = _cut_color
			pulse = 1.0 + 0.22 * _cut_feedback * _cut_feedback
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", color)
	_banner_style.border_color = color
	_banner_style.bg_color = Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.92)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2.ONE * pulse
	_banner.modulate.a = clampf(_cut_feedback * 2.0, 0.0, 1.0) if state == "cut" else 1.0


func _feed_view() -> void:
	_view.attitude = attitude
	_view.guidance_color = _guidance_color()
	_view.thrust = lerpf(0.6, 1.0, clampf(progress(), 0.0, 1.0)) if phase == "tli" else 0.0
	_view.pogo = incident == "pogo"
	var amplitude := 0.0
	if phase == "tli":
		amplitude = 1.0 + 2.2 * clampf(progress(), 0.0, 1.0) + (5.0 if incident == "pogo" else 0.0)
	_view.shake = amplitude if Game.screen_shake else 0.0


## Vibração dos instrumentos: tremor do motor, trancos e a flutuação lenta depois do corte.
func _shake(delta: float) -> void:
	var amplitude := 0.0
	if phase == "tli":
		amplitude = 0.6 + 1.2 * clampf(progress(), 0.0, 1.0) + (3.0 if incident == "pogo" else 0.0)
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-delta * (2.2 if phase in ["sep", "done"] else 6.0)))
	var offset := Vector2(sin(_clock * 41.0) + sin(_clock * 67.3), cos(_clock * 53.7) + sin(_clock * 79.1)) * 0.5 * amplitude + _kick * 0.6
	if phase in ["sep", "done"]:
		offset.y += sin(_clock * 0.9) * 1.5
	_hud.position = offset.round() if Game.screen_shake else Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	var key: int = event.physical_keycode
	if not event.pressed:
		if phase == "sep":
			qte_key(key, false)
		return
	if phase == "tli" and key == KEY_SPACE:
		_cutoff()
	elif phase == "tli" and key == KEY_R:
		_reset_alarm()
	elif phase == "sep" and key in [KEY_1, KEY_2, KEY_3]:
		_switch_buttons[key - KEY_1].emit_signal("pressed")
	elif phase == "sep":
		qte_key(key, true)
	elif phase == "done" and _flight_box.visible and key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		skip_flight()


func _gui_input(event: InputEvent) -> void:
	if phase == "done" and _flight_box.visible and event is InputEventMouseButton and event.pressed:
		skip_flight()


func _on_lamps_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and ALARM_LAMP.has_point(event.position):
		_reset_alarm()


func _cutoff() -> void:
	if phase != "tli":
		return
	var delta_v := velocity_kms - target
	if delta_v < -tol * 2.5:
		_fail_tli(false)
		return
	cut_error = clampf(absf(delta_v) / (tol * 2.5), 0.0, 1.0)
	MissionState.trajectory_error = clampf(cut_error + attitude_error(), 0.0, 1.0)
	_final_aim = deg_to_rad(attitude.x * 2.0)
	_cut_line = "precise" if absf(delta_v) <= tol and attitude_error() < MissionDecisions.SMALL_ERROR else "correction"
	# Resposta imediata ao ESPAÇO: o alerta vira a confirmação, a tela pisca e soa o sinal.
	var aligned := absf(delta_v) <= tol and attitude.length() < ATT_GOOD
	_cut_feedback = 1.0
	_cut_text = str(TranslationServer.translate("CORTE CONFIRMADO — MOTOR DESLIGADO")) if aligned else str(TranslationServer.translate("CORTE ACEITO — CORREÇÃO DE ROTA DEPOIS"))
	_cut_color = Game.GOOD if aligned else Game.WARN
	_flash_rect.color = Color(_cut_color.r, _cut_color.g, _cut_color.b, 0.28)
	Sound.play_cue("confirm")
	_start_sep()


func _say_cut_line() -> void:
	if _cut_line == "precise":
		Houston.say_recorded("cutoff_precise", "Good cutoff. You are on your way.", "Corte perfeito. Vocês estão a caminho.")
	else:
		Houston.say_recorded("cutoff_correction", "Cutoff confirmed. We'll need a small course correction later.",
			str(TranslationServer.translate("Corte confirmado. Vamos precisar de uma pequena correção de rota depois.")))


# ---------- Separação ----------

func _start_sep() -> void:
	Sound.end_maneuver()
	Sound.play_cue("cutoff")
	Houston.clear()
	phase = "sep"
	sep_step = 0
	incident = ""
	_silence = SILENCE
	_kick = Vector2(0, -14)
	_view.cutoff()
	# Na separação só importam as instruções e as alavancas: o resto sai da tela.
	_map_panel.visible = false
	_cluster_panel.visible = false
	_title.text = str(TranslationServer.translate("PAINEL DE MANOBRA · SEPARAÇÃO DO CSM"))
	_body.text = str(TranslationServer.translate("Motor desligado. Siga as instruções grandes à direita para acionar as três alavancas."))
	_update_checklist()


func _update_checklist() -> void:
	var text := str(TranslationServer.translate("CHECKLIST DE SEPARAÇÃO\n"))
	for i in SWITCHES.size():
		var mark := "[x]" if i < sep_step else ("[>]" if i == sep_step and phase == "sep" else "[ ]")
		text += " %s %d. %s\n" % [mark, i + 1, SWITCHES[i][0]]
	if phase == "sep" and sep_step < SWITCHES.size():
		text += " → %s" % str(TranslationServer.translate(SWITCHES[sep_step][1]))
	_checklist.text = text
	_checklist.visible = phase in ["sep", "done"]
	for button in _switch_buttons:
		button.queue_redraw()


func _qte_time() -> float:
	return QTE_TIME.get(MissionState.difficulty, 2.0)


## Tecla 1-3 ou clique em uma alavanca: começa o procedimento dela, se for o próximo item.
func _press_switch(position_index: int) -> void:
	if phase != "sep" or qte_index >= 0:
		return
	var index: int = _order[position_index]
	if index < sep_step:
		return
	if index != sep_step:
		Sound.play_cue("warning", "Voice", true)
		MissionState.separation_mistakes += 1
		_cell_error[position_index] = 1.0
		_qte_error = 1.0
		_qte_alert = str(TranslationServer.translate("ALAVANCA ERRADA!"))
		_kick = Vector2(rng.randf_range(-5.0, 5.0), 5.0)
		_body.text = str(TranslationServer.translate("Fora de ordem! %s não pode vir agora. Siga o checklist: o próximo é %s.")) % [SWITCHES[index][0], SWITCHES[sep_step][0]]
		return
	qte_index = index
	_key_bounce = 0.14
	qte_step = 0
	qte_hold = 0.0
	qte_holding = false
	# O primeiro passo ganha um respiro para o jogador achar a tecla.
	qte_time_left = _qte_time() + 0.6
	_lever_target[position_index] = 0.08
	Sound.play_cue("switch")
	_body.text = str(TranslationServer.translate("Procedimento %s: siga as teclas grandes à direita.")) % SWITCHES[index][0]


## Perder o foco no meio de um "segurar" não pode completar o passo sozinho: zera a barra.
var _focus_paused := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and qte_holding:
		qte_holding = false
		qte_hold = 0.0
		if is_instance_valid(_body):
			_body.text = str(TranslationServer.translate("Janela fora de foco: segure a tecla de novo até a barra encher."))
	# Fora de foco, a queima, a deriva e as janelas do QTE congelam até o foco voltar.
	if not is_inside_tree():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase in ["countdown", "tli", "sep"] and not get_tree().paused:
		_focus_paused = true
		get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and _focus_paused:
		_focus_paused = false
		get_tree().paused = false


func _exit_tree() -> void:
	if _focus_paused:
		get_tree().paused = false


## Tecla durante um procedimento. `pressed` falso é a soltura, usada nos passos de segurar.
func qte_key(keycode: int, pressed: bool) -> void:
	if phase != "sep" or qte_index < 0:
		return
	var step: Array = PROCEDURES[qte_index][qte_step]
	var expected: int = step[1]
	if not pressed:
		if keycode == expected and qte_holding:
			qte_holding = false
			qte_hold = 0.0
			_body.text = str(TranslationServer.translate("Soltou cedo: segure %s até a barra encher.")) % OS.get_keycode_string(expected)
		return
	if keycode == expected:
		if step[2] == "hold":
			qte_holding = true
			qte_hold = 0.0
			Sound.play_cue("switch")
		else:
			_qte_advance()
	elif keycode >= KEY_A and keycode <= KEY_Z:
		_qte_fail(str(TranslationServer.translate("Tecla errada: %s em vez de %s.")) % [OS.get_keycode_string(keycode), OS.get_keycode_string(expected)])


func _update_qte(delta: float) -> void:
	if qte_index < 0:
		return
	var step: Array = PROCEDURES[qte_index][qte_step]
	if step[2] == "hold" and qte_holding:
		qte_hold += delta
		var position_index := _order.find(qte_index)
		var steps: Array = PROCEDURES[qte_index]
		_lever_target[position_index] = 0.15 + 0.55 * (qte_step + qte_hold / HOLD_TIME) / steps.size()
		if qte_hold >= HOLD_TIME:
			_qte_advance()
		return
	qte_time_left -= delta
	if qte_time_left <= 0.0:
		_qte_fail(str(TranslationServer.translate("Tempo esgotado em %s.")) % str(TranslationServer.translate(step[0])))


func _qte_advance() -> void:
	Sound.play_cue("switch")
	_key_bounce = 0.14
	var steps: Array = PROCEDURES[qte_index]
	var position_index := _order.find(qte_index)
	qte_step += 1
	qte_hold = 0.0
	qte_holding = false
	_lever_target[position_index] = 0.15 + 0.55 * qte_step / steps.size()
	if qte_step >= steps.size():
		var index := qte_index
		qte_index = -1
		_qte_done_name = SWITCHES[index][0]
		_qte_done_time = 1.4
		Sound.play_cue("confirm")
		_on_switch(index)
	else:
		qte_time_left = _qte_time()


## Erro no procedimento: luz vermelha, tranco e o procedimento recomeça do primeiro passo.
func _qte_fail(reason: String) -> void:
	Sound.play_cue("warning", "Voice", true)
	MissionState.separation_mistakes += 1
	var position_index := _order.find(qte_index)
	_cell_error[position_index] = 1.0
	_qte_error = 1.0
	_qte_alert = str(TranslationServer.translate("TEMPO ESGOTADO!")) if reason.begins_with(str(TranslationServer.translate("Tempo"))) else str(TranslationServer.translate("TECLA ERRADA!"))
	_kick = Vector2(rng.randf_range(-6.0, 6.0), 6.0)
	_lever_target[position_index] = 0.0
	qte_step = 0
	qte_hold = 0.0
	qte_holding = false
	qte_time_left = _qte_time() + 0.8
	_body.text = str(TranslationServer.translate("%s O procedimento %s recomeça do primeiro passo.")) % [reason, SWITCHES[qte_index][0]]


func _animate_levers(delta: float) -> void:
	_qte_done_time = maxf(0.0, _qte_done_time - delta)
	_qte_error = maxf(0.0, _qte_error - delta * 2.0)
	# Durante a confirmação do corte, o aviso central fica sozinho na tela.
	_qte_panel.visible = (phase == "sep" or _qte_done_time > 0.0) and _hud.visible and _cut_feedback <= 0.0
	_key_bounce = maxf(0.0, _key_bounce - delta)
	for i in lever.size():
		# A alavanca acompanha o procedimento e trava com um tranco no fim do curso.
		var speed := 9.0 if _lever_target[i] >= 1.0 else 4.0
		lever[i] = move_toward(lever[i], _lever_target[i], delta * speed)
		_cell_error[i] = maxf(0.0, _cell_error[i] - delta * 1.6)


## Alavanca acionada: chamada ao fim do procedimento (e diretamente pelos testes de fluxo).
func _on_switch(index: int) -> void:
	if phase != "sep":
		return
	if index != sep_step:
		Sound.play_cue("warning", "Voice", true)
		MissionState.separation_mistakes += 1
		_body.text = str(TranslationServer.translate("Fora de ordem! %s não pode vir agora. Siga o checklist.")) % SWITCHES[index][0]
		return
	var position_index := _order.find(index)
	_lever_target[position_index] = 1.0
	_kick = Vector2(0, -7)
	Sound.play_cue("switch")
	sep_step += 1
	_view.separation_step(sep_step)
	_update_checklist()
	if sep_step < SWITCHES.size():
		_body.text = str(TranslationServer.translate("%s acionada. Próximo item do checklist: %s.")) % [SWITCHES[index][0], SWITCHES[sep_step][0]]
	else:
		_finish()


func _finish() -> void:
	phase = "done"
	_kick = Vector2(rng.randf_range(-4.0, 4.0), -9.0)
	Sound.play_cue("dock")
	_status.text = str(TranslationServer.translate("SEPARAÇÃO CONFIRMADA"))
	_body.text = str(TranslationServer.translate("Pirotécnicos disparados: os painéis do adaptador se abrem e o CSM se afasta do S-IVB."))
	_update_checklist()
	MissionState.add_event("separation", str(TranslationServer.translate("Injeção translunar e separação")),
		str(TranslationServer.translate("Concluída com desvio de trajetória de %.0f%% e %d erro(s) de ordem.")) % [MissionState.trajectory_error * 100.0, MissionState.separation_mistakes])
	Houston.clear()
	Houston.say_recorded("separation_confirmed", "We confirm separation. Proceed with transposition and docking.",
		str(TranslationServer.translate("Separação confirmada. Prossigam com a transposição e o acoplamento.")))
	_flight_timer.start()


## Voo acelerado da trajetória até a Lua, com a câmera se afastando.
func _start_flight() -> void:
	if _telemetry_shown:
		return
	_hud.visible = false
	_flight_box.visible = true
	_view.play_flight(MissionState.trajectory_error)


## Pula o voo e vai direto à telemetria (ESPAÇO, ENTER ou clique; também usado nos testes).
func skip_flight() -> void:
	if _telemetry_shown:
		return
	_flight_timer.stop()
	_hud.visible = false
	_view.finish_flight()
	_show_telemetry()


## Resumo da manobra: o que o jogador fez e o que isso custa mais adiante.
func _show_telemetry() -> void:
	if _telemetry_shown:
		return
	_telemetry_shown = true
	_flight_box.visible = false
	var ms := MissionState
	var delta_v := velocity_kms - target
	var cut_grade := str(TranslationServer.translate("no ponto certo")) if absf(delta_v) <= tol else str(TranslationServer.translate("fora do ponto ideal"))
	var att_grade := "firme" if attitude_error() <= 0.0 else "solta"
	var arrival := str(TranslationServer.translate("A rota chega à Lua.")) if ms.trajectory_error < MissionDecisions.SMALL_ERROR else str(TranslationServer.translate("A rota passa ao lado da Lua: será preciso corrigir."))
	_make_panel(str(TranslationServer.translate("TELEMETRIA DA MANOBRA")),
		str(TranslationServer.translate("Corte do motor: %.2f km/s (alvo %.2f) · %s\n")) % [velocity_kms, target, cut_grade] +
		str(TranslationServer.translate("Atitude: desvio médio de %.1f° durante a queima · %s\n")) % [mean_deviation(), att_grade] +
		str(TranslationServer.translate("Erros na separação (ordem ou procedimento): %d\n\n")) % ms.separation_mistakes +
		str(TranslationServer.translate("Desvio de trajetória: %.0f%% (corte %.0f%% + atitude %.0f%%). %s\n")) % [ms.trajectory_error * 100.0, cut_error * 100.0, attitude_error() * 100.0, arrival] +
		str(TranslationServer.translate("Correção de rota prevista na cabine: cerca de %.0f%% do propelente do CSM.\n")) % MissionDecisions.midcourse_cost() +
		str(TranslationServer.translate("Travessia até a Lua: cerca de 3 dias, vividos na cabine a partir do Dia 1.")))
	_panel_button(str(TranslationServer.translate("CONTINUAR ▶")), _advance)
	_advance_timer.start()


func _advance() -> void:
	if _finished:
		return
	_finished = true
	Game.separation_success()


# ---------- Falhas ----------

## A nave sai girando por um instante antes do vídeo de aborto.
func _abort() -> void:
	phase = "failed"
	_view.abort()
	Sound.end_maneuver()
	Sound.play_cue("abort", "Voice", true)
	_status.text = str(TranslationServer.translate("ABORTAR · ABORTAR"))
	_timer(ABORT_DELAY, Game.separation_failed).start()


func _fail_tli(too_fast: bool) -> void:
	if too_fast:
		MissionState.set_failure("separation", str(TranslationServer.translate("TLI ABORTADA · VELOCIDADE EXCESSIVA")),
			[str(TranslationServer.translate("O motor ficou ligado tempo demais (%.2f km/s). A nave passaria longe da Lua.")) % velocity_kms],
			[str(TranslationServer.translate("Pressione ESPAÇO quando a trajetória prevista alcançar a Lua e ficar verde.")), str(TranslationServer.translate("Um pouco antes ou depois também é aceito, mas gasta combustível em correções depois."))])
	else:
		MissionState.set_failure("separation", str(TranslationServer.translate("TLI ABORTADA · CORTE PREMATURO")),
			[str(TranslationServer.translate("O motor foi desligado cedo demais (%.2f km/s). A nave não teria energia para chegar à Lua.")) % velocity_kms],
			[str(TranslationServer.translate("Espere a trajetória prevista alcançar a Lua, perto de %.2f km/s.")) % target])
	_abort()


func _fail_attitude() -> void:
	MissionState.set_failure("separation", str(TranslationServer.translate("TLI ABORTADA · ATITUDE FORA DE CONTROLE")),
		[str(TranslationServer.translate("A nave desviou %.0f° da direção da queima. Com o empuxo apontado para o lado errado, a trajetória não chegaria à Lua.")) % attitude.length()],
		[str(TranslationServer.translate("Mantenha o nariz da nave dentro do anel com WASD ou SETAS durante toda a queima.")),
			str(TranslationServer.translate("Toques curtos funcionam melhor do que segurar a tecla.")),
			str(TranslationServer.translate("Se o MASTER ALARM acender, pressione R: enquanto ele toca, a nave deriva mais."))])
	_abort()


func _fail_sep() -> void:
	MissionState.set_failure("separation", str(TranslationServer.translate("SEPARAÇÃO NÃO CONCLUÍDA")),
		[str(TranslationServer.translate("A janela de separação terminou antes de completar o checklist."))],
		[str(TranslationServer.translate("Leia o checklist: o item marcado com [>] é o próximo.")), str(TranslationServer.translate("Escolha a alavanca com 1, 2, 3 ou clique e pressione as teclas do procedimento assim que elas acenderem."))])
	phase = "failed"
	Sound.play_cue("abort", "Voice", true)
	_timer(ABORT_DELAY, Game.separation_failed).start()


# ---------- Desenho dos instrumentos ----------

func _thousands(value: int) -> String:
	var digits := str(value)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "."
		out += digits[i]
	return out


func _draw_lamps() -> void:
	var blink := fmod(_clock, 0.5) < 0.25
	var font := _lamps.get_theme_default_font()
	var entries := [
		["ENGINE ON", Game.AMBER, phase == "tli"],
		["GUIDANCE", _guidance_color(), phase == "tli" or (phase == "countdown" and _countdown < 3.0)],
		["MASTER ALARM", Game.BAD, incident == "alarm" and blink],
		["CSM SEP", Game.GOOD, phase == "done"],
	]
	for i in entries.size():
		var rect := Rect2(Vector2(i * (LAMP_SIZE.x + 8), 0), LAMP_SIZE)
		var lit: bool = entries[i][2]
		var color: Color = entries[i][1]
		_lamps.draw_rect(rect, color if lit else Color(0.10, 0.105, 0.10))
		_lamps.draw_rect(rect, color.darkened(0.2) if lit else Color(0.28, 0.28, 0.26), false, 2.0)
		_lamps.draw_string(font, rect.position + Vector2(0, 17), entries[i][0], HORIZONTAL_ALIGNMENT_CENTER, LAMP_SIZE.x, 12,
			Color(0.05, 0.05, 0.05) if lit else Color(0.45, 0.45, 0.42))


## Mapa da trajetória: a órbita prevista se estica da órbita de espera até a Lua conforme a
## velocidade sobe. O eixo gira com a guinada da nave, mostrando a mira da queima.
func _draw_map() -> void:
	var font := _map.get_theme_default_font()
	var rect := Rect2(Vector2.ZERO, MAP_SIZE)
	_map.draw_rect(rect, Color(0.02, 0.05, 0.04))
	for i in range(1, 6):
		_map.draw_line(Vector2(MAP_SIZE.x * i / 6.0, 0), Vector2(MAP_SIZE.x * i / 6.0, MAP_SIZE.y), Color(0.3, 0.8, 0.4, 0.1), 1.0)
	for i in range(1, 4):
		_map.draw_line(Vector2(0, MAP_SIZE.y * i / 4.0), Vector2(MAP_SIZE.x, MAP_SIZE.y * i / 4.0), Color(0.3, 0.8, 0.4, 0.1), 1.0)
	var axis := (MAP_MOON - MAP_EARTH).normalized()
	var distance := MAP_EARTH.distance_to(MAP_MOON)
	var aim := deg_to_rad(attitude.x * 2.0) if phase in ["tli", "countdown", "intro"] else _final_aim
	var noisy := incident == "static"
	if noisy:
		aim += sin(_clock * 23.0) * 0.25
	var dir := axis.rotated(aim)
	var frac := clampf(apogee_fraction(), 0.0, 2.2)
	var escaped := apogee_fraction() > 2.0
	var apogee := MAP_PARK + (distance - MAP_PARK) * minf(frac, 1.9)
	var delta_v := velocity_kms - target
	var color := Color(0.75, 0.62, 0.32)
	if absf(delta_v) <= tol:
		color = Game.GOOD
	elif absf(delta_v) <= tol * 2.5:
		color = Game.WARN
	elif delta_v > 0.0:
		color = Game.BAD
	# Órbita de espera, Lua com a zona de captura e Terra.
	_dashed_circle(MAP_EARTH, MAP_PARK, Color(0.5, 0.6, 0.7, 0.6))
	var capture := Game.GOOD if absf(delta_v) <= tol else Color(0.5, 0.5, 0.48, 0.6)
	_dashed_circle(MAP_MOON, 16.0, capture)
	_map.draw_circle(MAP_MOON, 7.0, Color(0.72, 0.71, 0.68))
	_map.draw_circle(MAP_EARTH, 13.0, Color(0.16, 0.36, 0.78))
	_map.draw_circle(MAP_EARTH + Vector2(-4, -3), 5.0, Color(0.3, 0.55, 0.3))
	_map.draw_string(font, MAP_MOON + Vector2(-20, -22), str(TranslationServer.translate("LUA")), HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Game.CREAM)
	# Órbita prevista: foco na Terra, apogeu na direção da mira.
	var a := (MAP_PARK + apogee) * 0.5
	var c := a - MAP_PARK
	var b := sqrt(MAP_PARK * apogee)
	var center := MAP_EARTH + dir * c
	var across := dir.orthogonal()
	var last := Vector2.INF
	for i in 97:
		var t := TAU * i / 96.0
		# Em escape, a curva não fecha: some o trecho do lado de lá do apogeu.
		if escaped and absf(t - PI) < 0.7:
			last = Vector2.INF
			continue
		var point := center + dir * a * cos(t) + across * b * sin(t)
		if noisy:
			point += Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
		if last != Vector2.INF and rect.has_point(point) and rect.has_point(last):
			_map.draw_line(last, point, color, 2.0)
		last = point
	# A nave fica no perigeu, do lado oposto ao da Lua.
	var ship := MAP_EARTH - dir * MAP_PARK
	_map.draw_colored_polygon(PackedVector2Array([ship + across * 5.0, ship - across * 5.0, ship - dir * 6.0]), Game.CREAM)
	var label := str(TranslationServer.translate("APOGEU "))
	if escaped:
		label += "ESCAPE"
	else:
		label += "%s km" % _thousands(int(6556.0 + 377844.0 * frac))
	if noisy:
		label = str(TranslationServer.translate("SEM TELEMETRIA"))
		for i in 70:
			_map.draw_rect(Rect2(Vector2(rng.randf() * MAP_SIZE.x, rng.randf() * MAP_SIZE.y), Vector2(2, 2)), Color(0.7, 0.9, 0.75, 0.5))
	_map.draw_string(font, Vector2(6, MAP_SIZE.y - 8), label, HORIZONTAL_ALIGNMENT_LEFT, MAP_SIZE.x - 12, 13, Game.WARN if noisy else color)
	_map.draw_rect(rect, Game.AMBER.darkened(0.35), false, 1.0)


func _dashed_circle(center: Vector2, radius: float, color: Color) -> void:
	for i in 24:
		if i % 2 == 0:
			_map.draw_arc(center, radius, TAU * i / 24.0, TAU * (i + 1) / 24.0, 3, color, 1.0)


func _dial(center: Vector2, value: float, title: String, reading: String, color: Color) -> void:
	var font := _cluster.get_theme_default_font()
	var radius := 44.0
	var from := deg_to_rad(135.0)
	var to := deg_to_rad(405.0)
	_cluster.draw_circle(center, radius + 4.0, Color(0.06, 0.065, 0.06))
	_cluster.draw_arc(center, radius, from, to, 40, Game.AMBER.darkened(0.3), 3.0)
	for i in 11:
		var angle := lerpf(from, to, i / 10.0)
		var direction := Vector2(cos(angle), sin(angle))
		_cluster.draw_line(center + direction * (radius - (8.0 if i % 5 == 0 else 4.0)), center + direction * radius, Game.CREAM, 2.0)
	var needle := lerpf(from, to, clampf(value, 0.0, 1.0))
	_cluster.draw_line(center, center + Vector2(cos(needle), sin(needle)) * (radius - 10.0), color, 3.0)
	_cluster.draw_circle(center, 4.0, Game.CREAM)
	_cluster.draw_string(font, center + Vector2(-50, 34), reading, HORIZONTAL_ALIGNMENT_CENTER, 100, 14, Game.CREAM)
	_cluster.draw_string(font, center + Vector2(-60, 64), title, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(0.7, 0.7, 0.65))


## Aceleração, velocidade (ponteiro e digital), propelente do estágio e desvio de atitude.
func _draw_cluster() -> void:
	var font := _cluster.get_theme_default_font()
	var burning := phase == "tli"
	var done := clampf(progress(), 0.0, 1.0)
	var blink := fmod(_clock, 0.5) < 0.25
	var g := lerpf(G_START, G_END, done) if burning else 0.0
	_dial(Vector2(52, 52), g / 2.0, str(TranslationServer.translate("ACELERAÇÃO")), "%.1f g" % g, Game.AMBER)
	var shown_velocity := velocity_kms + (sin(_clock * 37.0) * 0.03 if incident == "static" else 0.0)
	var speed_color := Game.GOOD if absf(velocity_kms - target) <= tol else Game.CREAM
	_dial(Vector2(160, 52), (shown_velocity - 7.0) / 5.0, str(TranslationServer.translate("VELOCIDADE")), "km/s", speed_color)
	var fuel := clampf(1.0 - 0.92 * progress(), 0.0, 1.0)
	_dial(Vector2(268, 52), fuel, str(TranslationServer.translate("PROPELENTE S-IVB")), "%d%%" % roundi(fuel * 100.0), Game.GOOD if fuel > 0.15 else Game.WARN)
	var x := 330.0
	var width := CLUSTER_SIZE.x - x
	var digits := "--.-- km/s" if incident == "static" else "%.2f km/s" % velocity_kms
	_cluster.draw_string(font, Vector2(x, 34), digits, HORIZONTAL_ALIGNMENT_CENTER, width, 28, speed_color)
	_cluster.draw_string(font, Vector2(x, 54), str(TranslationServer.translate("ALVO %.2f km/s")) % target, HORIZONTAL_ALIGNMENT_CENTER, width, 13, Game.AMBER)
	var deviation := attitude.length()
	var guidance := _guidance_color() if burning else Color(0.5, 0.5, 0.48)
	_cluster.draw_string(font, Vector2(x, 80), str(TranslationServer.translate("NARIZ FORA DO ANEL  %.1f°")) % deviation, HORIZONTAL_ALIGNMENT_CENTER, width, 14, guidance)
	var notice := ""
	var notice_color := Game.CREAM
	if incident == "alarm":
		notice = str(TranslationServer.translate("MASTER ALARM · [R] SILENCIAR"))
		notice_color = Game.BAD if blink else Game.WARN
	elif incident == "pogo":
		notice = str(TranslationServer.translate("OSCILAÇÃO DO MOTOR"))
		notice_color = Game.WARN
	elif incident == "static":
		notice = str(TranslationServer.translate("TELEMETRIA COM RUÍDO"))
		notice_color = Game.WARN
	elif burning and deviation >= ATT_WARN:
		notice = str(TranslationServer.translate("ATITUDE! VOLTE AO ANEL"))
		notice_color = Game.BAD if blink else Game.WARN
	elif burning and velocity_kms >= target - 0.5 and velocity_kms < target - tol * 2.5:
		notice = str(TranslationServer.translate("PREPARAR CORTE"))
		notice_color = Game.AMBER
	elif burning and absf(velocity_kms - target) <= tol:
		notice = str(TranslationServer.translate("TRAJETÓRIA NA LUA · CORTE AGORA"))
		notice_color = Game.GOOD if blink else Game.CREAM
	elif phase == "sep" and _silence > 0.0:
		notice = str(TranslationServer.translate("MOTOR DESLIGADO"))
		notice_color = Game.GOOD
	_cluster.draw_string(font, Vector2(x, 112), notice, HORIZONTAL_ALIGNMENT_CENTER, width, 15, notice_color)


## Alavanca do painel: placa com marcas ON/OFF, haste que sobe conforme o procedimento,
## manopla colorida e luz de estado. Pisca em vermelho a cada erro.
func _draw_switch(button: Button, position_index: int) -> void:
	var font := button.get_theme_default_font()
	var index: int = _order[position_index]
	var live := phase == "sep"
	var thrown := index < sep_step
	var active := qte_index == index
	var next := live and index == sep_step and qte_index < 0
	var blink := fmod(_clock, 0.5) < 0.25
	var error := _cell_error[position_index]
	var width := button.size.x
	var middle := width * 0.5
	var edge := Game.AMBER.darkened(0.45 if live else 0.7)
	if thrown:
		edge = Game.GOOD.darkened(0.2)
	elif active:
		edge = Game.AMBER if blink else Game.CREAM
	elif next and button.is_hovered():
		edge = Game.AMBER
	if error > 0.0:
		edge = edge.lerp(Game.BAD, error)
	var background := Color(0.07, 0.08, 0.08).lerp(Color(0.35, 0.05, 0.04), error * 0.8)
	button.draw_rect(Rect2(Vector2.ZERO, button.size), background)
	button.draw_rect(Rect2(Vector2.ZERO, button.size), edge, false, 3.0 if active else 2.0)
	var ink := Game.CREAM if live or thrown else Color(0.42, 0.42, 0.40)
	button.draw_string(font, Vector2(0, 18), "[%d] %s" % [position_index + 1, SWITCHES[index][0]], HORIZONTAL_ALIGNMENT_CENTER, width, 13, ink)
	# Placa com o curso da alavanca.
	var plate := Rect2(middle - 26, 26, 52, 80)
	button.draw_rect(plate, Color(0.12, 0.13, 0.13))
	button.draw_rect(plate, Color(0.32, 0.33, 0.32), false, 1.0)
	button.draw_rect(Rect2(middle - 3, plate.position.y + 8, 6, plate.size.y - 16), Color(0.02, 0.02, 0.02))
	button.draw_string(font, Vector2(plate.end.x + 4, plate.position.y + 14), "ON", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Game.GOOD if thrown else Color(0.5, 0.5, 0.48))
	button.draw_string(font, Vector2(plate.end.x + 4, plate.end.y - 4), "OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.5, 0.48) if thrown else Game.CREAM)
	for i in 5:
		var y := lerpf(plate.position.y + 12, plate.end.y - 12, i / 4.0)
		button.draw_line(Vector2(plate.position.x + 4, y), Vector2(plate.position.x + 10, y), Color(0.4, 0.4, 0.38), 1.0)
	var pivot := Vector2(middle, plate.end.y - 6)
	var position_value := lever[position_index]
	var knob := pivot + Vector2(0, -6 - 62 * position_value)
	button.draw_circle(pivot, 8.0, Color(0.22, 0.23, 0.24))
	button.draw_line(pivot, knob, Color(0.72, 0.73, 0.75), 5.0)
	var knob_color: Color = KNOB_COLORS[index]
	button.draw_circle(knob, 9.0, knob_color.darkened(0.35))
	button.draw_circle(knob + Vector2(-2, -2), 6.0, knob_color)
	# Luz de estado e dica.
	var lamp := Color(0.15, 0.15, 0.14)
	var hint := ""
	if thrown:
		lamp = Game.GOOD
		hint = str(TranslationServer.translate("ACIONADA"))
	elif active:
		lamp = Game.AMBER if blink else Color(0.3, 0.2, 0.05)
		hint = str(TranslationServer.translate("EM CURSO"))
	elif next:
		lamp = Game.AMBER.darkened(0.3)
		hint = str(TranslationServer.translate("PRESSIONE %d")) % (position_index + 1) if blink else ""
	button.draw_circle(Vector2(14, button.size.y - 12), 5.0, lamp)
	button.draw_string(font, Vector2(22, button.size.y - 7), hint, HORIZONTAL_ALIGNMENT_CENTER, width - 30, 12, Game.AMBER if not thrown else Game.GOOD)


## Painel de instruções da separação, feito para ser entendido de relance: uma frase grande
## ("PRESSIONE A TECLA Q AGORA!"), a tecla desenhada em tamanho grande, um anel de tempo em
## volta dela e, embaixo, em qual passo o jogador está.
func _draw_qte() -> void:
	var font := _qte.get_theme_default_font()
	var size := _qte.size
	var blink := fmod(_clock, 0.5) < 0.25
	var key_center := Vector2(size.x * 0.5, 202)
	_qte.draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.035, 0.04).lerp(Color(0.35, 0.04, 0.03), _qte_error * 0.8))
	# Cabeçalho: qual alavanca e quanto falta da janela de separação.
	var lever_number := mini(sep_step + 1, SWITCHES.size())
	_qte.draw_string(font, Vector2(6, 22), str(TranslationServer.translate("SEPARAÇÃO · ALAVANCA %d DE 3")) % lever_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Game.AMBER)
	if phase == "sep" and _silence <= 0.0:
		var window_color := Game.CREAM if sep_time_left > 8.0 else (Game.BAD if blink else Game.WARN)
		_qte.draw_string(font, Vector2(0, 22), "%d s" % ceili(maxf(sep_time_left, 0.0)), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6, 17, window_color)
	_qte.draw_line(Vector2(6, 34), Vector2(size.x - 6, 34), Game.AMBER.darkened(0.45), 2.0)

	# Alavanca acabou de ser acionada (ou a separação terminou): confirmação em verde.
	if _qte_done_time > 0.0 and qte_index < 0:
		var done_text := str(TranslationServer.translate("SEPARAÇÃO CONFIRMADA!")) if phase == "done" else str(TranslationServer.translate("%s ACIONADA!")) % _qte_done_name
		_big_text(Vector2(0, 86), done_text, 30, Game.GOOD)
		_qte.draw_circle(key_center, 66.0, Color(0.06, 0.22, 0.08))
		_qte.draw_arc(key_center, 66.0, 0.0, TAU, 48, Game.GOOD, 6.0)
		_qte.draw_polyline(PackedVector2Array([key_center + Vector2(-32, 2), key_center + Vector2(-8, 26), key_center + Vector2(36, -24)]), Game.GOOD, 12.0)
		if phase == "sep" and sep_step < SWITCHES.size():
			_big_text(Vector2(0, 312), str(TranslationServer.translate("Próxima: %s")) % SWITCHES[sep_step][0], 20, Game.CREAM)
		return
	if phase != "sep":
		return

	# Silêncio logo depois do corte: só uma contagem para o jogador se preparar.
	if _silence > 0.0:
		_big_text(Vector2(0, 86), str(TranslationServer.translate("MOTOR DESLIGADO")), 30, Game.GOOD)
		_qte.draw_arc(key_center, 70.0, 0.0, TAU, 48, Game.AMBER.darkened(0.4), 4.0)
		_big_text(Vector2(0, key_center.y + 26), "%d" % ceili(_silence), 72, Game.CREAM)
		_big_text(Vector2(0, 312), str(TranslationServer.translate("Prepare-se: as alavancas vêm a seguir.")), 20, Game.CREAM)
		return

	var instruction := ""
	var subtitle := ""
	var key_label := ""
	var fraction := 1.0
	var fill := 0.0
	var holding_step := false
	if qte_index < 0:
		# Escolher a alavanca: a tecla é o número da posição dela no painel.
		var position_index := _order.find(sep_step)
		key_label = str(position_index + 1)
		instruction = str(TranslationServer.translate("PRESSIONE A TECLA %s AGORA!")) % key_label
		subtitle = str(TranslationServer.translate("Abre a alavanca %s")) % SWITCHES[sep_step][0]
		fraction = clampf(sep_time_left / _sep_window, 0.0, 1.0)
	else:
		var step: Array = PROCEDURES[qte_index][qte_step]
		key_label = OS.get_keycode_string(step[1])
		holding_step = step[2] == "hold"
		if holding_step:
			instruction = str(TranslationServer.translate("CONTINUE SEGURANDO %s...")) % key_label if qte_holding else str(TranslationServer.translate("SEGURE A TECLA %s!")) % key_label
			fill = clampf(qte_hold / HOLD_TIME, 0.0, 1.0)
		else:
			instruction = str(TranslationServer.translate("PRESSIONE A TECLA %s AGORA!")) % key_label
		subtitle = str(TranslationServer.translate("Passo %d de %d · %s")) % [qte_step + 1, PROCEDURES[qte_index].size(), str(TranslationServer.translate(step[0]))]
		fraction = fill if holding_step and qte_holding else clampf(qte_time_left / _qte_time(), 0.0, 1.0)
	var alert := _qte_error > 0.35
	if alert:
		_big_text(Vector2(0, 86), str(TranslationServer.translate("%s TENTE DE NOVO")) % _qte_alert, 25, Game.BAD if blink else Game.CREAM)
	else:
		_big_text(Vector2(0, 86), instruction, 30, Game.AMBER if blink else Game.CREAM)

	# Anel de tempo: cheio no começo, esvazia no sentido horário. Verde, depois amarelo e vermelho.
	var ring_color := Game.GOOD if fraction > 0.5 else (Game.WARN if fraction > 0.25 else Game.BAD)
	if holding_step and qte_holding:
		ring_color = Game.GOOD
	_qte.draw_arc(key_center, 86.0, 0.0, TAU, 64, Color(0.12, 0.12, 0.11), 12.0)
	if fraction > 0.0:
		_qte.draw_arc(key_center, 86.0, -PI * 0.5, -PI * 0.5 + TAU * fraction, 64, ring_color, 12.0)
	# Tecla grande com relevo, que afunda quando o jogador acerta.
	var press := 8.0 if _key_bounce > 0.0 or (holding_step and qte_holding) else 0.0
	var shake := Vector2(sin(_clock * 70.0) * 6.0 * _qte_error, 0.0)
	var cap := Rect2(key_center - Vector2(56, 58) + Vector2(0, press) + shake, Vector2(112, 106))
	var face := Color(0.2, 0.18, 0.13)
	var border := Game.AMBER if blink else Game.CREAM
	if alert:
		face = Color(0.4, 0.07, 0.05)
		border = Game.BAD
	_qte.draw_rect(Rect2(cap.position + Vector2(0, 14 - press), cap.size), Color(0.01, 0.01, 0.01))
	_qte.draw_rect(Rect2(cap.position + Vector2(0, 8 - press * 0.5), cap.size), face.darkened(0.45))
	_qte.draw_rect(cap, face)
	if fill > 0.0:
		_qte.draw_rect(Rect2(cap.position.x, cap.end.y - cap.size.y * fill, cap.size.x, cap.size.y * fill), Color(0.45, 0.9, 0.45, 0.55))
	_qte.draw_rect(Rect2(cap.position + Vector2(10, 8), Vector2(cap.size.x - 20, 6)), Color(1, 1, 1, 0.1))
	_qte.draw_rect(cap, border, false, 4.0)
	_qte.draw_string(font, Vector2(cap.position.x, cap.position.y + 76), key_label, HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, 70, Game.CREAM)
	if holding_step:
		_qte.draw_string(font, Vector2(cap.position.x, cap.end.y - 8), str(TranslationServer.translate("SEGURE")), HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, 14, Game.AMBER)
	# Passo atual e o caminho do procedimento: blocos verdes para os passos feitos.
	_big_text(Vector2(0, 318), subtitle, 20, Game.CREAM)
	if qte_index < 0:
		_big_text(Vector2(0, 348), str(TranslationServer.translate("(ou clique na alavanca)")), 16, Color(0.7, 0.7, 0.65))
	if qte_index >= 0:
		var total: int = PROCEDURES[qte_index].size()
		var width := 56.0
		var gap := 10.0
		var x0 := (size.x - total * width - (total - 1) * gap) * 0.5
		for i in total:
			var pip := Rect2(Vector2(x0 + i * (width + gap), 334), Vector2(width, 16))
			var pip_color := Game.GOOD if i < qte_step else (Game.AMBER if i == qte_step else Color(0.2, 0.2, 0.19))
			_qte.draw_rect(pip, pip_color)
			_qte.draw_rect(pip, Color(0, 0, 0, 0.5), false, 2.0)


func _big_text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := _qte.get_theme_default_font()
	_qte.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, _qte.size.x, font_size, 6, Color.BLACK)
	_qte.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, _qte.size.x, font_size, color)
