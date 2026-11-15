extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var ms := root.get_node("MissionState")
	for difficulty in ["easy", "normal", "hard"]:
		for id: String in ms.OBJECTIVES:
			ms.reset(difficulty)
			check(not ms.validate_plan()["ok"], "Objetivo obrigatório")
			ms.select_objective(id)
			check(not ms.validate_plan()["ok"], "Instrumento deve ser confirmado")
			ms.set_qty(id, 1)
			check(ms.validate_plan()["ok"], "Plano viável em cada dificuldade")
			ms.apply_plan()
			check(ms.instruments_active.has(id), "Instrumento ativo")
			check(not ms.complete_science(), "Não coleta antes de pousar")
			ms.landing_result = {"success": true}
			check(ms.complete_science(), "Ciência depois do pouso")
			var points: float = ms.science_collected
			check(not ms.complete_science() and ms.science_collected == points, "Ciência idempotente")
			ms.save_checkpoint("science")
			ms.science_completed = false
			ms.restore_checkpoint("science")
			check(ms.science_completed, "Checkpoint preserva ciência")
	ms.reset("normal")
	ms.random_event = "water_leak"
	ms.decision_seed = 0
	check(ms.day_two_decision_order() == ["power", "water"], "Uma partida oferece energia antes do vazamento")
	ms.decision_seed = 1
	ms.save_checkpoint("order")
	ms.decision_seed = 0
	ms.restore_checkpoint("order")
	check(ms.day_two_decision_order() == ["water", "power"], "Checkpoint restaura a outra ordem")
	ms.reset("normal")
	ms.select_objective("sample_kit")
	ms.set_qty("sample_kit", 1)
	ms.select_objective("camera")
	check(ms.qty("sample_kit") == 0, "Troca libera carga antiga")
	ms.set_qty("camera", 1)
	ms.apply_plan()
	ms.stage = "cabin"
	ms.nourishment = 80.0
	ms.hydration = 60.0
	ms.close_day_needs(1)
	ms.close_day_needs(1)
	check(ms.critical_wake_pending, "Dormir sem comer prepara o despertar crítico")
	ms.begin_wake()
	check(ms.nourishment == 5.0 and ms.hydration == 5.0 and ms.need_critical.size() == 2, "Despertar crítico deixa as duas barras em 5%")
	var food: float = ms.food_days
	check(ms.consume("food"), "Consumo válido")
	check(is_equal_approx(ms.nourishment, 55.0) and ms.food_days == food - 1.0 and not ms.need_critical.has("food"), "Consumo soma 50, cobra e encerra só a queda crítica da fome")
	ms.save_checkpoint("survival")
	var water: float = ms.water_days
	var token: int = ms.reserve_supply("water")
	check(token > 0 and ms.available_supply("water") == water - 1.0, "Pegar reserva uma cota no compartimento")
	check(ms.water_days == water, "Pegar não consome")
	check(ms.consume_supply_token(token), "Consumo debita a cota reservada")
	check(not ms.consume_supply_token(token) and ms.water_days == water - 1.0, "Mesmo objeto só pode ser consumido uma vez")
	check(ms.restore_checkpoint("survival"), "Restaura a sede crítica para validar a derrota")
	ms.advance_survival(10.0)
	check(ms.ended.get("stage") == "survival", "Game over imediato quando a sede zera")
	check(ms.verdict()["causes"][0].contains("sede chegou a zero"), "Motivo físico no relatório")
	check(not ms.consume("food"), "Game over impede consumo")
	var cargo := {"retroreflector": [2, false, "laser_retroreflector"], "camera": [2, false, "surface_camera"], "sample_kit": [4, true, "lunar_sample_container_open"], "sample_closed": [2, false, "lunar_sample_container_closed"]}
	for key: String in cargo:
		var id: String = key.replace("_closed", "_kit")
		ms.reset("normal")
		ms.select_objective(id)
		ms.set_qty(id, 1)
		ms.apply_plan()
		ms.day = cargo[key][0]
		ms.science_completed = cargo[key][1]
		ms.stage = "cabin"
		var cabin: Node = load(root.get_node("Game").SCENES["cabin"]).instantiate()
		root.add_child(cabin)
		await process_frame
		var model: Node = cabin.cabin.get_node_or_null("ScienceCargo/Model")
		check(model != null and model.scene_file_path.ends_with(cargo[key][2] + ".glb"), "Carga científica mostra o modelo de " + key)
		cabin.queue_free()
		await process_frame
		root.get_node("Houston").clear()
	print("SCIENCE / SURVIVAL CHECKS: %d failures" % failures)
	quit(0 if failures == 0 else 1)
