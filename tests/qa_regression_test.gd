extends SceneTree
## Regressões da bateria de QA de 15/11: cada verificação falha na versão 4f72643
## e passa com as correções.
## Uso: godot --headless --path . --script res://tests/qa_regression_test.gd

var failures: Array[String] = []
var checks := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("FALHA: " + message)


func _initialize() -> void:
	call_deferred("run")


func plan(ms: Node, diff := "normal") -> void:
	ms.reset(diff)
	ms.select_objective("sample_kit")
	ms.set_qty("sample_kit", 1)
	ms.apply_plan()


func run() -> void:
	var ms: Node = root.get_node("MissionState")
	var game: Node = root.get_node("Game")
	await process_frame

	# QA-001: o texto do saldo nunca arredonda para uma cota inteira inexistente.
	check(ms.amount_text(0.99) == "0,9", "0,99 cota aparece como 0,9 (era 1,0)")
	check(ms.amount_text(2.99) == "2,9", "2,99 cotas aparecem como 2,9 (era 3)")
	check(ms.amount_text(3.0) == "3" and ms.amount_text(0.5) == "0,5", "Inteiros e meios inalterados")
	check(ms.amount_text(0.01, true) == "0,1", "Falta de 0,01 aparece como 0,1, nunca 0")

	# QA-002: salto com saldo dentro da tolerância não deixa estoque negativo.
	plan(ms)
	ms.food_days = 1.0 - 0.00005
	ms.water_days = 1.0
	ms.day = 3
	var paid: Dictionary = game.confirm_jump("A")
	check(paid["ok"] and ms.food_days >= 0.0, "Estoque após o salto nunca fica negativo (%.6f)" % ms.food_days)

	# QA-003: num quadro longo, a causa é a barra que zerou primeiro.
	plan(ms)
	ms.stage = "cabin"
	ms.nourishment = 10.0
	ms.hydration = 20.0
	ms.advance_survival(400.0)
	check(ms.ended.get("needs", []) == ["food"], "Quadro longo: só a fome zerou primeiro (%s)" % str(ms.ended.get("needs", [])))
	plan(ms)
	ms.stage = "cabin"
	ms.nourishment = 10.0
	ms.hydration = 15.0
	ms.advance_survival(400.0)
	check(ms.ended.get("needs", []).size() == 2, "Zerar juntas continua registrando as duas causas")

	# QA-004: sem reserva para a volta, nenhuma queima de partida é registrada.
	plan(ms)
	ms.food_days = 3.5
	ms.water_days = 5.0
	ms.day = 3
	game.confirm_jump("B")
	check(not ms.departure["ok"], "Reserva 2,5/4 bloqueia a partida")
	check(not ms.events.any(func(e): return e["id"] == "tei") and is_equal_approx(ms.sps_fuel, 100.0), "Sem partida, sem queima nem gasto de propelente")
	plan(ms)
	ms.food_days = 5.0
	ms.water_days = 5.0
	game.confirm_jump("B")
	check(ms.departure["ok"] and ms.events.any(func(e): return e["id"] == "tei"), "Com reserva, a queima de partida acontece")

	# QA-005: contato com o solo avaliado no instante do toque, independente do passo.
	for dt in [1.0, 1.0 / 480.0]:
		plan(ms)
		ms.stage = "landing"
		ms.last_failure = {}
		var l: Node = load("res://scenes/lunar_module/landing.tscn").instantiate()
		root.add_child(l)
		await process_frame
		l.set_physics_process(false)
		l.state = "flying"
		var v0 := 2.0
		var v_contact := 2.48
		l.pos = Vector3(0, (v_contact * v_contact - v0 * v0) / (2.0 * 1.62), 0)
		l.vel = Vector3(0, -v0, 0)
		l.throttle = 0.0
		var guard := 0
		while l.state == "flying" and guard < 10000:
			l.step(dt, 0.0, Vector2.ZERO)
			guard += 1
		var vy: float = l.attempt.get("values", {}).get("vy", -1.0)
		check(l.state == "landed" and absf(vy - v_contact) < 0.01, "Contato a 2,48 m/s aprovado com passo %.4f s (vy %.3f)" % [dt, vy])
		# QA-006: os timers do resultado são filhos da cena.
		check(l.get_children().any(func(n): return n is Timer), "Timer do resultado pertence à cena do pouso")
		var stage_before: String = ms.stage
		l.queue_free()
		await create_timer(0.1).timeout
		if dt == 1.0:
			await create_timer(maxf(4.5, root.get_node("Houston").radio_time_remaining() + 0.5)).timeout
			check(ms.stage == stage_before, "Sair da cena antes do timer não dispara a transição antiga")

	# QA-007: perder o foco congela pouso e cabine; segurar no QTE não completa sozinho.
	plan(ms)
	ms.stage = "landing"
	var l2: Node = load("res://scenes/lunar_module/landing.tscn").instantiate()
	root.add_child(l2)
	await process_frame
	l2.state = "flying"
	l2._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(paused, "Pouso fora de foco pausa a simulação")
	l2._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not paused, "Pouso retoma quando o foco volta")
	l2.queue_free()
	await process_frame
	plan(ms)
	var sep: Node = load("res://scenes/minigames/separation.tscn").instantiate()
	root.add_child(sep)
	await process_frame
	sep.set_process(false)
	sep.phase = "sep"
	for p in sep.PROCEDURES.size():
		for i in sep.PROCEDURES[p].size():
			if sep.PROCEDURES[p][i][2] == "hold" and sep.qte_index < 0:
				sep.sep_step = p
				sep.qte_index = p
				sep.qte_step = i
	var hold_step: int = sep.qte_step
	var proc: int = sep.qte_index
	sep.qte_time_left = 10.0
	sep.qte_key(sep.PROCEDURES[sep.qte_index][hold_step][1], true)
	sep._update_qte(0.5)
	sep._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	sep._update_qte(0.5)
	check(sep.qte_step == hold_step and sep.qte_index == proc and not sep.qte_holding and sep.qte_hold == 0.0, "Perder o foco no meio do segurar zera a barra e não avança")
	sep._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	sep.queue_free()
	await process_frame
	paused = false

	print("QA REGRESSION CHECKS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
