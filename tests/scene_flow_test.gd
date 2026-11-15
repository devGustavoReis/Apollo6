extends SceneTree
## Percorre as trocas de cena reais da missão completa: menu → planejamento → cutscenes →
## separação (falha e repetição) → cabine Dias 1–3 → transição A → pouso (falha e repetição)
## → transição B → cabine Dias 4–5 → transição C → reentrada (falha e repetição) → relatório.
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


func press_first(screen: Node) -> void:
	var buttons: Array = screen._buttons.get_children().filter(func(b): return not b.is_queued_for_deletion())
	var confirm: Button = buttons.back()
	check(confirm.disabled, "Botão de confirmação começa travado para a leitura")
	for i in 40:
		if not confirm.disabled:
			break
		await create_timer(0.1).timeout
	check(not confirm.disabled, "Botão de confirmação liberado depois da leitura")
	confirm.pressed.emit()


func consume_day(ms: Node) -> void:
	ms.consume("food")
	ms.consume("water")


func run() -> void:
	var game := root.get_node("Game")
	var ms := root.get_node("MissionState")
	change_scene_to_file(game.SCENES["menu"])
	var menu: Node = await wait_scene("MainMenu")
	menu._on_difficulty(2)
	menu._on_start()
	await wait_scene("Planning")
	check(ms.difficulty == "hard", "Dificuldade escolhida no menu")
	ms.select_objective("retroreflector")
	ms.set_qty("retroreflector", 1)
	check(ms.qty("food_day") == 8 and ms.qty("water_day") == 8 and ms.validate_plan()["ok"], "Plano nominal 8/8 aprovado")
	game.launch()
	await skip_cutscene()
	var sep: Node = await wait_scene("Separation")
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
	check(ms.phase == "outbound" and ms.day == 1, "Cabine de ida no Dia 1")
	for day in [1, 2]:
		consume_day(ms)
		ms.seal_day(day)
		ms.day += 1
	consume_day(ms)
	check(is_equal_approx(ms.food_days, 5.0) and is_equal_approx(ms.water_days, 5.0), "5/5 depois dos Dias 1 a 3")
	ms.tasks_done["3:console"] = true
	cabin.interact("hatch")
	cabin.hud._on_modal_button(0)
	var transition: Node = await wait_scene("Transition")
	check(transition.id == "A" and transition._title.text.contains("4 dias e 6 horas"), "Transição A mostra o tempo histórico")
	check(transition._body.text.contains("Saldo agora: [b]5 comida · 5 água[/b]"), "Transição A mostra o saldo antes de cobrar")
	await create_timer(0.8).timeout
	transition._go_back()
	cabin = await wait_scene("CabinGame")
	check(is_equal_approx(ms.food_days, 5.0) and ms.jumps.is_empty() and not ms.sealed.has("3"), "Voltar da transição A não cobra nem sela o Dia 3")
	check(ms.day == 3 and cabin._done("console"), "Dia 3 e inserção preservados ao voltar")
	game.enter_lunar_module()
	transition = await wait_scene("Transition")
	await press_first(transition)
	await skip_cutscene()
	var landing: Node = await wait_scene("Landing")
	check(ms.sealed.has("3") and is_equal_approx(ms.food_days, 4.0) and ms.checkpoints.has("landing"), "Transição A sela, cobra 4/4 e grava o checkpoint do pouso")
	landing._start()
	landing.set_physics_process(false)
	while landing.state == "flying":
		landing.step(1.0 / 60.0, 0.0, Vector2.ZERO)
	check(landing.attempt["primary"] == "vertical", "Queda livre tem impacto vertical como causa principal")
	await skip_cutscene()
	landing = await wait_scene("Landing")
	check(ms.landing_attempts == 1 and ms.last_failure.get("stage", "") == "landing", "Falha no pouso volta ao pouso, não à missão")
	game.retry_from_checkpoint("landing", "landing")
	landing = await wait_scene("Landing")
	check(ms.stage == "landing" and ms.day == 3 and is_equal_approx(ms.food_days, 4.0) and ms.jumps.size() == 1, "Repetir o pouso não refaz a inserção nem a cobrança de A")
	landing._start()
	landing.set_physics_process(false)
	landing.pos = Vector3(0, 0.5, 0)
	landing.vel = Vector3(0, -1.0, 0)
	while landing.state == "flying":
		landing.step(1.0 / 60.0, 0.0, Vector2.ZERO)
	check(landing.state == "landed", "Pouso suave aceito")
	await skip_cutscene()
	transition = await wait_scene("Transition")
	check(transition.id == "B" and ms.landing_result.get("success", false), "Pouso seguro leva à transição B, não ao relatório")
	check(transition._title.text.contains("Atividade científica"), "Atividade científica oferecida após pouso")
	await press_first(transition)
	check(ms.science_completed, "Ciência registrada pela ação do jogador")
	await press_first(transition)
	check(transition._body.text.contains("21 h e 36 min") and transition._body.text.contains("3 de cada"), "Transição B resume a Lua e a reserva de 3")
	await press_first(transition)
	check(transition._title.text == "Dia 4 · Volta à Terra" and ms.day == 3, "Cartela do Dia 4 aparece antes de abrir o dia")
	check(is_equal_approx(ms.food_days, 3.0) and ms.departure["ok"], "Partida aprovada com 3/3")
	await press_first(transition)
	cabin = await wait_scene("CabinGame")
	check(ms.phase == "return" and ms.day == 4 and ms.stage == "cabin", "Cabine de volta no Dia 4")
	check(cabin.day_tasks().any(func(t): return t["id"] == "M04") and not cabin.day_tasks().any(func(t): return t["id"] == "hatch"), "Dia 4 tem M04 e nenhuma escotilha")
	consume_day(ms)
	cabin.player.unbuckle()
	await create_timer(1.2).timeout
	for task in cabin._pending("rest"):
		ms.tasks_done[cabin._key(task["id"])] = true
	cabin.interact("rest")
	cabin.hud._on_modal_button(0)
	check(ms.sealed.has("4") and ms.day == 4, "Descanso sela o Dia 4 antes da cartela")
	await create_timer(3.5).timeout
	check(ms.day == 5 and cabin.hud._night == null, "Dia 5 abre só depois da cartela")
	consume_day(ms)
	cabin.interact("console")
	check(cabin.hud.modal_open() and cabin.hud._modal_body.text.contains("RADIO"), "Preparar reentrada pede o status pelo rádio antes")
	cabin.hud._on_modal_button(0)
	ms.tasks_done["5:radio"] = true
	cabin.interact("console")
	transition = await wait_scene("Transition")
	check(transition.id == "C" and transition._body.text.contains("Saldo agora: [b]1 comida · 1 água[/b]"), "Transição C mostra 1/1 antes do salto")
	await press_first(transition)
	var reentry: Node = await wait_scene("Reentry")
	check(ms.sealed.has("5") and is_zero_approx(ms.food_days) and is_zero_approx(ms.water_days) and ms.checkpoints.has("reentry"), "Transição C sela o Dia 5, termina em 0/0 e grava o checkpoint")
	reentry.set_process(false)
	reentry.start()
	for i in 2000:
		if reentry.phase == "failed":
			break
		reentry.step(1.0 / 60.0)
	check(reentry.phase == "failed" and reentry.result["code"] == "window_missed", "Sem toque, a janela expira")
	reentry._retry()
	reentry = await wait_scene("Reentry")
	check(ms.reentry_attempts == 1 and is_zero_approx(ms.food_days) and ms.landing_result.get("success", false), "Repetir a reentrada mantém saldo e pouso")
	reentry.set_process(false)
	reentry.start()
	while reentry.phase != "window":
		reentry.step(1.0 / 60.0)
	reentry.press()
	check(reentry.phase == "mains", "Toque na janela abre os paraquedas principais")
	for i in 2000:
		if reentry.phase == "splash":
			break
		reentry.step(1.0 / 60.0)
	check(ms.splashdown, "Amerissagem confirmada só depois do toque na água")
	game.finish_mission()
	var report: Node = await wait_scene("Report")
	var verdict: Dictionary = ms.verdict()
	check(verdict["success"] and verdict["title"] == "Missão concluída", "Missão exata com tudo cumprido é concluída")
	check(ms.landing_attempts == 2 and ms.reentry_history.size() == 2, "Relatório recebe tentativas de pouso e de reentrada")
	check(report != null, "Relatório aberto")
	print("SCENE FLOW CHECKS: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
