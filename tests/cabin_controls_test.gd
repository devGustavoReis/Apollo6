extends SceneTree
## Regressões de controle e física da cabine e da separação.
## Uso: godot --headless --path . --script tests/cabin_controls_test.gd

const DT := 1.0 / 60.0

var failures: Array[String] = []


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("FALHA: " + message)


func _initialize() -> void:
	call_deferred("run")


func key(code: Key, pressed := true, echo := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	ev.echo = echo
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


func open(path: String, scene_name: String) -> Node:
	change_scene_to_file(path)
	for i in 400:
		await process_frame
		if current_scene and current_scene.name == scene_name:
			for j in 3:
				await physics_frame
			return current_scene
	check(false, "Cena %s não abriu" % scene_name)
	return null


func run() -> void:
	await zero_g_stays_inside()
	await preview_keypad_enter()
	await separation_second_space()
	print("CONTROLS CHECKS: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)


## Em microgravidade, segurar ESPAÇO depois de soltar o cinto não pode tirar o jogador
## da nave pelo vão aberto da escotilha, e a escotilha continua alvo encostado no teto.
func zero_g_stays_inside() -> void:
	var ms := root.get_node("MissionState")
	ms.reset("normal")
	var game: Node = await open("res://scenes/spacecraft/cabin_game.tscn", "CabinGame")
	if game == null:
		return
	var player: CharacterBody3D = game.player
	player.unbuckle()
	await create_timer(1.2).timeout
	check(not player.seated and not player.frozen, "Jogador solto e livre após o cinto")
	player.set_physics_process(false)
	Input.action_press("move_up")
	var max_y := -INF
	for i in 600:
		player._physics_process(DT)
		max_y = maxf(max_y, player.global_position.y)
	Input.action_release("move_up")
	check(max_y < 2.6, "Subir sob a escotilha deve parar no teto (y máximo %.2f)" % max_y)
	player.pitch = 0.0
	player.look(Vector2(0, -2000))
	game._physics_process(DT)
	check(game.target_id == "hatch", "Encostado na escotilha, olhando para o vão, o alvo é a escotilha (alvo '%s')" % game.target_id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## O controlador de inspeção aceita o Enter do teclado numérico, como o resto do jogo,
## e o eco do Enter mantido alterna uma vez só.
func preview_keypad_enter() -> void:
	var main: Node = await open("res://scenes/main.tscn", "Main")
	if main == null:
		return
	var player: CharacterBody3D = main.get_node("SpacecraftInterior/PreviewPlayer")
	check(player.seated, "Inspeção começa sentada")
	await key(KEY_KP_ENTER)
	await key(KEY_KP_ENTER, false)
	check(not player.seated, "Enter do teclado numérico levanta")
	await key(KEY_ENTER)
	for i in 10:
		await key(KEY_ENTER, true, true)
	await key(KEY_ENTER, false)
	check(player.seated, "Enter mantido alterna uma única vez")


## Um segundo toque em ESPAÇO logo após o corte da TLI não aciona interruptores.
func separation_second_space() -> void:
	var ms := root.get_node("MissionState")
	ms.reset("normal")
	var sep: Node = await open("res://scenes/minigames/separation.tscn", "Separation")
	if sep == null:
		return
	sep._start_tli()
	sep.velocity_kms = ms.TLI_TARGET_KMS
	await key(KEY_SPACE)
	await key(KEY_SPACE, false)
	check(sep.phase == "sep", "ESPAÇO corta o motor da TLI")
	await key(KEY_SPACE)
	await key(KEY_SPACE, false)
	check(sep.sep_step == 0 and ms.separation_mistakes == 0, "Segundo ESPAÇO não aciona interruptor (passo %d, erros %d)" % [sep.sep_step, ms.separation_mistakes])
	for i in 3:
		var button: Button = sep._switch_buttons[i]
		check(button.focus_mode == Control.FOCUS_NONE, "Interruptor %d sem foco de teclado" % (i + 1))
	var before: int = sep.sep_step + ms.separation_mistakes
	await key(KEY_1)
	await key(KEY_1, false)
	check(sep.sep_step + ms.separation_mistakes == before + 1, "Tecla 1 continua acionando o interruptor")
