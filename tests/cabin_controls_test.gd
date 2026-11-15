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
	await zero_g_drift()
	await preview_keypad_enter()
	await separation_second_space()
	print("CONTROLS CHECKS: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)


## Em microgravidade, ESPAÇO empurra uma vez por toque, a deriva conserva a velocidade e o
## contato com o teto dissipa energia. O jogador não sai pelo vão da escotilha.
func zero_g_stays_inside() -> void:
	var ms := root.get_node("MissionState")
	ms.reset("normal")
	var game: Node = await open("res://scenes/spacecraft/cabin_game.tscn", "CabinGame")
	if game == null:
		return
	var player: CharacterBody3D = game.player
	player.unbuckle()
	await create_timer(1.2).timeout
	check(not player.seated and not player.frozen and player.grabbing, "Jogador solto e segurando o apoio após o cinto")
	player.set_physics_process(false)
	player.pitch = 0.0
	player.look(Vector2(0, -2000))
	Input.action_press("move_up")
	player._physics_process(DT)
	var pushed: Vector3 = player.velocity
	check(pushed.length() > 1.0 and pushed.y > 1.0, "ESPAÇO segurando o apoio empurra na direção do olhar (%.2f m/s)" % pushed.length())
	player._physics_process(DT)
	check(player.velocity.is_equal_approx(pushed), "ESPAÇO mantido não empurra de novo")
	Input.action_release("move_up")
	player.velocity = Vector3.UP * 1.4
	var max_y := -INF
	var impacts := 0
	var first := {}
	for i in 600:
		var before: Dictionary = player.last_impact
		player._physics_process(DT)
		max_y = maxf(max_y, player.global_position.y)
		if player.last_impact != before:
			impacts += 1
			if first.is_empty():
				first = player.last_impact
	check(max_y < 2.6, "Subir sob a escotilha deve parar no teto (y máximo %.2f)" % max_y)
	check(impacts >= 1 and first.get("speed_out", 9.0) < first.get("speed_in", 0.0), "Contato com o teto dissipa velocidade (%.2f → %.2f m/s)" % [first.get("speed_in", 0.0), first.get("speed_out", 0.0)])
	check(first.get("normal", Vector3.ZERO).y < -0.5, "A normal do teto aponta para baixo")
	player.pitch = 0.0
	player.look(Vector2(0, -2000))
	game._physics_process(DT)
	check(game.target_id == "hatch", "Encostado na escotilha, olhando para o vão, o alvo é a escotilha (alvo '%s')" % game.target_id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func zero_g_drift() -> void:
	var ms := root.get_node("MissionState")
	ms.reset("normal")
	var game: Node = await open("res://scenes/spacecraft/cabin_game.tscn", "CabinGame")
	if game == null:
		return
	var player: CharacterBody3D = game.player
	player.unbuckle()
	await create_timer(1.2).timeout
	player.set_physics_process(false)
	player.global_position = Vector3(0, 1.3, 0.55)
	player.grabbing = false
	player.contact_time = 99.0
	player.velocity = Vector3(0, 0, 0.2)
	for fps in [30.0, 60.0, 120.0]:
		player.global_position = Vector3(0, 1.3, 0.55)
		player.velocity = Vector3(0, 0, 0.2)
		var start: Vector3 = player.global_position
		for i in int(fps):
			player._physics_process(1.0 / fps)
		check(player.velocity.is_equal_approx(Vector3(0, 0, 0.2)), "Deriva conserva a velocidade a %d FPS" % fps)
		check(absf(player.global_position.z - start.z - 0.2) < 0.01, "Deriva percorre 0,2 m em 1 s a %d FPS (%.3f)" % [fps, player.global_position.z - start.z])
	player.global_position = Vector3(0, 1.3, 0.55)
	player.velocity = Vector3(0, 0, 0.2)
	Input.action_press("move_forward")
	Input.action_press("move_up")
	for i in 30:
		player._physics_process(DT)
	Input.action_release("move_forward")
	Input.action_release("move_up")
	check(player.velocity.is_equal_approx(Vector3(0, 0, 0.2)), "WASD e ESPAÇO no ar não mudam a deriva")
	player.yaw = 1.0
	player.look(Vector2(300, 100))
	player._physics_process(DT)
	check(player.velocity.is_equal_approx(Vector3(0, 0, 0.2)), "Olhar para outro lado não muda a deriva")
	player.velocity = Vector3.ZERO
	player.still_time = 3.0
	check(player.needs_help(), "Parado no ar sem apoio, o jogo oferece a ajuda do apoio")
	Input.action_press("move_up")
	player._physics_process(DT)
	Input.action_release("move_up")
	check(player.velocity.length() > 0.3, "Ajuda puxa o jogador em direção ao apoio")
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
