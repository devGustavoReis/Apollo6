extends SceneTree
## Teste automático do protótipo: carrega todas as cenas, percorre a missão,
## verifica checkpoints e confirma que o pouso é possível em todas as dificuldades
## sem a reserva de propelente.
## Uso: godot --headless --path . --script tests/flow_test.gd

var failures: Array[String] = []


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("FALHA: " + message)


func _initialize() -> void:
	call_deferred("run")


func ms() -> Node:
	return root.get_node("MissionState")


func fly_trajectory(minigame: Node, wrong_moves: int) -> void:
	minigame.espera = 0.0
	for i in wrong_moves:
		minigame.mover(minigame.nave + Vector2(0, 400))
	for i in range(1, minigame.pontos.size()):
		minigame.mover(minigame.pontos[i])
	for i in 5:
		await process_frame


func open_cabin_day() -> Node:
	var cabin: Node = load(root.get_node("Game").SCENES["cabin"]).instantiate()
	root.add_child(cabin)
	await physics_frame
	await physics_frame
	cabin.player.unbuckle()
	for i in 70:
		await physics_frame
	return cabin


func finish_eating(cabin: Node) -> void:
	cabin.interact(cabin.target_id)
	for i in 40:
		if not cabin.eating and cabin.held == "":
			return
		cabin._process(0.1)


func eat(cabin: Node, kind: String) -> void:
	cabin.interact(kind)
	await finish_eating(cabin)


func check_racks(cabin: Node) -> void:
	var packs: Node = cabin.cabin.get_node_or_null("EquipmentSlots/FoodStorage/FoodRack/Packs")
	var pouches: Node = cabin.cabin.get_node_or_null("EquipmentSlots/WaterStorage/WaterRack/Pouches")
	check(packs != null and pouches != null and cabin.cabin.get_node_or_null("EquipmentSlots/MedicalStorage/MedicalRack/Bag") != null, "Modelos de comida, água e kit médico nos slots")
	if packs == null or pouches == null:
		return
	var shown := packs.get_children().filter(func(n): return n.visible).size()
	check(shown == mini(floori(ms().food_days + 0.0001), 8), "Pacotes visíveis acompanham as cotas inteiras (%d visíveis, %s)" % [shown, ms().amount_text(ms().food_days)])
	shown = pouches.get_children().filter(func(n): return n.visible).size()
	check(shown == mini(floori(ms().water_days + 0.0001), 8), "Bolsas visíveis acompanham as cotas inteiras (%d visíveis, %s)" % [shown, ms().amount_text(ms().water_days)])


func do_tasks(cabin: Node, day: int, skip: Array) -> void:
	var hud = cabin.hud
	for task in cabin.day_tasks():
		if task["id"] in skip or task.get("optional", false):
			continue
		var guard := 0
		while not (cabin._done(task["id"]) or ms().day > day) and guard < 4:
			if task["id"] == "water":
				cabin.target_id = "water"
				var event := InputEventAction.new()
				event.action = "cabin_task"
				event.pressed = true
				cabin._unhandled_input(event)
			else:
				cabin.interact(task["id"])
			while hud.modal_open() or cabin._gesture_active:
				if cabin._gesture_active:
					cabin._decision_motion.custom_step(1.0)
				elif hud.minigame != null:
					if hud.minigame.scene_file_path.ends_with("/antenna_minigame.tscn"):
						var antenna: Node = hud.minigame
						for step in range(23):
							antenna.mira = antenna.terra
							antenna.passo(0.1, Vector2.ZERO)
						antenna.espera = 0.0
						await process_frame
					elif hud.minigame.has_signal("completed"):
						var cartridge: Control = hud.minigame
						while hud.minigame == cartridge:
							cartridge.angle = 0.0
							cartridge._advance()
							cartridge._motion.custom_step(0.5)
					else:
						await fly_trajectory(hud.minigame, 0)
				elif hud._night != null:
					hud._night_tween.custom_step(3.0)
					await process_frame
				else:
					hud._on_modal_button(0)
			guard += 1
		check(cabin._done(task["id"]) or ms().day > day, "Dia %d: tarefa %s concluída" % [day, task["id"]])


func run() -> void:
	TranslationServer.set_locale("pt_BR")
	root.get_node("Game").language = "pt_BR"
	root.get_node("MissionState").refresh_catalog_language()
	var game := root.get_node("Game")
	await process_frame
	# 1. Todas as cenas carregam e rodam alguns quadros.
	game.cutscene_entries = []
	for key in ["menu", "planning", "separation", "report"]:
		ms().reset("normal")
		var scene: Node = load(game.SCENES[key]).instantiate()
		root.add_child(scene)
		for i in 5:
			await process_frame
		check(is_instance_valid(scene), "Cena %s carregou" % key)
		scene.queue_free()
		await process_frame

	var cut: GDScript = load("res://scripts/cutscenes/cutscene_player.gd")
	check(cut != null and cut.can_instantiate(), "Script de cutscene compila")

	# 2. Planejamento: plano padrão inválido (sem ciência), plano mínimo viável em todas as dificuldades.
	for diff in ["easy", "normal", "hard"]:
		ms().reset(diff)
		check(not ms().validate_plan()["ok"], "%s: plano sem ciência deve ser bloqueado" % diff)
		ms().select_objective("sample_kit")
		ms().set_qty("sample_kit", 1)
		check(ms().validate_plan()["ok"], "%s: plano mínimo deve ser viável" % diff)
		ms().set_qty("food_day", 7)
		check(not ms().validate_plan()["ok"], "%s: comida insuficiente deve bloquear" % diff)
		ms().set_qty("food_day", 8)
		for id in ms().items:
			ms().set_qty(id, 99)
		var limits: Dictionary = ms().settings()
		var within_limits: bool = ms().plan_items() <= int(limits["storage"]) and ms().plan_mass() <= limits["mass_limit"] + 0.001
		check(ms().validate_plan()["ok"] == within_limits, "%s: carga máxima respeita os limites de armazenamento e massa" % diff)
		ms().set_qty("retroreflector", 1)
		check(ms().qty("retroreflector") == 0, "Objetivo de amostras bloqueia outro instrumento")

	var storage := {"easy": 24, "normal": 21, "hard": 17}
	var optional := ["battery_pack", "propellant_reserve", "spare_parts", "fastening_kit", "sealing_kit", "signal_meter", "blackout_kit"]
	for diff: String in storage:
		ms().reset(diff)
		check(int(ms().settings()["storage"]) == storage[diff], "%s: armazenamento de %d itens" % [diff, storage[diff]])
		check(not ms().settings().has("budget"), "%s: sem orçamento" % diff)
		ms().select_objective("camera")
		ms().set_qty("camera", 1)
		check(ms().plan_items() == 17 and ms().validate_plan()["ok"], "%s: plano mínimo de 17 itens é válido" % diff)
		var added := 0
		for id: String in optional:
			var before: int = ms().plan_items()
			ms().set_qty(id, 1)
			if ms().plan_items() > before:
				added += 1
		check(added == storage[diff] - 17, "%s: cabem %d opcionais além do mínimo (%d)" % [diff, storage[diff] - 17, added])
		check(ms().plan_items() <= storage[diff], "%s: o total nunca passa do armazenamento" % diff)
		ms().set_qty("food_day", 9)
		check(ms().plan_items() <= storage[diff], "%s: mais comida não passa do armazenamento" % diff)
		if diff == "easy":
			check(ms().plan_items() == 24 and ms().validate_plan()["ok"] == (ms().plan_mass() <= ms().settings()["mass_limit"]), "easy: leva o mínimo e todos os opcionais")
		var full: int = ms().plan_items()
		ms().set_qty("water_day", 7)
		check(ms().plan_items() == full - 1, "%s: diminuir funciona com o armazenamento cheio" % diff)
		ms().cargo["water_day"] = 30
		check(str(ms().validate_plan()["errors"]).contains("Armazenamento excedido"), "%s: carga acima do limite acusa armazenamento excedido" % diff)

	# 3. Missão completa na cabine (normal), com cada evento aleatório, nos cinco dias.
	for event_id in ["comm_dropout", "water_leak", "ptc"]:
		ms().reset("normal")
		ms().select_objective("sample_kit")
		ms().set_qty("sample_kit", 1)
		ms().apply_plan()
		ms().random_event = event_id
		ms().trajectory_error = 0.3
		ms().test_samples = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]
		ms().day = 1
		ms().stage = "cabin"
		var cabin: Node = await open_cabin_day()
		check(cabin.cabin.get_node_or_null("PreviewPlayer") == null, "PreviewPlayer removido")
		var hud = cabin.hud
		cabin.interact("food")
		check(cabin.held == "food" and ms().food_eaten == 0, "Pegar a comida ainda não consome uma cota")
		await finish_eating(cabin)
		check(cabin.held == "" and ms().food_eaten == 1 and ms().intake_on(1, "food") == 1, "Comer o item segurado consome uma cota")
		for day in [1, 2, 3]:
			check(ms().day == day, "Dia %d" % day)
			if cabin._has_task("water") and not cabin._done("water"):
				await do_tasks(cabin, day, ["rest", "hatch"])
				check(cabin._done("water") and ms().lost_water > 0.0, "Vazamento tratado antes de beber")
			if day > 1:
				await eat(cabin, "food")
			await eat(cabin, "water")
			check(ms().intake_on(day, "food") == 1 and ms().intake_on(day, "water") == 1, "Dia %d: uma cota de cada consumida" % day)
			await do_tasks(cabin, day, ["hatch"])
		check(ms().day == 3 and ms().sealed.size() == 2, "Chegou ao dia 3 com dois dias selados (%s)" % event_id)
		check(is_equal_approx(ms().food_days, 5.0) and is_equal_approx(ms().water_days, 5.0 - ms().lost_water), "Saldo após os dias de ida (%s)" % event_id)
		check(not cabin.day_tasks().any(func(t): return t["id"] in ["food", "water"] and t["text"].contains("do dia")), "Comida e água não são tarefas do checklist")
		check(ms().decisions.size() >= 2, "Registrou decisões (%d)" % ms().decisions.size())
		check(ms().decisions.all(func(d): return d["correct"]), "Opção 1 é a escolha adequada em todas as decisões (%s)" % event_id)
		check(ms().decisions.all(func(d): return d["favorable"]), "Amostra 0,1 dá desfecho favorável a escolhas boas (%s)" % event_id)
		await create_timer(1.0).timeout
		var food: Node3D = cabin.cabin.get_node("EquipmentSlots/FoodStorage")
		cabin.player.global_position = Vector3(-0.9, 0.6, 0.35)
		cabin.player.camera.look_at(food.global_position + Vector3(0, 0.3, 0))
		await physics_frame
		await physics_frame
		check(cabin.target_id == "food", "Raio de interação encontra FOOD (achou '%s')" % cabin.target_id)
		check_racks(cabin)
		var paid: Dictionary = root.get_node("Game").confirm_jump("A")
		check(paid["ok"] and ms().sealed.has("3") and is_equal_approx(ms().food_days, 4.0), "Salto A sela o Dia 3 e cobra 1 de cada")
		check(root.get_node("Game").confirm_jump("A") == paid and is_equal_approx(ms().food_days, 4.0), "Salto A não cobra duas vezes")
		cabin.queue_free()
		await process_frame
		ms().landing_result = {"success": true, "vy": 1.0, "vh": 0.3, "tilt": 2.0, "fuel_left": 20.0, "distance": 12.0}
		check(ms().complete_science(), "Atividade científica concluída após o pouso")
		var b: Dictionary = root.get_node("Game").confirm_jump("B")
		var leak: bool = event_id == "water_leak"
		check(b["ok"] and is_equal_approx(ms().food_days, 3.0), "Salto B cobra 1 de cada (%s)" % event_id)
		check(ms().departure["ok"] != leak, "Reserva 3/3 aprovada sem vazamento e bloqueada com vazamento (%s)" % event_id)
		if leak:
			check(ms().departure_text().contains("Faltou") and ms().ended.get("stage", "") == "departure", "Partida bloqueada registra o déficit")
			check(ms().verdict()["summary"].begins_with("Pouso lunar confirmado"), "Pouso seguro preservado com retorno bloqueado")
			continue
		ms().phase = "return"
		ms().day = 4
		ms().stage = "cabin"
		ms().return_error = 0.3
		cabin = await open_cabin_day()
		hud = cabin.hud
		for day in [4, 5]:
			check(ms().day == day, "Dia %d" % day)
			await eat(cabin, "food")
			await eat(cabin, "water")
			await do_tasks(cabin, day, ["console"])
		check(ms().day == 5 and ms().sealed.has("4") and not ms().sealed.has("5"), "Dia 4 selado no descanso e Dia 5 aberto")
		check(cabin._done("radio"), "Rádio do Dia 5 resolvido (%s)" % event_id)
		check(ms().decisions.any(func(d): return d["id"] == "return_course"), "Correção de volta registrada")
		check(is_zero_approx(ms().return_error), "Correção limpa zera o desvio de volta")
		check(hud.minigame == null and not cabin.player.frozen, "Minigame de trajetória fechado e jogador livre")
		var c: Dictionary = root.get_node("Game").confirm_jump("C")
		check(c["ok"] and ms().sealed.has("5") and is_zero_approx(ms().food_days) and is_zero_approx(ms().water_days), "Missão exata termina em 0/0 depois do salto C")
		check(ms().day_issues().is_empty(), "Nenhuma falta diária na missão exata")
		ms().splashdown = true
		check(ms().verdict()["success"], "Missão exata com amerissagem é concluída (%s)" % event_id)
		cabin.queue_free()
		await process_frame
		root.get_node("Houston").clear()

	# 4. Checkpoint do pouso restaura combustível e estado.
	ms().reset("normal")
	ms().select_objective("sample_kit")
	ms().set_qty("sample_kit", 1)
	ms().apply_plan()
	ms().day = 3
	ms().save_checkpoint("landing")
	ms().lm_fuel = 1.0
	ms().day = 99
	ms().landing_attempts = 2
	check(ms().restore_checkpoint("landing"), "Restaurou checkpoint")
	check(ms().day == 3 and is_equal_approx(ms().lm_fuel, ms().lm_fuel_max), "Checkpoint restaurou dia e combustível")
	check(ms().landing_attempts == 2, "Tentativas preservadas após restaurar")

	# 5. Pouso possível com piloto automático simples, sem reserva de propelente.
	for diff in ["easy", "normal", "hard"]:
		ms().reset(diff)
		ms().select_objective("sample_kit")
		ms().set_qty("sample_kit", 1)
		ms().apply_plan()
		ms().last_failure = {}
		var landing: Node = load(game.SCENES["landing"]).instantiate()
		root.add_child(landing)
		await process_frame
		landing.state = "flying"
		landing.set_physics_process(false)
		var dt := 1.0 / 60.0
		var t := 0.0
		while landing.state == "flying" and t < 300.0:
			var hv := Vector2(landing.vel.x, landing.vel.z)
			var tilt_in := Vector2(-hv.x, hv.y) * 0.8
			var target_vy := -clampf(landing.pos.y * 0.15, 0.8, 9.0)
			var hover: float = landing.MOON_G / landing.MAX_ACCEL
			var wanted := clampf(hover + (target_vy - landing.vel.y) * 0.5, 0.0, 1.0)
			var throttle_in := clampf((wanted - landing.throttle) * 10.0, -1.0, 1.0)
			if landing.pos.y < 3.0:
				tilt_in = Vector2.ZERO
			landing.step(dt, throttle_in, tilt_in)
			t += dt
		check(landing.state == "landed", "%s: pouso possível com propelente base (estado %s, %s)" % [diff, landing.state, str(ms().last_failure.get("reasons", []))])
		print("%s: pouso em %.0f s, sobrou %.0f s de propelente de %.0f" % [diff, t, ms().lm_fuel, ms().lm_fuel_max])
		landing.queue_free()
		await process_frame

	# 6. Pouso desastroso é detectado como falha.
	ms().reset("normal")
	ms().apply_plan()
	var crash: Node = load(game.SCENES["landing"]).instantiate()
	root.add_child(crash)
	await process_frame
	crash.state = "flying"
	crash.set_physics_process(false)
	var guard := 0
	while crash.state == "flying" and guard < 20000:
		guard += 1
		crash.step(1.0 / 60.0, -1.0, Vector2.ZERO)
	check(crash.state == "crashed" and ms().last_failure.get("stage", "") == "landing", "Queda livre gera falha explicada")
	crash.queue_free()

	# 7. Relatório.
	ms().landing_result = {"success": true, "vy": 1.0, "vh": 0.3, "tilt": 2.0, "fuel_left": 20.0, "distance": 12.0}
	ms().landing_attempts = 1
	var report: Dictionary = load("res://scripts/ui/report_screen.gd").evaluate()
	check(report["score"] > 0.0 and report["tips"].size() > 0, "Relatório gera pontuação e dicas")

	var tolerances := []
	for diff in ["easy", "normal", "hard"]:
		tolerances.append(ms().DIFFICULTIES[diff].get("traj_tol", 0.0))
	check(tolerances[0] > tolerances[1] and tolerances[1] > tolerances[2] and tolerances[2] > 0.0, "Tolerância da trajetória diminui com a dificuldade")
	var decisions: GDScript = load("res://scripts/mission/mission_decisions.gd")
	ms().reset("normal")
	ms().return_error = 0.3
	ms().test_samples = [0.1]
	decisions.apply("return_course", 0, 0)
	var clean_fuel: float = ms().sps_fuel
	ms().reset("normal")
	ms().return_error = 0.3
	ms().test_samples = [0.1]
	var sloppy: Dictionary = decisions.apply("return_course", 0, 3)
	check(ms().sps_fuel < clean_fuel, "Desvios no minigame gastam mais propelente")
	check(sloppy["correct"] and ms().return_error > 0.0, "Três desvios deixam desvio residual, mas a escolha de corrigir continua adequada")
	ms().reset("normal")
	ms().return_error = 1.0
	ms().test_samples = [0.99]
	decisions.apply("return_course", 0, 99)
	check(ms().sps_fuel >= 70.0, "Pior correção ainda deixa propelente (%.1f%%)" % ms().sps_fuel)
	var minigame: Node = load("res://scenes/minigames/trajectory_minigame.tscn").instantiate()
	root.add_child(minigame)
	await process_frame
	var reported := [-1]
	minigame.terminou.connect(func(errors): reported[0] = errors)
	minigame.mover(minigame.pontos[0] + Vector2(0, 400))
	check(minigame.erros == 1 and minigame.nave == minigame.pontos[0], "Sair da rota conta um desvio e devolve a nave")
	minigame.mover((minigame.pontos[0] + minigame.pontos[1]) / 2.0)
	check(minigame.erros == 1 and minigame.indice == 0 and minigame.nave != minigame.pontos[0], "Seguir a linha move a nave sem desvio")
	await fly_trajectory(minigame, 1)
	check(minigame.acabou and reported[0] == 2, "Minigame termina e informa os desvios (informou %d)" % reported[0])
	minigame.queue_free()
	await process_frame

	check_minigame_assistance()
	print("FLOW CHECKS: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func _seed_assist(should_recover: bool) -> void:
	for value in range(100):
		seed(value)
		if (randf() < 0.8) == should_recover:
			seed(value)
			return


func check_minigame_assistance() -> void:
	var mission := ms()
	mission.reset("normal")
	var failure: Dictionary = mission.resolve_minigame_attempt("M01", 1, false)
	check(not failure["completed"] and not failure["assisted"] and failure["new_attempt"], "Sem ferramenta, um erro mantém a tarefa pendente")
	var direct: Dictionary = mission.resolve_minigame_attempt("M01", 2, true)
	check(direct["completed"] and direct["played_well"] and not direct["assisted"], "Minigame pode ser concluído sem ferramenta")
	mission.reset("normal")

	var assignments := {
		"M01": "fastening_kit", "M02": "sealing_kit", "M03": "signal_meter",
		"M04": "sealing_kit", "M05": "blackout_kit", "M06": "fastening_kit",
	}
	for id: String in assignments:
		var tool: String = assignments[id]
		mission.set_qty(tool, 1)
		_seed_assist(true)
		var assist: Dictionary = mission.resolve_minigame_attempt(id, 1, false)
		check(assist["completed"] and assist["assisted"] and not assist["played_well"], id + ": assistência conclui a tarefa sem atribuir acerto")
		check(assist["tool_id"] == tool and assist["message"].contains(mission.items[tool]["name"]), id + ": feedback identifica a ferramenta")
		check(assist["message"].contains("errou"), id + ": feedback reconhece o erro")
		var duplicate: Dictionary = mission.resolve_minigame_attempt(id, 1, false)
		check(not duplicate["new_attempt"] and not duplicate["new_completion"], id + ": sinal duplicado não dá nova conclusão")
		var replay: Dictionary = mission.resolve_minigame_attempt(id, 2, true)
		check(replay["assisted"] and not replay["new_completion"], id + ": tarefa concluída preserva como foi resolvida")
		mission.set_qty(tool, 0)

	mission.reset("normal")
	mission.set_qty("signal_meter", 1)
	_seed_assist(true)
	var wrong_tool: Dictionary = mission.resolve_minigame_attempt("M05", 1, false)
	check(not wrong_tool["completed"] and wrong_tool["tool_id"].is_empty(), "Ferramenta de outra tarefa não assiste")
	_seed_assist(false)
	var unlucky: Dictionary = mission.resolve_minigame_attempt("M03", 1, false)
	check(not unlucky["completed"] and not unlucky["assisted"] and unlucky["tool_id"] == "signal_meter", "Uma ferramenta pode falhar em recuperar o erro")
	mission.save_checkpoint("assist_test")
	_seed_assist(true)
	var reemit: Dictionary = mission.resolve_minigame_attempt("M03", 1, false)
	check(not reemit["completed"] and not reemit["new_attempt"], "Repetir o sinal de falha não sorteia de novo")
	var retry: Dictionary = mission.resolve_minigame_attempt("M03", 2, false)
	check(retry["completed"] and retry["new_completion"], "Uma nova tentativa real pode receber assistência")
	check(mission.restore_checkpoint("assist_test"), "Checkpoint de assistência restaurado")
	check(not mission.minigame_completions.has("M03") and mission.minigame_attempts["M03"].size() == 1, "Checkpoint preserva tentativas e conclusões no momento salvo")
	mission.reset("normal")
	check(mission.minigame_attempts.is_empty() and mission.minigame_completions.is_empty(), "Nova missão limpa os resultados de assistência")
	randomize()
