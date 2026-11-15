extends SceneTree
## Fome e sede: drenagem, consumo, sono sem comida, janela crítica por dificuldade, falas e derrota.
## Uso: godot --headless --path . --script tests/needs_test.gd

var failures: Array[String] = []
var ms: Node
var warnings: Array[String] = []


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("FALHA: " + message)


func _initialize() -> void:
	call_deferred("run")


## Missão nova já na cabine, com estoque e as duas barras cheias.
func fresh(level := "normal") -> void:
	ms.reset(level)
	ms.select_objective("camera")
	ms.set_qty("camera", 1)
	ms.apply_plan()
	ms.stage = "cabin"
	warnings.clear()


func run() -> void:
	TranslationServer.set_locale("pt_BR")
	root.get_node("Game").language = "pt_BR"
	root.get_node("MissionState").refresh_catalog_language()
	ms = root.get_node("MissionState")
	ms.need_warning.connect(func(kind): warnings.append(kind))
	drain_and_day()
	sleep_rules()
	critical_window()
	deadlines()
	game_over_rules()
	voice_rules()
	stock_and_duplicates()
	persistence()
	critical_by_difficulty()
	await cabin_flow()
	print("NEEDS CHECKS: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)


func drain_and_day() -> void:
	fresh()
	check(ms.nourishment == 100.0 and ms.hydration == 100.0, "Missão nova começa com 100% nas duas barras")
	var day_seconds: float = ms.NEEDS_DAY_SECONDS["normal"]
	ms.advance_survival(day_seconds)
	check(absf(ms.nourishment - 80.0) < 0.001 and absf(ms.hydration - 70.0) < 0.001, "Um dia jogável drena 20 de fome e 30 de sede (%.2f, %.2f)" % [ms.nourishment, ms.hydration])
	check(ms.ended.is_empty() and not ms.critical_wake_pending, "Passar um dia sem comer com as barras acima de zero não encerra a missão")
	# Mesma drenagem a 30 e a 120 quadros por segundo.
	var results := []
	for fps in [30.0, 120.0]:
		fresh()
		for i in int(fps * 60.0):
			ms.advance_survival(1.0 / fps)
		results.append(ms.nourishment)
	check(absf(results[0] - results[1]) < 0.001, "Drenagem igual a 30 e 120 FPS (%.4f e %.4f)" % results)
	fresh()
	ms.stage = "landing"
	ms.advance_survival(100.0)
	check(ms.nourishment == 100.0, "Fora da cabine as barras não drenam")


func sleep_rules() -> void:
	fresh("hard")
	check(ms.consume("water"), "Bebe no dia 1")
	ms.close_day_needs(1)
	check(ms.critical_wake_pending, "Dormir sem comer, mesmo tendo bebido, prepara o despertar crítico")
	ms.begin_wake()
	check(ms.nourishment == 5.0 and ms.hydration == 5.0, "Despertar crítico: fome e sede em 5%")
	check(ms.need_critical.has("food") and ms.need_critical.has("water"), "As duas barras entram na queda crítica")
	check(is_equal_approx(ms.critical_left("food"), 10.0), "A contagem começa em 10 s")

	fresh("hard")
	ms.hydration = 40.0
	check(ms.consume("food"), "Come no dia 1")
	ms.close_day_needs(1)
	ms.begin_wake()
	check(not ms.critical_wake_pending and ms.need_critical.is_empty() and ms.hydration == 40.0, "Dormir depois de comer, sem beber: sem urgência e a sede mantém o valor")

	fresh("hard")
	ms.hydration = 2.0
	ms.close_day_needs(1)
	ms.begin_wake()
	check(ms.hydration == 2.0 and ms.nourishment == 5.0, "O despertar crítico nunca aumenta uma barra que estava mais baixa")
	ms.advance_survival(5.0)
	check(is_equal_approx(ms.hydration, 1.0), "Começando em 2%%, a barra perde 0,2 ponto por segundo (%.3f)" % ms.hydration)
	ms.advance_survival(5.0)
	check(ms.ended.get("stage", "") == "survival", "Começando em 2%, zera em 10 s sem consumo")

	fresh("hard")
	ms.close_day_needs(1)
	ms.close_day_needs(1)
	ms.consume("food")
	check(ms.critical_wake_pending, "Uma comida depois de fechar o dia não apaga o dia já fechado")
	check(ms.intake_on(1, "food") == 1, "O consumo após fechar o dia é registrado normalmente")


func critical_window() -> void:
	# Exemplo da especificação: come aos 4 s e bebe aos 7 s.
	fresh("hard")
	ms.close_day_needs(1)
	ms.begin_wake()
	ms.advance_survival(4.0)
	check(is_equal_approx(ms.nourishment, 3.0), "Aos 4 s a fome está em 3%% (%.3f)" % ms.nourishment)
	ms.consume("food")
	check(is_equal_approx(ms.nourishment, 53.0) and not ms.need_critical.has("food"), "Comer aos 4 s leva a fome a 53% e encerra só a urgência dela")
	check(ms.need_critical.has("water") and is_equal_approx(ms.critical_left("water"), 6.0), "A sede segue com o prazo original")
	ms.advance_survival(3.0)
	check(is_equal_approx(ms.hydration, 1.5), "Aos 7 s a sede está em 1,5%% (%.3f)" % ms.hydration)
	ms.consume("water")
	check(is_equal_approx(ms.hydration, 51.5) and ms.need_critical.is_empty(), "Beber aos 7 s leva a sede a 51,5%")
	ms.advance_survival(30.0)
	check(ms.ended.is_empty(), "Comendo e bebendo a tempo, o jogador sobrevive")
	check(absf(ms.nourishment - (53.0 - ms.need_rate("food") * 33.0)) < 0.01, "A fome volta à drenagem normal depois de comer")

	# Ordem inversa: bebe primeiro.
	fresh("hard")
	ms.close_day_needs(1)
	ms.begin_wake()
	ms.advance_survival(2.0)
	ms.consume("water")
	ms.advance_survival(2.0)
	ms.consume("food")
	check(ms.ended.is_empty() and ms.need_critical.is_empty(), "Beber antes de comer também resolve")

	# Come e não bebe.
	fresh("hard")
	ms.close_day_needs(1)
	ms.begin_wake()
	ms.advance_survival(4.0)
	ms.consume("food")
	ms.advance_survival(6.0)
	check(ms.ended.get("stage", "") == "survival" and ms.ended["needs"] == ["water"], "Comer sem beber: a sede zera aos 10 s e encerra a missão")


func deadlines() -> void:
	fresh("hard")
	ms.close_day_needs(1)
	ms.begin_wake()
	ms.advance_survival(9.9)
	check(ms.hydration > 0.0 and ms.ended.is_empty(), "Aos 9,9 s a barra ainda é positiva")
	check(ms.consume("water") and is_equal_approx(ms.hydration, 50.05), "Consumir aos 9,9 s aplica a recuperação (%.3f)" % ms.hydration)

	fresh("hard")
	ms.close_day_needs(1)
	ms.begin_wake()
	ms.advance_survival(10.0)
	var food: float = ms.food_days
	check(ms.ended.get("stage", "") == "survival", "Aos 10 s exatos as barras chegam a zero")
	check(not ms.consume("food") and ms.food_days == food and ms.nourishment == 0.0, "Confirmar o consumo quando a barra chegou a zero: o Game Over prevalece")


func game_over_rules() -> void:
	fresh()
	ms.nourishment = 0.01
	ms.advance_survival(1.0)
	check(ms.ended.get("stage", "") == "survival" and ms.ended["needs"] == ["food"], "Zerar a fome no jogo normal encerra na hora, sem depender do sono")
	check(ms.ended["reason"].contains("A fome chegou a zero"), "O motivo diz que a fome zerou")

	fresh()
	ms.nourishment = 0.01
	ms.hydration = 0.01
	var changes := [0]
	var counter := func(): changes[0] += 1
	ms.changed.connect(counter)
	ms.advance_survival(1.0)
	ms.advance_survival(1.0)
	ms.changed.disconnect(counter)
	check(ms.ended["needs"].size() == 2 and ms.ended["reason"].contains("juntas"), "As duas zeradas juntas: um único encerramento com as duas no motivo")
	check(changes[0] == 1, "O encerramento roda uma vez (%d)" % changes[0])
	var survival_causes := 0
	for cause in ms.verdict()["causes"]:
		if cause.contains("chegaram a zero"):
			survival_causes += 1
	check(survival_causes == 1, "O relatório mostra o motivo uma vez")

	# A antiga regra de dia sem comer não reprova mais.
	fresh()
	ms.seal_day(1)
	check(not ms.day_issues().is_empty(), "O dia sem consumo continua registrado no relatório de suprimentos")
	check(ms.verdict()["causes"].all(func(c): return not c.contains("Nenhuma ração")), "Dia sem comer não entra nas causas de derrota")


func voice_rules() -> void:
	fresh()
	ms.nourishment = 25.0
	ms._check_needs()
	check(warnings.is_empty(), "Em 25,0% exatos não há fala")
	ms.nourishment = 24.9
	ms._check_needs()
	ms._check_needs()
	check(warnings == ["food"], "Ao cruzar para 24,9%% a fala dispara uma vez (%s)" % str(warnings))
	ms.consume("food")
	ms.nourishment = 24.0
	ms._check_needs()
	check(warnings == ["food", "food"], "Recuperar e cruzar de novo pede nova fala")

	fresh()
	ms.nourishment = 30.0
	ms.hydration = 30.0
	ms._check_needs()
	ms.nourishment = 20.0
	ms.hydration = 20.0
	ms._check_needs()
	check(warnings == ["food", "water"], "As duas cruzam juntas: fome primeiro, sede depois (%s)" % str(warnings))

	fresh()
	ms.close_day_needs(1)
	ms.begin_wake()
	check(warnings == ["food", "water"], "O despertar crítico também dispara as duas falas")
	fresh()
	ms.nourishment = 10.0
	ms._check_needs()
	ms.close_day_needs(1)
	ms.begin_wake()
	check(warnings == ["food", "water"], "Barra que já estava abaixo de 25%% não repete a fala ao acordar (%s)" % str(warnings))


func stock_and_duplicates() -> void:
	fresh()
	ms.food_days = 0.0
	ms.nourishment = 40.0
	check(not ms.consume("food") and ms.nourishment == 40.0 and ms.intake_on(1, "food") == 0, "Sem estoque: nada muda")
	fresh()
	ms.nourishment = 40.0
	var stock: float = ms.food_days
	var token: int = ms.reserve_supply("food")
	check(ms.consume_supply_token(token), "Primeira confirmação consome")
	check(not ms.consume_supply_token(token), "Segunda confirmação do mesmo consumo é ignorada")
	check(ms.food_days == stock - 1.0 and ms.nourishment == 90.0 and ms.intake_on(1, "food") == 1, "Estoque, barra e registro contam um consumo só")
	ms.nourishment = 80.0
	ms.consume("food")
	check(ms.nourishment == 100.0, "Em 80%, uma comida leva a 100% e o excedente é descartado")


func persistence() -> void:
	fresh("hard")
	ms.close_day_needs(1)
	ms.begin_wake()
	ms.advance_survival(3.0)
	ms.save_checkpoint("needs")
	ms.advance_survival(5.0)
	ms.restore_checkpoint("needs")
	check(is_equal_approx(ms.critical_left("food"), 7.0) and is_equal_approx(ms.nourishment, 3.5), "Checkpoint preserva o prazo crítico e o valor das barras")


## Caminho real da cabine: descansar sem ter comido, acordar crítico, falas e Game Over.
func critical_by_difficulty() -> void:
	var expected := {"easy": 20.0, "normal": 15.0, "hard": 10.0}
	for level: String in expected:
		fresh(level)
		ms.close_day_needs(1)
		ms.begin_wake()
		check(is_equal_approx(ms.critical_left("food"), expected[level]), "%s: a contagem crítica começa em %d s" % [level, int(expected[level])])
		ms.advance_survival(expected[level] - 0.1)
		check(ms.ended.is_empty() and ms.nourishment > 0.0, "%s: a barra ainda é positiva antes do prazo" % level)
		ms.advance_survival(0.1)
		check(ms.ended.get("stage", "") == "survival", "%s: a barra zera exatamente no prazo" % level)
		check(ms.ended["reason"].contains("estado crítico"), "%s: o Game Over explica o despertar crítico" % level)


func cabin_flow() -> void:
	fresh()
	ms.day = 1
	ms.tasks_done = {"1:lifesupport": true, "1:nav": true}
	ms.consume("water")
	change_scene_to_file(root.get_node("Game").SCENES["cabin"])
	for i in 300:
		await process_frame
		if current_scene and current_scene.name == "CabinGame":
			break
	var cabin: Node = current_scene
	for i in 5:
		await process_frame
	var houston: Node = root.get_node("Houston")
	houston.clear()
	cabin.interact("rest")
	cabin.hud._on_modal_button(0)
	for i in 600:
		await process_frame
		if not cabin.player.frozen and ms.day == 2:
			break
	check(ms.day == 2 and not ms.need_critical.is_empty(), "Descansar sem comer pela cabine acorda o jogador no estado crítico")
	var lines := []
	if not houston._current.is_empty():
		lines.append(houston._current["pt"])
	for entry in houston._queue:
		lines.append(entry["pt"])
	await process_frame
	check(cabin.hud.critical_visible(), "Despertar crítico mostra o aviso de GAME OVER")
	check(cabin.hud.critical_text().contains("GAME OVER") and cabin.hud.critical_text().contains("15 SEGUNDOS"), "O aviso cita GAME OVER e o prazo da dificuldade (%s)" % cabin.hud.critical_text())
	check(cabin.hud._critical.mouse_filter == Control.MOUSE_FILTER_IGNORE and not paused, "O aviso não bloqueia cliques nem pausa o jogo")
	check(lines.has("Estou com fome") and lines.has("Estou com sede") and lines.find("Estou com fome") < lines.find("Estou com sede"), "Falas na fila do rádio, fome antes de sede (%s)" % str(lines))
	# Pausa: o prazo crítico fica parado.
	var left: float = ms.critical_left("water")
	paused = true
	await create_timer(11.0, true).timeout
	check(absf(ms.critical_left("water") - left) < 0.05, "Pausa de 11 s reais preserva o tempo crítico (%.2f → %.2f)" % [left, ms.critical_left("water")])
	paused = false
	var before: float = ms.critical_left("water")
	for i in 100:
		await create_timer(0.25).timeout
		if not ms.ended.is_empty():
			break
	check(ms.critical_left("water") < before or not ms.ended.is_empty(), "Sem pausa o prazo crítico corre (%.2f → %.2f, modal %s, frozen %s)" % [before, ms.critical_left("water"), cabin.hud.modal_open(), cabin.player.frozen])
	check(ms.ended.get("stage", "") == "survival", "Sem comer nem beber, a janela termina em Game Over")
	await process_frame
	check(cabin.hud.modal_open() and houston._queue.is_empty(), "Game Over abre o aviso e limpa as falas pendentes")
	houston.clear()
