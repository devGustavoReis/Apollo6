extends SceneTree

var failures: Array[String] = []
var respostas = []


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("FALHA: " + message)


func _initialize() -> void:
	call_deferred("run")


func abrir(cena: String, nivel: int, folga := 0) -> Node:
	var minigame: Node = load("res://scenes/minigames/" + cena + ".tscn").instantiate()
	minigame.nivel = nivel
	minigame.folga = folga
	respostas = []
	minigame.terminou.connect(func(acertou): respostas.append(acertou))
	root.add_child(minigame)
	# A prova da condição inicial do M03 precede o primeiro avanço de deriva.
	if cena == "antenna_minigame":
		minigame.set_process(false)
	await process_frame
	return minigame


func fechar(minigame: Node) -> void:
	minigame.espera = 0.0
	minigame.set_process(true)
	for i in 5:
		await process_frame
	minigame.queue_free()
	await process_frame


func run() -> void:
	await objetos_soltos()
	await bolsa_de_agua()
	await antena()
	await conector_do_traje()
	await descanso()
	await embalagens()
	print("MINIGAME CHECKS: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)


func objetos_soltos() -> void:
	var totais := []
	var tempos := []
	for nivel in 3:
		var m: Node = await abrir("loose_objects_minigame", nivel)
		totais.append(m.posicoes.size())
		tempos.append(m.tempo)
		for i in m.posicoes.size():
			m.pegar(m.posicoes[i])
			check(m.na_mao == i, "M01 nível %d: clicar no objeto %d pega o objeto" % [nivel, i])
			m.soltar(m.alvos[i])
		check(m.acabou and m.acertou, "M01 nível %d: prender tudo conclui" % nivel)
		await fechar(m)
		check(respostas == [true], "M01 nível %d: sinal de acerto emitido uma vez" % nivel)
	check(totais[0] < totais[1] and totais[1] < totais[2], "M01: mais objetos nas dificuldades maiores")
	check(tempos[0] > tempos[1] and tempos[1] > tempos[2], "M01: menos tempo nas dificuldades maiores")
	var m: Node = await abrir("loose_objects_minigame", 1)
	m.pegar(m.posicoes[0])
	m.soltar(m.alvos[1])
	check(not m.presos[0] and m.na_mao == -1, "M01: velcro errado não prende o objeto")
	m.posicoes[0] = Vector2(480, 200)
	m.direcoes[0] = Vector2(0, -300)
	for i in 60:
		m.flutuar(0, 0.016)
	check(m.batidas >= 1 and m.posicoes[0].y > m.painel.end.y, "M01: objeto que chega ao painel conta batida e volta")
	m.batidas = m.limites[1] + 1
	m._process(0.016)
	check(m.acabou and not m.acertou, "M01: batidas demais encerram com erro")
	await fechar(m)
	check(respostas == [false], "M01: sinal de erro emitido uma vez")
	m = await abrir("loose_objects_minigame", 1, 2)
	check(m.tempo > tempos[1], "M01: nova tentativa após erro ganha mais tempo")
	m.tempo = 0.0
	m._process(0.016)
	check(m.acabou and not m.acertou, "M01: tempo esgotado encerra com erro")
	await fechar(m)


func bolsa_de_agua() -> void:
	var faixas := []
	for nivel in 3:
		var m: Node = await abrir("water_fill_minigame", nivel)
		faixas.append(m.faixas[nivel])
		m.bico = m.valvula
		check(m.encaixado(), "M02 nível %d: bico sobre a válvula encaixa" % nivel)
		while not m.acabou and m.agua < m.alvo:
			m.passo(0.05, true)
		check(not m.acabou and is_zero_approx(m.perdido), "M02 nível %d: encher encaixado não perde água" % nivel)
		for i in 25:
			m.passo(0.05, false)
		check(m.acabou and m.acertou, "M02 nível %d: parar na faixa verde conclui" % nivel)
		await fechar(m)
		check(respostas == [true], "M02 nível %d: sinal de acerto emitido uma vez" % nivel)
	check(faixas[0] > faixas[1] and faixas[1] > faixas[2], "M02: faixa verde menor nas dificuldades maiores")
	var m: Node = await abrir("water_fill_minigame", 1)
	m.bico = m.valvula + 200.0
	for i in 100:
		m.passo(0.05, true)
	check(m.acabou and not m.acertou and is_zero_approx(m.agua), "M02: encher fora da válvula perde a água e encerra com erro")
	await fechar(m)
	check(respostas == [false], "M02: sinal de erro emitido uma vez")
	m = await abrir("water_fill_minigame", 1)
	m.bico = m.valvula
	for i in 200:
		if not m.acabou:
			m.passo(0.05, true)
	check(m.acabou and not m.acertou and m.agua > m.alvo + m.faixas[1], "M02: passar da faixa transborda e encerra com erro")
	await fechar(m)
	m = await abrir("water_fill_minigame", 1)
	m.agua = 30.0
	for i in 40:
		m.passo(0.05, false)
	check(not m.acabou, "M02: parar abaixo da faixa não conclui")
	m.tempo = 0.01
	m.passo(0.05, false)
	check(m.acabou and not m.acertou, "M02: tempo esgotado encerra com erro")
	await fechar(m)


func antena() -> void:
	var raios := []
	for nivel in 3:
		var m: Node = await abrir("antenna_minigame", nivel)
		raios.append(m.raio())
		check(m.terra.distance_to(m.mira) >= 140.0 and m.sinal < 0.5, "M03 nível %d: começa longe do sinal" % nivel)
		var longe: float = m.sinal
		m.mira = m.terra + Vector2(60, 0)
		m.passo(0.01, Vector2.ZERO)
		check(m.sinal > longe and m.subindo, "M03 nível %d: chegar perto aumenta o sinal" % nivel)
		for i in 25:
			m.mira = m.terra
			m.passo(0.1, Vector2.ZERO)
		check(m.acabou and m.acertou, "M03 nível %d: segurar no sinal trava a antena" % nivel)
		await fechar(m)
		check(respostas == [true], "M03 nível %d: sinal de acerto emitido uma vez" % nivel)
	check(raios[0] > raios[1] and raios[1] > raios[2], "M03: área de trava menor nas dificuldades maiores")
	var m: Node = await abrir("antenna_minigame", 1)
	m.mira = m.area.get_center()
	var antes: Vector2 = m.mira
	m.passo(0.5, Vector2(1, 0))
	check(is_equal_approx(m.mira.x, antes.x + 85.0), "M03: a antena anda na direção pedida")
	m.terra = Vector2(m.area.end.x - 31.0, m.area.get_center().y)
	m.rumo = Vector2.RIGHT
	m.passo(10.0, Vector2(1, 1))
	check(m.area.grow(0.01).has_point(m.mira), "M03: a mira não sai do visor")
	check(m.area.grow(-29.99).has_point(m.terra) and m.rumo.x < 0.0,
		"M03: deriva longa rebate mantendo o alvo alcançável")
	var eixo: Vector2 = m.refletir_eixo(99.0, 1.0, 0.0, 100.0, 302.0)
	check(eixo.is_equal_approx(Vector2(1.0, 1.0)), "M03: reflete várias bordas com direção correta")
	m.rumo = Vector2.ZERO
	m.mira = m.terra
	m.passo(0.5, Vector2.ZERO)
	var travado: float = m.trava
	m.mira = m.terra + Vector2(200, 0) if m.terra.x < 250.0 else m.terra - Vector2(200, 0)
	m.passo(0.1, Vector2.ZERO)
	check(travado > 0.0 and is_zero_approx(m.trava), "M03: sair do sinal desfaz a trava")
	m.mira = m.terra
	m.passo(1.9, Vector2.ZERO)
	check(not m.acabou and m.trava < 2.0, "M03: reentrada exige dois segundos contínuos")
	m.tempo = 0.01
	m.passo(0.05, Vector2.ZERO)
	check(m.acabou and not m.acertou, "M03: tempo esgotado encerra com erro")
	await fechar(m)
	check(respostas == [false], "M03: sinal de erro emitido uma vez")


func conector_do_traje() -> void:
	var folgas := []
	for nivel in 3:
		var m: Node = await abrir("suit_connector_minigame", nivel)
		folgas.append(m.tolerancias[nivel])
		check(not m.alinhado(), "M04 nível %d: começa desalinhado" % nivel)
		m.angulo = m.encaixe
		check(m.alinhado(), "M04 nível %d: travas sobre os encaixes alinham" % nivel)
		m.empurrar()
		check(m.etapa == 1 and not m.acabou and not m.alinhado(), "M04 nível %d: primeira mangueira presa, segunda desalinhada" % nivel)
		m.angulo = m.encaixe + 120.0
		m.empurrar()
		check(m.acabou and m.acertou and m.erros == 0, "M04 nível %d: duas mangueiras concluem" % nivel)
		await fechar(m)
		check(respostas == [true], "M04 nível %d: sinal de acerto emitido uma vez" % nivel)
	check(folgas[0] > folgas[1] and folgas[1] > folgas[2], "M04: tolerância menor nas dificuldades maiores")
	var m: Node = await abrir("suit_connector_minigame", 1)
	m.derivas = [0.0, 0.0, 0.0]
	var antes: float = m.angulo
	m.passo(1.0, 1.0)
	check(is_equal_approx(m.angulo, antes + 110.0), "M04: girar muda o ângulo do conector")
	m.angulo = m.encaixe + 60.0
	for i in m.limites[1]:
		m.empurrar()
	check(not m.acabou and m.erros == m.limites[1], "M04: erros dentro do limite não encerram")
	m.empurrar()
	check(m.acabou and not m.acertou, "M04: empurrar desalinhado demais encerra com erro")
	await fechar(m)
	check(respostas == [false], "M04: sinal de erro emitido uma vez")
	m = await abrir("suit_connector_minigame", 1)
	m.tempo = 0.01
	m.passo(0.05, 0.0)
	check(m.acabou and not m.acertou, "M04: tempo esgotado encerra com erro")
	await fechar(m)


func descanso() -> void:
	var totais := []
	for nivel in 3:
		var m: Node = await abrir("rest_prep_minigame", nivel)
		totais.append(m.velcros.size())
		check(is_equal_approx(m.luz(), 100.0), "M05 nível %d: começa com toda a luz" % nivel)
		m.clicar(Vector2(480, 120))
		check(is_equal_approx(m.luz(), 100.0), "M05 nível %d: clicar no vazio não faz nada" % nivel)
		for ponto in m.velcros:
			m.clicar(ponto)
		check(m.luz() < 100.0 and not m.acabou, "M05 nível %d: janelas fechadas ainda deixam as lâmpadas" % nivel)
		for ponto in m.luzes:
			m.clicar(ponto)
		check(m.acabou and m.acertou and is_zero_approx(m.luz()), "M05 nível %d: cabine escura conclui" % nivel)
		await fechar(m)
		check(respostas == [true], "M05 nível %d: sinal de acerto emitido uma vez" % nivel)
	check(totais[0] < totais[1] and totais[1] < totais[2], "M05: mais pontos de velcro nas dificuldades maiores")
	var m: Node = await abrir("rest_prep_minigame", 1)
	m.clicar(m.velcros[0])
	m.proxima = 0.01
	m.passo(0.05)
	check(not m.presos[0] and m.alerta > 0.0, "M05: no normal, um velcro preso pode soltar")
	m.tempo = 0.01
	m.passo(0.05)
	check(m.acabou and not m.acertou, "M05: tempo esgotado encerra com erro")
	await fechar(m)
	check(respostas == [false], "M05: sinal de erro emitido uma vez")
	m = await abrir("rest_prep_minigame", 0)
	for ponto in m.velcros:
		m.clicar(ponto)
	for i in 400:
		m.passo(0.05)
	check(m.presos.count(false) == 0, "M05: no fácil, o velcro não solta sozinho")
	await fechar(m)


func embalagens() -> void:
	var solucoes := [
		[Vector2(0, 0), Vector2(2, 0), Vector2(2, 1), Vector2(3, 1)],
		[Vector2(0, 0), Vector2(0, 2), Vector2(3, 1), Vector2(2, 0)],
		[Vector2(0, 0), Vector2(0, 2), Vector2(3, 1), Vector2(2, 0), Vector2(2, 1)],
	]
	var areas := []
	for nivel in 3:
		var m: Node = await abrir("meal_stowage_minigame", nivel)
		var area := 0.0
		for i in m.tamanhos.size():
			area += m.tamanhos[i].x * m.tamanhos[i].y
			m.pegar(m.caixa(i).get_center())
			check(m.na_mao == i, "M06 nível %d: clicar na embalagem %d pega a embalagem" % [nivel, i])
			m.soltar(m.origem + (solucoes[nivel][i] + m.tamanhos[i] / 2.0) * m.celula)
			check(m.casas[i] == solucoes[nivel][i], "M06 nível %d: embalagem %d entra na casa certa" % [nivel, i])
		areas.append(area)
		check(m.acabou and m.acertou, "M06 nível %d: guardar tudo conclui" % nivel)
		await fechar(m)
		check(respostas == [true], "M06 nível %d: sinal de acerto emitido uma vez" % nivel)
	check(areas[0] < areas[1] and areas[1] < areas[2] and areas[2] <= 12.0, "M06: a bolsa fica mais cheia nas dificuldades maiores")
	var m: Node = await abrir("meal_stowage_minigame", 1)
	m.pegar(m.caixa(0).get_center())
	m.soltar(m.origem + Vector2(1, 1) * m.celula)
	check(m.casas[0] == Vector2(0, 0), "M06: a embalagem encaixa na grade")
	m.pegar(m.caixa(1).get_center())
	m.soltar(m.origem + Vector2(2, 1.5) * m.celula)
	check(m.casas[1].x < 0 and m.alerta > 0.0, "M06: embalagem sobre outra volta para a bandeja")
	m.pegar(m.caixa(2).get_center())
	m.soltar(Vector2(200, 300))
	check(m.casas[2].x < 0, "M06: soltar fora da bolsa não guarda")
	m.pegar(m.caixa(0).get_center())
	check(m.na_mao == 0 and m.casas[0].x < 0 and m.guardadas() == 0, "M06: dá para tirar uma embalagem já guardada")
	m.soltar(Vector2(200, 300))
	m.tempo = 0.01
	m._process(0.05)
	check(m.acabou and not m.acertou, "M06: tempo esgotado encerra com erro")
	await fechar(m)
	check(respostas == [false], "M06: sinal de erro emitido uma vez")
