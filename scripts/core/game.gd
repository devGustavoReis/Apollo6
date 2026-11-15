extends Node
## Fluxo entre etapas, controles e tema visual (autoload "Game").

const SCENES := {
	"menu": "res://scenes/menu/main_menu.tscn",
	"planning": "res://scenes/planning/planning.tscn",
	"cutscene": "res://scenes/cutscenes/cutscene.tscn",
	"separation": "res://scenes/minigames/separation.tscn",
	"cabin": "res://scenes/spacecraft/cabin_game.tscn",
	"landing": "res://scenes/lunar_module/landing.tscn",
	"transition": "res://scenes/transition/transition.tscn",
	"reentry": "res://scenes/reentry/reentry.tscn",
	"report": "res://scenes/report/report.tscn",
}

## Cada entrada toca o vídeo, se existir, ou mostra um cartão de texto provisório.
## Coloque os vídeos convertidos para .ogv (Ogg Theora) em assets/videos/.
const CUTSCENES := {
	"launch": [
		{"video": "res://assets/videos/01_launchpad.ogv", "duration": 4.0,
			"title": "16 DE JULHO DE 1969", "caption": "Um foguete inspirado no Saturn V aguarda na plataforma."},
		{"video": "res://assets/videos/02_family_tv.ogv", "duration": 3.5,
			"title": "AO VIVO", "caption": "Famílias acompanham a contagem regressiva pela televisão."},
		{"video": "res://assets/videos/03_liftoff.ogv", "duration": 4.0,
			"title": "DECOLAGEM", "caption": "Primeiro e segundo estágios levam a nave à órbita da Terra. O terceiro estágio, S-IVB, a coloca em órbita."},
	],
	"docking": [
		{"video": "res://assets/videos/separation_success.ogv", "duration": 5.0,
			"title": "TRANSPOSIÇÃO E ACOPLAMENTO", "caption": "O módulo de comando e serviço se separa do S-IVB, gira 180° e se acopla ao módulo lunar, retirando-o do estágio."},
		{"video": "res://assets/videos/04_space_cabin.ogv", "duration": 4.0,
			"title": "A CAMINHO DA LUA", "caption": "Thomas Walker, na cadeira central do módulo de comando."},
	],
	"separation_fail": [
		{"video": "res://assets/videos/separation_fail.ogv", "duration": 3.0,
			"title": "ABORTAR", "caption": "Houston cancela a manobra. Voltando ao último checkpoint."},
	],
	"undocking": [
		{"video": "res://assets/videos/undocking.ogv", "duration": 4.0,
			"title": "ÓRBITA LUNAR", "caption": "A tripulação passa pelo túnel ao módulo lunar. O módulo de comando permanece em órbita."},
	],
	"landing_fail": [
		{"video": "res://assets/videos/landing_fail.ogv", "duration": 3.0,
			"title": "IMPACTO", "caption": "O módulo lunar tocou o solo fora dos limites seguros."},
	],
	"landing_success": [
		{"video": "res://assets/videos/landing_success.ogv", "duration": 5.0,
			"title": "CONTATO COM A SUPERFÍCIE", "caption": "O módulo lunar está em segurança na Lua."},
	],
}

var transition_id := ""
var cutscene_entries: Array = []
var cutscene_next := "menu"
var cutscene_id := ""
var ui_theme: Theme
## Tremor de tela nas manobras. Pode ser desligado em CONFIGURAÇÕES e vale para a sessão.
var screen_shake := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	ui_theme = _build_theme()
	get_tree().root.theme = ui_theme
	get_tree().node_added.connect(_on_node_added)


## Controles sob CanvasLayer não herdam o tema da janela: aplica o tema neles.
func _on_node_added(node: Node) -> void:
	if node is Control and node.theme == null and not (node.get_parent() is Control):
		node.theme = ui_theme


func go(scene_key: String) -> void:
	Houston.clear()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_deferred("change_scene_to_file", SCENES[scene_key])


func play_cutscene(id: String, next_scene: String) -> void:
	cutscene_id = id
	cutscene_entries = CUTSCENES[id]
	cutscene_next = next_scene
	go("cutscene")


func finish_cutscene() -> void:
	go(cutscene_next)


# ---------- Fluxo da missão ----------

func start_new_mission(difficulty: String) -> void:
	MissionState.reset(difficulty)
	go("planning")


func launch() -> void:
	if MissionState.stage != "planning" or not MissionState.validate_plan()["ok"]:
		return
	MissionState.apply_plan()
	MissionState.stage = "separation"
	MissionState.save_checkpoint("separation")
	play_cutscene("launch", "separation")


func separation_failed() -> void:
	Sound.end_maneuver()
	MissionState.separation_attempts += 1
	play_cutscene("separation_fail", "separation")


func retry_from_checkpoint(checkpoint: String, scene_key: String) -> void:
	MissionState.restore_checkpoint(checkpoint)
	MissionState.last_failure = {}
	go(scene_key)


func separation_success() -> void:
	MissionState.separation_attempts += 1
	MissionState.stage = "cabin"
	MissionState.day = 1
	MissionState.save_checkpoint("cabin")
	play_cutscene("docking", "cabin")


func open_transition(id: String) -> void:
	transition_id = id
	go("transition")


func enter_lunar_module() -> void:
	open_transition("A")


func confirm_jump(id: String) -> Dictionary:
	var ms := MissionState
	if id == "A":
		ms.seal_day(3)
	elif id == "C":
		ms.seal_day(5)
	ms.supply_tokens.clear()
	var paid := ms.pay_jump(id)
	if not paid["ok"]:
		ms.end_mission("jump_" + id, ms.jump_text(id))
		return paid
	if id == "B" and not ms.tasks_done.has("tei"):
		ms.tasks_done["tei"] = true
		ms.sps_fuel = maxf(ms.sps_fuel - 20.0, 0.0)
		ms.add_event("tei", "Queima de partida rumo à Terra", "O motor do módulo de serviço gastou 20%% do propelente. Restam %.0f%%." % ms.sps_fuel)
	if id == "B":
		var reserve := ms.check_departure()
		if not reserve["ok"]:
			ms.end_mission("departure", ms.departure_text())
	return paid


func start_descent() -> void:
	var ms := MissionState
	if ms.current_checkpoint == "landing" or ms.stage == "landing":
		return
	ms.phase = "lunar"
	ms.stage = "landing"
	ms.last_failure = {}
	ms.save_checkpoint("landing")
	play_cutscene("undocking", "landing")


func landing_failed() -> void:
	play_cutscene("landing_fail", "landing")


func landing_success() -> void:
	MissionState.stage = "lunar_ops"
	transition_id = "B"
	play_cutscene("landing_success", "transition")


func begin_return() -> void:
	var ms := MissionState
	if ms.phase == "return":
		return
	ms.phase = "return"
	ms.day = 4
	ms.stage = "cabin"
	ms.return_error = 0.06 + ms.sample() * 0.4
	ms.save_checkpoint("return")
	go("cabin")


func start_reentry() -> void:
	var ms := MissionState
	if ms.stage == "reentry":
		return
	ms.phase = "earth"
	ms.stage = "reentry"
	ms.save_checkpoint("reentry")
	go("reentry")


func retry_reentry() -> void:
	MissionState.reentry_attempts += 1
	MissionState.restore_checkpoint("reentry")
	MissionState.stage = "reentry"
	go("reentry")


func finish_mission() -> void:
	MissionState.stage = "report"
	go("report")


# ---------- Controles ----------

func _setup_inputs() -> void:
	var map := {
		"move_forward": [KEY_W], "move_back": [KEY_S],
		"move_left": [KEY_A], "move_right": [KEY_D],
		"move_up": [KEY_SPACE], "move_down": [KEY_CTRL, KEY_C],
		"interact": [KEY_E], "cabin_task": [KEY_F], "checklist": [KEY_TAB],
		"advance": [KEY_ENTER, KEY_KP_ENTER], "pause": [KEY_ESCAPE],
		"engine": [KEY_SPACE],
		"tilt_left": [KEY_A, KEY_LEFT], "tilt_right": [KEY_D, KEY_RIGHT],
		"tilt_forward": [KEY_W, KEY_UP], "tilt_back": [KEY_S, KEY_DOWN],
		"chute": [KEY_SPACE], "put_back": [KEY_Q],
		"retry": [KEY_R], "drop_supply": [KEY_G],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


# ---------- Tema retrô ----------

const AMBER := Color(0.96, 0.74, 0.36)
const CREAM := Color(0.93, 0.89, 0.78)
const PANEL_BG := Color(0.06, 0.07, 0.065, 0.95)
const GOOD := Color(0.45, 0.9, 0.45)
const WARN := Color(1.0, 0.8, 0.25)
const BAD := Color(1.0, 0.35, 0.3)


func _box(bg: Color, border: Color, width := 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_content_margin_all(10)
	return box


func _build_theme() -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	t.default_font = font
	t.default_font_size = 18
	var panel := _box(PANEL_BG, AMBER.darkened(0.25))
	panel.set_content_margin_all(16)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_color("font_color", "Label", CREAM)
	t.set_stylebox("normal", "Button", _box(Color(0.12, 0.13, 0.11), AMBER.darkened(0.45)))
	t.set_stylebox("hover", "Button", _box(Color(0.2, 0.17, 0.1), AMBER))
	t.set_stylebox("pressed", "Button", _box(Color(0.3, 0.22, 0.1), AMBER))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), AMBER, 1))
	t.set_stylebox("disabled", "Button", _box(Color(0.08, 0.08, 0.08), Color(0.25, 0.25, 0.25)))
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", AMBER)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.4))
	t.set_color("default_color", "RichTextLabel", CREAM)
	t.set_stylebox("normal", "OptionButton", _box(Color(0.12, 0.13, 0.11), AMBER.darkened(0.45)))
	t.set_stylebox("hover", "OptionButton", _box(Color(0.2, 0.17, 0.1), AMBER))
	t.set_stylebox("background", "ProgressBar", _box(Color(0.1, 0.1, 0.1), Color(0.3, 0.3, 0.28), 1))
	t.set_stylebox("fill", "ProgressBar", _box(AMBER.darkened(0.2), Color(0, 0, 0, 0), 0))
	return t


static func level_color(ratio: float) -> Color:
	## 0 = seguro, 1 = no limite.
	if ratio < 0.6:
		return GOOD
	if ratio < 1.0:
		return WARN
	return BAD


static func make_label(text: String, size := 18, color := CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
