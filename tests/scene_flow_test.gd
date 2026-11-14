extends SceneTree
## Percorre as trocas de cena reais: menu → planejamento → cutscenes → separação →
## cabine → pouso (com falha e repetição) → relatório.
## Uso: godot --headless --path . --script tests/scene_flow_test.gd

var failures: Array[String] = []


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("FALHA: " + message)


func _initialize() -> void:
	call_deferred("run")


func wait_scene(name: String) -> Node:
	for i in 800:
		await create_timer(0.02).timeout
		if current_scene and current_scene.name == name:
			for j in 3:
				await process_frame
			return current_scene
	check(false, "Cena %s não apareceu (atual: %s)" % [name, current_scene.name if current_scene else "nenhuma"])
	return null


func skip_cutscene() -> void:
	var cut: Node = await wait_scene("Cutscene")
	if cut:
		cut._finish()


func run() -> void:
	var game := root.get_node("Game")
	var ms := root.get_node("MissionState")
	change_scene_to_file(game.SCENES["menu"])
	var menu: Node = await wait_scene("MainMenu")
	menu._on_difficulty(2)
	menu._on_start()
	await wait_scene("Planning")
	check(ms.difficulty == "hard", "Dificuldade escolhida no menu")
	ms.set_qty("retroreflector", 1)
	game.launch()
	await skip_cutscene()
	var sep: Node = await wait_scene("Separation")
	# Corte prematuro gera falha e volta ao checkpoint sem refazer o planejamento.
	sep._start_tli()
	sep._cutoff()
	await skip_cutscene()
	sep = await wait_scene("Separation")
	check(ms.last_failure.get("stage", "") == "separation", "Falha da separação explicada")
	game.retry_from_checkpoint("separation", "separation")
	sep = await wait_scene("Separation")
	sep._start_tli()
	sep.velocity_kms = ms.TLI_TARGET_KMS
	sep._cutoff()
	for i in 3:
		sep._on_switch(i)
	await skip_cutscene()
	var cabin: Node = await wait_scene("CabinGame")
	check(ms.separation_attempts == 2, "Duas tentativas de separação registradas")
	ms.day = 3
	ms.tasks_done["3:console"] = true
	cabin.interact("hatch")
	cabin.hud._on_modal_button(0)
	await skip_cutscene()
	var landing: Node = await wait_scene("Landing")
	landing._start()
	landing.set_physics_process(false)
	while landing.state == "flying":
		landing.step(1.0 / 60.0, -1.0, Vector2.ZERO)
	await skip_cutscene()
	landing = await wait_scene("Landing")
	check(ms.landing_attempts == 1 and ms.last_failure.get("stage", "") == "landing", "Falha no pouso volta ao pouso, não à missão")
	game.retry_from_checkpoint("landing", "landing")
	landing = await wait_scene("Landing")
	check(ms.stage == "landing" and ms.day == 3, "Checkpoint do pouso preserva a missão")
	landing._start()
	landing.set_physics_process(false)
	landing.pos = Vector3(0, 0.5, 0)
	landing.vel = Vector3(0, -1.0, 0)
	landing.step(1.0 / 60.0, 0.0, Vector2.ZERO)
	while landing.state == "flying":
		landing.step(1.0 / 60.0, 0.0, Vector2.ZERO)
	check(landing.state == "landed", "Pouso suave aceito")
	await skip_cutscene()
	await wait_scene("Report")
	check(ms.landing_attempts == 2, "Relatório recebe 2 tentativas de pouso")
	print("SCENE FLOW CHECKS: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
