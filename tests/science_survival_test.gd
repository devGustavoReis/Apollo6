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
	ms.select_objective("sample_kit")
	ms.set_qty("sample_kit", 1)
	ms.select_objective("camera")
	check(ms.qty("sample_kit") == 0, "Troca libera carga antiga")
	ms.set_qty("camera", 1)
	ms.apply_plan()
	ms.stage = "cabin"
	ms.nourishment = 0.8
	ms.hydration = 0.6
	ms.sleep_penalty(1)
	ms.sleep_penalty(1)
	check(is_equal_approx(ms.nourishment, 0.4) and is_equal_approx(ms.hydration, 0.3), "Noite reduz uma vez à metade")
	var food: float = ms.food_days
	check(ms.consume("food"), "Consumo válido")
	check(ms.nourishment == 1.0 and ms.food_days == food - 1.0, "Consumo recupera e cobra")
	ms.save_checkpoint("survival")
	ms.advance_survival(2000)
	check(ms.ended.get("stage") == "survival", "Game over imediato")
	check(ms.verdict()["causes"][0].contains("esgotada"), "Motivo físico no relatório")
	check(not ms.consume("food"), "Game over impede consumo")
	print("SCIENCE / SURVIVAL CHECKS: %d failures" % failures)
	quit(0 if failures == 0 else 1)
