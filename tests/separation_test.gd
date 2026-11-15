extends SceneTree
## Regras do painel de manobra: queima guiada da TLI, imprevistos e alavancas por QTE.
## Uso: godot --headless --path . --script tests/separation_test.gd

const DT := 1.0 / 60.0

var failures: Array[String] = []
var ms: Node
## Carregado em tempo de execução: o script depende dos autoloads.
var decisions: GDScript


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("FALHA: " + message)


func _initialize() -> void:
	call_deferred("run")


func open(difficulty: String, seed_value: int) -> Node:
	# Deixa terminar uma troca de cena pendente, como a da falha anterior.
	for i in 6:
		await process_frame
	ms.reset(difficulty)
	change_scene_to_file("res://scenes/minigames/separation.tscn")
	for i in 400:
		await process_frame
		if current_scene and current_scene.name == "Separation" and current_scene.phase == "intro":
			break
	var sep := current_scene
	sep.set_process(false)
	sep.rng.seed = seed_value
	return sep


## Piloto simples: empurra a mira de volta ao centro e silencia o alarme depois de 1 s.
func fly(sep: Node, steering: bool) -> void:
	var alarm_time := 0.0
	while sep.phase == "tli" and sep.velocity_kms < sep.target:
		var steer := Vector2.ZERO
		if steering:
			steer = -sep.attitude.normalized() * minf(1.0, sep.attitude.length() / 1.5)
			if sep.incident == "alarm":
				alarm_time += DT
				if alarm_time > 1.0:
					sep._reset_alarm()
		sep.step(DT, steer)


func run() -> void:
	ms = root.get_node("MissionState")
	decisions = load("res://scripts/mission/mission_decisions.gd")
	await guided_burn_is_flyable()
	await loose_attitude_costs()
	await burn_is_frame_rate_independent()
	await incidents()
	await guarded_switches()
	print("SEPARATION CHECKS: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)


## Com um piloto atento, a queima chega ao corte com desvio pequeno em todas as dificuldades.
func guided_burn_is_flyable() -> void:
	for difficulty in ["easy", "normal", "hard"]:
		var worst := 0.0
		var longest := 0.0
		for seed_value in [1, 2, 3, 4, 5, 6]:
			var sep: Node = await open(difficulty, seed_value)
			sep._start_tli()
			fly(sep, true)
			check(sep.phase == "tli", "Piloto atento não aborta (%s, semente %d, fase %s)" % [difficulty, seed_value, sep.phase])
			worst = maxf(worst, sep.mean_deviation())
			longest = maxf(longest, sep.burn_time)
			sep._cutoff()
			check(sep.phase == "sep", "Corte no alvo abre a separação (%s, semente %d)" % [difficulty, seed_value])
			check(ms.trajectory_error < decisions.SMALL_ERROR, "Piloto atento deixa desvio pequeno (%s, semente %d: %.0f%%)" % [difficulty, seed_value, ms.trajectory_error * 100.0])
		print("  %s: pior desvio médio %.2f°, queima de %.0f s" % [difficulty, worst, longest])
		check(longest > 20.0 and longest < 45.0, "Queima dura entre 20 e 45 s (%.1f s)" % longest)


## Sem segurar a atitude, a queima aborta ou custa trajetória.
func loose_attitude_costs() -> void:
	var aborted := 0
	for seed_value in [1, 2, 3, 4, 5, 6]:
		var sep: Node = await open("normal", seed_value)
		sep._start_tli()
		fly(sep, false)
		if sep.phase == "failed":
			aborted += 1
			check(ms.last_failure.get("title", "").contains("ATITUDE"), "Aborto por atitude é explicado (semente %d)" % seed_value)
		else:
			check(sep.attitude_error() > 0.0, "Atitude solta custa trajetória (semente %d, desvio médio %.1f°)" % [seed_value, sep.mean_deviation()])
		ms.last_failure = {}
	print("  sem comando: %d de 6 queimas abortadas" % aborted)
	check(aborted >= 3, "Atitude solta aborta a maioria das queimas (%d de 6)" % aborted)
	# O desvio médio entra no desvio de trajetória junto com o erro do corte.
	var sep: Node = await open("normal", 1)
	sep._start_tli()
	sep.velocity_kms = sep.target
	sep.burn_time = 10.0
	var free: float = sep.ATT_FREE["normal"]
	sep.deviation_sum = 10.0 * (free + (sep.ATT_FULL - free) * 0.5)
	sep._cutoff()
	check(absf(ms.trajectory_error - 0.5) < 0.01, "Desvio médio no meio da escala vale 50%% de desvio (%.2f)" % ms.trajectory_error)


func burn_is_frame_rate_independent() -> void:
	var reached := []
	for fps in [30.0, 120.0]:
		var sep: Node = await open("normal", 7)
		sep._start_tli()
		sep.incident_done = true
		for i in int(fps * 12.0):
			sep.step(1.0 / fps, Vector2.ZERO)
			sep.attitude = Vector2.ZERO
		reached.append(sep.velocity_kms)
	check(absf(reached[0] - reached[1]) < 0.01, "Velocidade após 12 s é a mesma a 30 e 120 FPS (%.3f e %.3f)" % [reached[0], reached[1]])


func incidents() -> void:
	for kind in ["alarm", "pogo", "static"]:
		var sep: Node = await open("normal", 3)
		sep._start_tli()
		sep.incident_kind = kind
		sep.incident_at = 0.0
		sep.step(DT, Vector2.ZERO)
		check(sep.incident == kind, "Imprevisto %s começa" % kind)
		if kind == "alarm":
			for i in 600:
				sep.step(DT, -sep.attitude.normalized())
			check(sep.incident == "alarm", "O alarme toca até ser silenciado")
			sep._reset_alarm()
		else:
			for i in 300:
				sep.step(DT, -sep.attitude.normalized())
		check(sep.incident == "" and sep.incident_done, "Imprevisto %s termina e não se repete" % kind)


## Executa o procedimento inteiro de uma alavanca, como o jogador: toques e teclas seguradas.
func run_procedure(sep: Node, index: int) -> void:
	for step in sep.PROCEDURES[index]:
		sep.qte_key(step[1], true)
		if step[2] == "hold":
			for i in 6:
				sep._update_qte(sep.HOLD_TIME / 5.0)
			sep.qte_key(step[1], false)


## Alavancas por QTE: escolher fora de ordem conta erro; tecla errada, tempo esgotado ou soltar
## cedo uma tecla segurada não acionam; o procedimento completo aciona a alavanca.
func guarded_switches() -> void:
	var sep: Node = await open("normal", 4)
	sep._start_tli()
	sep.velocity_kms = sep.target
	sep._cutoff()
	var window: float = sep.sep_time_left
	sep._process(1.0)
	check(sep.sep_time_left == window, "A janela de separação não corre durante o silêncio do corte")
	sep._process(2.0)
	sep._process(1.0)
	check(absf(sep.sep_time_left - (window - 1.0)) < 0.001, "Depois do silêncio, a janela corre")
	var first: int = sep._order.find(0)
	var last: int = sep._order.find(2)
	sep._press_switch(last)
	check(sep.qte_index == -1 and sep.sep_step == 0 and ms.separation_mistakes == 1, "Escolher a alavanca fora de ordem conta o erro e não abre o procedimento")
	sep._press_switch(first)
	check(sep.qte_index == 0 and sep.qte_step == 0, "A alavanca certa abre o procedimento SECS LOGIC")
	var steps: Array = sep.PROCEDURES[0]
	sep.qte_key(steps[0][1], true)
	sep.qte_key(steps[1][1], true)
	check(sep.qte_step == 2 and sep.lever[first] < 1.0, "Teclas certas avançam os passos")
	sep.qte_key(KEY_Z, true)
	check(sep.qte_step == 0 and ms.separation_mistakes == 2 and sep.qte_index == 0, "Tecla errada conta erro e recomeça o procedimento")
	sep.qte_key(KEY_1, true)
	sep.qte_key(KEY_SPACE, true)
	check(sep.qte_step == 0 and ms.separation_mistakes == 2, "Números e ESPAÇO não contam como tecla errada")
	sep._update_qte(sep._qte_time() + 1.0)
	check(sep.qte_step == 0 and ms.separation_mistakes == 3, "Tempo esgotado conta erro e recomeça")
	run_procedure(sep, 0)
	check(sep.sep_step == 1 and sep.qte_index == -1, "Procedimento completo aciona SECS LOGIC")
	sep._animate_levers(1.0)
	check(is_equal_approx(sep.lever[first], 1.0), "A alavanca acionada vai ao fim do curso")
	# Passo de segurar: soltar cedo zera a barra sem contar erro.
	var second: int = sep._order.find(1)
	sep._press_switch(second)
	var pyro: Array = sep.PROCEDURES[1]
	for i in 3:
		sep.qte_key(pyro[i][1], true)
	sep.qte_key(pyro[3][1], true)
	sep._update_qte(sep.HOLD_TIME * 0.5)
	sep.qte_key(pyro[3][1], false)
	check(sep.qte_step == 3 and sep.qte_hold == 0.0 and ms.separation_mistakes == 3, "Soltar cedo a tecla segurada zera a barra sem erro")
	sep.qte_key(pyro[3][1], true)
	for i in 6:
		sep._update_qte(sep.HOLD_TIME / 5.0)
	check(sep.sep_step == 2, "Segurar até encher aciona PYRO ARM")
	sep._press_switch(sep._order.find(2))
	run_procedure(sep, 2)
	check(sep.phase == "done", "As três alavancas concluem a separação")
	sep.skip_flight()
	check(sep._panel != null and sep._telemetry_shown, "Pular o voo até a Lua mostra a telemetria")
	sep._advance()
	sep._advance()
	for i in 200:
		await process_frame
		if current_scene and current_scene.name == "Cutscene":
			break
	check(current_scene != null and current_scene.name == "Cutscene" and ms.separation_attempts == 1, "CONTINUAR avança uma única vez (tentativas: %d)" % ms.separation_attempts)
