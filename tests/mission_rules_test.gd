extends SceneTree
## Regras da missão sem cenas longas: cotas, saltos, reserva de partida, decisões 95/5,
## janela da reentrada, causas do pouso e projeção do radar.
## Uso: godot --headless --path . --script tests/mission_rules_test.gd

var failures: Array[String] = []


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("FALHA: " + message)


func _initialize() -> void:
	call_deferred("run")


func ms() -> Node:
	return root.get_node("MissionState")


func fresh(food: float, water: float) -> void:
	ms().reset("normal")
	ms().food_days = food
	ms().water_days = water
	ms().day = 1


func play_day(day: int, food: int, water: int) -> void:
	ms().day = day
	for i in food:
		ms().consume("food")
	for i in water:
		ms().consume("water")
	ms().seal_day(day)


func run() -> void:
	TranslationServer.set_locale("pt_BR")
	root.get_node("Game").language = "pt_BR"
	root.get_node("MissionState").refresh_catalog_language()
	supplies()
	jumps()
	departure()
	decisions()
	await reentry_window()
	await landing_causes()
	radar()
	print("RULES CHECKS: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)


func supplies() -> void:
	fresh(8, 8)
	for d in [1, 2, 3]:
		play_day(d, 1, 1)
	ms().pay_jump("A")
	ms().pay_jump("B")
	check(ms().check_departure()["ok"] and is_equal_approx(ms().food_days, 3.0), "8/8 com consumo exato chega à partida com 3/3")
	for d in [4, 5]:
		play_day(d, 1, 1)
	ms().pay_jump("C")
	ms().landing_result = {"success": true}
	ms().science_completed = true
	ms().splashdown = true
	check(is_zero_approx(ms().food_days) and is_zero_approx(ms().water_days), "8/8 termina em 0/0")
	check(ms().verdict()["success"], "8/8 exato é sucesso")

	fresh(8, 8)
	play_day(1, 2, 1)
	check(ms().intake_on(1, "food") == 2 and is_equal_approx(ms().food_days, 6.0), "Comer duas vezes no dia é livre e debita duas cotas")
	for d in [2, 3]:
		play_day(d, 1, 1)
	ms().pay_jump("A")
	ms().pay_jump("B")
	var dep: Dictionary = ms().check_departure()
	check(not dep["ok"] and is_equal_approx(dep["deficits"]["food"], 1.0) and not dep["deficits"].has("water"), "Uma comida extra deixa 2/3 e bloqueia a partida por 1 comida")
	check(ms().departure_text() == "Havia 2 comidas e 3 águas. Faltou 1 comida.", "Texto da partida bloqueada (%s)" % ms().departure_text())

	fresh(8, 8)
	play_day(1, 1, 1)
	play_day(2, 1, 0)
	var issues: Array = ms().day_issues()
	check(issues.size() == 1 and issues[0] == "Dia 2 · Nenhuma água foi consumida, apesar de haver estoque.", "Pular a água com estoque vira falha diária (%s)" % str(issues))
	ms().pay_jump("A")
	ms().landing_result = {"success": true}
	# Um dia sem beber não reprova sozinho: quem decide são as barras de FOME e SEDE.
	check(not ms().verdict()["causes"].any(func(c): return c.contains("Nenhuma água")), "Falta diária não entra nas causas do veredito")

	fresh(0.5, 2)
	check(not ms().consume("food") and is_equal_approx(ms().food_days, 0.5) and ms().intake_on(1, "food") == 0, "Meia cota não pode ser consumida")
	var sealed: Dictionary = ms().seal_day(1)
	check("food" in sealed["no_stock"] and ms().day_issues()[0] == "Dia 1 · Faltou comida para o consumo diário.", "Sem estoque, a falta diária diz que faltou comida")
	check(ms().seal_day(1) == sealed, "Selar o mesmo dia duas vezes devolve o mesmo resultado")
	ms().consume("water")
	check(ms().intake_on(1, "water") == 1 and ms().sealed["1"]["water"] == 0, "Consumo depois do selo não reescreve o dia selado")

	fresh(3, 3)
	var lost: float = ms().lose("water", 5.0, "Teste")
	check(is_equal_approx(lost, 3.0) and is_zero_approx(ms().water_days) and is_equal_approx(ms().losses[0]["asked"], 5.0), "Perda nunca deixa o estoque negativo")
	fresh(8, 8)
	ms().landing_result = {"success": true}
	ms().science_completed = true
	ms().splashdown = true
	var partial: Dictionary = ms().verdict()
	check(not partial["success"] and not partial["causes"].is_empty() and partial["summary"].contains("incompleta"), "Missão sem os dias e saltos não vira sucesso nem quebra o veredito")
	check(ms().amount_text(2.5) == "2,5" and ms().amount_text(3.0) == "3", "Cotas aparecem com vírgula só quando fracionárias")


func jumps() -> void:
	fresh(1, 0.5)
	var preview: Dictionary = ms().jump_preview("A")
	check(not preview["ok"] and is_equal_approx(preview["deficits"]["water"], 0.5) and not preview["deficits"].has("food"), "Prévia do salto mostra só o déficit de água")
	var paid: Dictionary = ms().pay_jump("A")
	check(not paid["ok"] and is_equal_approx(ms().food_days, 1.0), "Salto sem água não cobra nada")
	check(ms().jump_text("A") == "Faltou 0,5 cota de água para avançar.", "Texto do salto bloqueado (%s)" % ms().jump_text("A"))
	check(ms().verdict()["causes"].any(func(c): return c.begins_with("Órbita lunar")), "Salto bloqueado entra nas causas do veredito")
	fresh(2, 2)
	ms().pay_jump("A")
	ms().pay_jump("A")
	check(is_equal_approx(ms().food_days, 1.0) and is_equal_approx(ms().jump_food, 1.0), "Salto repetido debita uma vez só")
	check(ms().events.filter(func(e): return e["id"] == "jump_A").size() == 1, "Salto repetido registra um evento só")


func departure() -> void:
	fresh(3, 2.5)
	var dep: Dictionary = ms().check_departure()
	check(not dep["ok"] and is_equal_approx(dep["deficits"]["water"], 0.5), "Reserva com 2,5 águas falta meia cota")
	ms().water_days = 9
	check(ms().check_departure() == dep, "A checagem da partida é feita uma vez só")
	fresh(3, 3)
	check(ms().check_departure()["ok"], "3/3 passa no limite exato")


func decision(option: int, roll: float) -> Dictionary:
	ms().reset("normal")
	ms().test_samples = [roll]
	return load("res://scripts/mission/mission_decisions.gd").apply("power", option, 0)


func decisions() -> void:
	var good_fav := decision(0, 0.10)
	check(good_fav["correct"] and good_fav["favorable"] and is_equal_approx(good_fav["chance"], 0.95), "Escolha boa com amostra 0,10 é favorável")
	var good_edge := decision(0, 0.949)
	check(good_edge["favorable"], "Escolha boa com 0,949 ainda é favorável")
	var good_bad := decision(0, 0.95)
	check(good_bad["correct"] and not good_bad["favorable"], "Escolha boa com 0,95 cai nos 5% desfavoráveis")
	var bad_fav := decision(2, 0.04)
	check(not bad_fav["correct"] and bad_fav["favorable"] and is_equal_approx(bad_fav["chance"], 0.05), "Escolha ruim com 0,04 tem sorte")
	var bad_bad := decision(2, 0.05)
	check(not bad_bad["correct"] and not bad_bad["favorable"], "Escolha ruim com 0,05 é desfavorável")
	var again: Dictionary = load("res://scripts/mission/mission_decisions.gd").apply("power", 0, 0)
	check(again == bad_bad and ms().decisions.size() == 1, "Decisão já resolvida não sorteia de novo")


func reentry_at(prepare: Callable) -> Node:
	var scene: Node = load("res://scenes/reentry/reentry.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.start()
	scene.phase = "drogue"
	scene.phase_time = 0.0
	prepare.call(scene)
	return scene


func open_window(scene: Node) -> void:
	scene.altitude = scene.TARGET + 0.001
	scene.step(0.001 / scene.DROGUE_RATE)


func reentry_window() -> void:
	ms().reset("normal")
	for wait in [0.0, 1.0, 1.999]:
		var scene: Node = await reentry_at(open_window)
		check(scene.phase == "window" and scene.window_time < 0.001, "Janela abre ao cruzar 3.050 m")
		if wait > 0.0:
			scene.step(wait)
		scene.press()
		check(scene.phase == "mains" and scene.result["success"], "Toque com %.3f s abre os principais" % wait)
		scene.queue_free()
	for wait in [2.0, 2.001]:
		var scene: Node = await reentry_at(open_window)
		scene.step(1.0)
		scene.step(wait - 1.0)
		check(scene.phase == "failed" and scene.result["code"] == "window_missed", "Com %.3f s a janela já fechou" % wait)
		scene.press()
		check(scene.phase == "failed", "Toque depois da janela não abre nada (%.3f s)" % wait)
		scene.queue_free()
	var early: Node = await reentry_at(func(s): s.altitude = s.TARGET + 500.0)
	early.press()
	check(early.phase == "drogue" and early.early_note > 0.0, "Toque antes da janela só mostra aviso")
	early.step(0.1)
	check(early.phase == "drogue", "Toque antes não conta como abertura")
	early.queue_free()
	var cross: Node = await reentry_at(func(s): s.altitude = s.TARGET + 10.0)
	cross.step(1.0)
	var expected: float = 1.0 - 10.0 / cross.DROGUE_RATE
	check(cross.phase == "window" and absf(cross.window_time - expected) < 0.001, "Cruzar 3.050 m no meio do quadro desconta o tempo já passado (%.3f)" % cross.window_time)
	cross.queue_free()
	var skip: Node = await reentry_at(func(s): s.altitude = s.TARGET + 10.0)
	skip.step(3.0)
	check(skip.phase == "failed", "Quadro de 3 s que passa por toda a janela reprova")
	skip.queue_free()
	await process_frame


func touchdown(vy: float, vh: float) -> Dictionary:
	var scene: Node = load("res://scenes/lunar_module/landing.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene._start()
	scene.pos = Vector3(0, 0, 0)
	scene.vel = Vector3(vh, -vy, 0)
	scene.tilt = Vector2.ZERO
	scene._touchdown()
	var attempt: Dictionary = scene.attempt
	scene.queue_free()
	await process_frame
	clear_radio()
	return attempt


func clear_radio() -> void:
	root.get_node("Houston").clear()


func landing_causes() -> void:
	ms().reset("normal")
	var probe: Node = load("res://scenes/lunar_module/landing.tscn").instantiate()
	root.add_child(probe)
	await process_frame
	var lim: Dictionary = probe.limits.duplicate()
	var all: Dictionary = probe.evaluate_values({"vy": 9.0, "vh": 9.0, "tilt": 30.0, "x": 300.0, "z": 0.0, "vx": 9.0, "vz": 0.0, "distance": 300.0, "fuel_out_alt": 12.0}, ["fuel", "area", "tilt", "lateral", "vertical"])
	check(all["causes"] == ["vertical", "lateral", "tilt", "area", "fuel"] and all["primary"] == "vertical", "Causas seguem a ordem fixa")
	check(all["reasons"].size() == 5 and all["tips"].size() == 5, "Cada causa tem motivo e dica")
	check(all["tips"][1].contains("para a direita") and all["tips"][3].contains("para a esquerda"), "Dicas apontam o deslizamento e a direção do alvo")
	probe.queue_free()
	await process_frame
	var vy_lim: float = lim["land_vy"]
	var vh_lim: float = lim["land_vh"]
	var at: Dictionary = await touchdown(vy_lim, 0.0)
	check(at["success"], "Exatamente no limite vertical ainda pousa")
	var over: Dictionary = await touchdown(vy_lim + 0.01, 0.0)
	check(not over["success"] and over["primary"] == "vertical", "0,01 m/s acima do limite vertical reprova")
	at = await touchdown(0.5, vh_lim)
	check(at["success"], "Exatamente no limite lateral ainda pousa (%s, %s)" % [str(at["causes"]), str(at["values"])])
	over = await touchdown(0.5, vh_lim + 0.01)
	check(over["causes"] == ["lateral"], "0,01 m/s acima do limite lateral reprova só por deslizamento")
	over = await touchdown(vy_lim + 1.0, vh_lim + 1.0)
	check(over["causes"] == ["vertical", "lateral"] and over["primary"] == "vertical", "Duas causas juntas têm a vertical como principal")
	check(ms().landing_history.size() == 5, "Cada toque registra uma tentativa no histórico")


func radar() -> void:
	var landing: GDScript = load("res://scripts/landing/landing_game.gd")
	check(landing.map_point(Vector3(10, 50, -20)) == Vector2(10, -20), "Mapa usa X para a direita e Z para baixo (frente para cima)")
	check(landing.direction_name(Vector2(0, -5)) == "para a frente" and landing.direction_name(Vector2(5, 0)) == "para a direita", "Nomes de direção do mapa")
	check(landing.direction_name(Vector2(-5, 5)) == "para trás e para a esquerda", "Direção diagonal")
	var r: Control = load("res://scripts/ui/landing_radar.gd").new()
	r.size = Vector2(170, 170)
	check(r.para_tela(Vector2.ZERO) == Vector2(85, 85), "O alvo fica no centro do radar")
	check(r.para_tela(Vector2(60, 0)).is_equal_approx(Vector2(162, 85)), "60 m à direita cai na borda direita")
	check(r.para_tela(Vector2(0, -30)).is_equal_approx(Vector2(85, 46.5)), "30 m à frente fica no meio para cima")
	r.free()
