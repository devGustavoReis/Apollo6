extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func seed_for_assistance(success: bool) -> void:
	for value in range(100):
		seed(value)
		if (randf() < 0.8) == success:
			seed(value)
			return


func station_key(cabin: Node, station: String) -> void:
	cabin.target_id = station
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.pressed = true
	cabin._unhandled_input(event)


func aim_at_station(cabin: Node, station: String) -> void:
	var marker: Node3D
	if station == "disposal":
		marker = cabin.cabin.get_node("MealDisposal")
	else:
		for slot: String in cabin.STATIONS:
			if cabin.STATIONS[slot][0] == station:
				marker = cabin.cabin.get_node("EquipmentSlots/" + slot)
				break
	if marker == null:
		check(false, "Estação sem marcador: " + station)
		return
	var body: StaticBody3D = marker.get_node("InteractionZone")
	var center: Vector3 = body.get_child(0).global_position
	var inward := Vector3(-center.x, 0.0, -center.z).normalized()
	var camera: Camera3D = cabin.player.camera
	var previous := camera.transform
	cabin.player.frozen = true
	camera.global_position = center + inward * 0.75
	camera.look_at(center)
	await physics_frame
	await physics_frame
	check(cabin.target_id == station, "Mira alcança %s pela cabine (alvo %s)" % [station, cabin.target_id])
	camera.transform = previous
	cabin.player.frozen = false


func start_minigame(cabin: Node, station: String, id := "") -> void:
	station_key(cabin, station)
	if cabin.hud.modal_open() and cabin.hud.minigame == null:
		if id != "":
			var briefing: String = cabin.BRIEFINGS.TEXTOS[id]["instrucoes"]
			check(cabin.hud._modal_body.text == briefing, id + " mostra as instruções antes de começar")
			var buttons: Array = cabin.hud._modal_buttons.get_children().filter(func(b): return not b.is_queued_for_deletion())
			check(buttons.size() == 2, id + " oferece começar ou adiar")
		cabin.hud._on_modal_button(0)


func finish(cabin: Node, success: bool) -> void:
	if cabin.hud.minigame != null:
		cabin.hud.minigame.terminou.emit(success)


func run() -> void:
	var ms := root.get_node("MissionState")
	var game := root.get_node("Game")
	var scene := load(game.SCENES["cabin"]) as PackedScene
	var planned := {1: ["M01", "M02"], 2: ["M05"], 3: ["M06"], 4: ["M04"], 5: ["M03"]}
	for difficulty: String in ["easy", "normal", "hard"]:
		ms.reset(difficulty)
		ms.apply_plan()
		ms.random_event = "ptc"
		var cabin := scene.instantiate()
		root.add_child(cabin)
		await process_frame
		cabin.player.seated = false
		for day: int in planned:
			ms.day = day
			var optional: Array = cabin.day_tasks().filter(func(task): return task.get("optional", false))
			check(optional.map(func(task): return task["id"]) == planned[day], "Tarefas opcionais do dia %d em %s" % [day, difficulty])
			check(not cabin._pending().any(func(task): return task.get("optional", false)), "Tarefas opcionais não bloqueiam avanço")
			for id: String in planned[day]:
				var data: Dictionary = ms.CABIN_MINIGAMES[id]
				check(cabin._station_minigame(data["station"]) == id, id + " na estação e dia corretos")
				if difficulty == "normal":
					await aim_at_station(cabin, data["station"])
				start_minigame(cabin, data["station"], id)
				check(cabin.hud.minigame != null and cabin.player.frozen, id + " abre com F e congela o jogador")
				if cabin.hud.minigame == null:
					continue
				check(cabin.hud.minigame.nivel == ["easy", "normal", "hard"].find(difficulty), id + " recebe dificuldade")
				var escape := InputEventKey.new()
				escape.physical_keycode = KEY_ESCAPE
				escape.pressed = true
				cabin.hud._unhandled_input(escape)
				check(not cabin.hud.modal_open() and not cabin.player.frozen and not ms.minigame_attempts.has(id), id + " Esc abandona sem sorteio")
				start_minigame(cabin, data["station"])
				finish(cabin, false)
				check(not ms.minigame_completions.has(id) and ms.next_minigame_attempt(id) == 2, id + " falha sem ferramenta dá 0 ponto")
				cabin.hud._on_modal_button(0)
				check(cabin.hud.minigame != null and cabin.hud.minigame.folga == 1, id + " nova tentativa ganha folga sem repetir instruções")
				finish(cabin, true)
				check(ms.minigame_completions.has(id), id + " retry pode concluir sem ferramenta")
				check(cabin.hud._modal_body.text.contains(cabin.BRIEFINGS.TEXTOS[id]["licao"]), id + " explica a atividade real depois de concluir")
				cabin.hud._on_modal_button(0)
				station_key(cabin, data["station"])
				check(cabin.hud.minigame == null and ms.next_minigame_attempt(id) == 3, id + " revisão da conclusão não inicia nova tentativa")
				cabin.hud._on_modal_button(0)
		check(ms.cabin_minigame_report()["points"] == 600, "Seis conclusões valem 600 pontos em " + difficulty)
		cabin.queue_free()
		await process_frame

	ms.reset("normal")
	ms.set_qty("fastening_kit", 1)
	ms.set_qty("signal_meter", 1)
	ms.apply_plan()
	ms.random_event = "comm_dropout"
	var cabin := scene.instantiate()
	root.add_child(cabin)
	await process_frame
	cabin.player.seated = false
	start_minigame(cabin, "storage")
	seed_for_assistance(false)
	finish(cabin, false)
	check(not ms.minigame_completions.has("M01"), "20% adverso mantém tarefa pendente mesmo com kit")
	cabin.hud._on_modal_button(0)
	seed_for_assistance(true)
	finish(cabin, false)
	check(ms.minigame_completions.get("M01", {}).get("assisted", false), "Erro recuperado com ajuda explícita")
	check(ms.cabin_minigame_report()["rows"][0]["status"].contains("Kit de fixação"), "Relatório identifica a ferramenta")
	check(cabin.hud._modal_body.text.contains("Kit de fixação"), "A tela de resultado identifica a ferramenta")
	check(cabin.hud._modal_body.text.contains(cabin.BRIEFINGS.TEXTOS["M01"]["licao"]), "Conclusão com ajuda também explica a atividade real")
	cabin.hud._on_modal_button(0)
	start_minigame(cabin, "water")
	seed_for_assistance(true)
	finish(cabin, false)
	check(not ms.minigame_completions.has("M02"), "Ferramenta incompatível não recupera")
	cabin.hud._on_modal_button(1)

	ms.day = 5
	station_key(cabin, "radio")
	cabin.hud._on_modal_button(0)
	check(cabin.hud.minigame == null and cabin.hud._modal_body.text == cabin.BRIEFINGS.TEXTOS["M03"]["instrucoes"], "Decisão leva às instruções do M03")
	cabin.hud._on_modal_button(0)
	check(cabin.hud.minigame != null, "Realinhamento escolhido na decisão abre M03")
	seed_for_assistance(false)
	finish(cabin, false)
	var fuel: float = ms.sps_fuel
	ms.test_samples = [0.99]
	cabin.hud._on_modal_button(1)
	check(cabin._done("radio") and not ms.minigame_completions.has("M03"), "É possível continuar a operação sem recuperar M03")
	check(ms.sps_fuel == fuel - 3.0 and ms.decisions.back()["correct"] and not ms.decisions.back()["favorable"], "Escolha boa com M03 pendente e complicação aplica consequência uma vez")
	cabin.hud._on_modal_button(0)
	start_minigame(cabin, "radio")
	seed_for_assistance(true)
	finish(cabin, false)
	check(ms.minigame_completions.get("M03", {}).get("assisted", false) and ms.decisions.size() == 1, "Recuperação posterior pontua sem reexecutar a decisão")
	cabin.hud._on_modal_button(0)

	ms.day = 2
	for task: Dictionary in cabin._pending("rest"):
		ms.tasks_done[cabin._key(task["id"])] = true
	cabin.interact("rest")
	cabin.hud._on_modal_button(0)
	check(ms.day == 2 and cabin.hud._night != null and cabin.player.frozen, "Preparação do sono inicia sem avançar o dia")
	cabin.hud._night_tween.custom_step(1.4)
	check(ms.day == 2 and cabin.hud._night.get_child(0).text == "Dia 3", "Cartela visível ainda no dia 2")
	cabin.hud._night_tween.custom_step(1.5)
	check(ms.day == 3 and cabin.hud._night == null and not cabin.player.frozen, "Dia 3 só começa após a cartela")
	check(ms.cabin_minigame_report()["points"] == 200, "Quatro pendências ficam no relatório")
	check(ms.cabin_minigame_report()["rows"].filter(func(r): return r["title"] == "Preparar a cabine para descanso")[0]["status"] == "Pendente", "Descanso não completa automaticamente M05")
	ms.save_checkpoint("landing")
	ms.minigame_attempts.clear()
	ms.minigame_completions.clear()
	ms.restore_checkpoint("landing")
	check(ms.cabin_minigame_report()["points"] == 200 and ms.next_minigame_attempt("M01") == 3, "Checkpoint preserva resultado e tentativas")
	cabin.queue_free()
	root.get_node("Houston").clear()
	await process_frame
	randomize()
	print("CABIN MINIGAME INTEGRATION CHECKS: ", failures.size(), " failures")
	quit(1 if failures.size() else 0)
