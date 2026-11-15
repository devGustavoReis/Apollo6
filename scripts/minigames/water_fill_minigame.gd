extends Control

signal terminou(acertou)

var nivel = 1
var folga = 0
var amplitudes = [90.0, 140.0, 190.0]
var ritmos = [0.9, 1.2, 1.6]
var encaixes = [34.0, 26.0, 20.0]
var faixas = [14.0, 10.0, 7.0]
var tempos = [50.0, 45.0, 40.0]
var alvo = 75.0
var vazao = 22.0
var limite_perda = 40.0
var agua = 0.0
var perdido = 0.0
var bico = 480.0
var valvula = 480.0
var botao = false
var tecla_livre = false
var parado = 0.0
var relogio = 0.0
var gotas = []
var tempo = 0.0
var motivo = ""
var acabou = false
var acertou = false
var espera = 1.5
var alerta = 0.0
var contador
var aviso


func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	size = Vector2(960, 540)
	tempo = tempos[nivel] + folga * 10
	var titulo = Game.make_label("ÁGUA · ABASTECER A BOLSA", 20, Game.AMBER)
	titulo.position = Vector2(16, 6)
	add_child(titulo)
	contador = Game.make_label("", 20, Color.WHITE)
	contador.position = Vector2(650, 6)
	add_child(contador)
	aviso = Game.make_label("", 15, Color.WHITE)
	aviso.position = Vector2(16, 33)
	add_child(aviso)
	var rodape = Game.make_label("Água fora da bolsa vira gotas flutuando pela cabine.", 15)
	rodape.position = Vector2(16, 510)
	add_child(rodape)
	atualizar_textos()
	centralizar()
	get_viewport().size_changed.connect(centralizar)


func centralizar():
	var tela = get_viewport_rect().size
	position = Vector2((tela.x - 960) / 2, 16)


func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		botao = event.pressed
	if event is InputEventMouseMotion:
		bico = clamp(event.position.x, 200, 760)


func _notification(what):
	if what == NOTIFICATION_PAUSED:
		botao = false


func aberto():
	if not Input.is_action_pressed("move_up"):
		tecla_livre = true
	return botao or (tecla_livre and Input.is_action_pressed("move_up"))


func encaixado():
	return abs(bico - valvula) < encaixes[nivel] + folga * 4


func encerrar(resultado, texto):
	acabou = true
	acertou = resultado
	motivo = texto


func passo(delta, aberto):
	tempo -= delta
	if aberto and encaixado():
		agua += vazao * delta
		parado = 0.0
	elif aberto:
		perdido += vazao * delta
		parado = 0.0
		alerta = 0.3
		if gotas.size() < 40:
			gotas.append(Vector2(bico - 20 + randf() * 40, 236))
	elif agua >= alvo - faixas[nivel]:
		parado += delta
	if agua > alvo + faixas[nivel]:
		encerrar(false, "A bolsa passou do limite e vazou. Voltando à cabine...")
	elif perdido >= limite_perda:
		encerrar(false, "Muita água escapou pela cabine. Voltando à cabine...")
	elif tempo <= 0:
		encerrar(false, "O tempo acabou. Voltando à cabine...")
	elif parado >= 1.0:
		encerrar(true, "Bolsa cheia na medida certa. Voltando à cabine...")


func _process(delta):
	if alerta > 0:
		alerta -= delta
	for i in range(gotas.size()):
		gotas[i] += Vector2(sin(relogio * 3 + i) * 12, -18) * delta
	if acabou:
		espera -= delta
		if espera <= 0:
			set_process(false)
			terminou.emit(acertou)
	else:
		relogio += delta
		valvula = 480 + sin(relogio * ritmos[nivel]) * amplitudes[nivel]
		bico = clamp(bico + Input.get_axis("ui_left", "ui_right") * 280 * delta, 200, 760)
		passo(delta, aberto())
	atualizar_textos()
	queue_redraw()


func atualizar_textos():
	contador.text = "TEMPO %d · PERDA %d%%" % [ceil(max(tempo, 0)), perdido / limite_perda * 100]
	contador.modulate = Game.GOOD
	if perdido > 0 or tempo < 10:
		contador.modulate = Game.WARN
	if acabou:
		aviso.text = motivo
		aviso.modulate = Game.BAD
		if acertou:
			aviso.modulate = Game.GOOD
	elif alerta > 0:
		aviso.text = "O bico está fora da válvula! A água está escapando."
		aviso.modulate = Game.BAD
	else:
		aviso.text = "Bico na válvula (mouse ou SETAS). Segure o clique ou ESPAÇO para encher. Solte na faixa verde."
		aviso.modulate = Game.CREAM


func _draw():
	var fonte = get_theme_default_font()
	draw_rect(Rect2(0, 0, 960, 540), Color(0.1, 0.11, 0.12))
	for x in range(0, 960, 120):
		draw_line(Vector2(x, 60), Vector2(x, 500), Color(1, 1, 1, 0.05), 2)
	var topo = 250.0
	var altura = 200.0
	var bolsa = Rect2(valvula - 75, topo, 150, altura)
	draw_rect(bolsa, Color(0.2, 0.22, 0.24))
	var cheio = altura * min(agua, 100) / 100
	draw_rect(Rect2(valvula - 75, topo + altura - cheio, 150, cheio), Color("3f8fd0"))
	var faixa_baixo = topo + altura - altura * (alvo - faixas[nivel]) / 100
	var faixa_cima = topo + altura - altura * (alvo + faixas[nivel]) / 100
	draw_rect(Rect2(valvula - 75, faixa_cima, 150, faixa_baixo - faixa_cima), Color(0.45, 0.9, 0.45, 0.3))
	draw_line(Vector2(valvula - 75, faixa_baixo), Vector2(valvula + 75, faixa_baixo), Game.GOOD, 2)
	draw_line(Vector2(valvula - 75, faixa_cima), Vector2(valvula + 75, faixa_cima), Game.BAD, 2)
	draw_rect(bolsa, Game.CREAM, false, 3)
	var cor_valvula = Game.AMBER
	if encaixado():
		cor_valvula = Game.GOOD
	draw_rect(Rect2(valvula - 14, topo - 16, 28, 16), cor_valvula)
	draw_arc(Vector2(valvula, topo - 8), encaixes[nivel] + folga * 4, 0, TAU, 32, Color(1, 1, 1, 0.25), 1.5)
	draw_string(fonte, Vector2(valvula - 75, topo + altura + 18), "BOLSA DE ÁGUA", HORIZONTAL_ALIGNMENT_CENTER, 150, 13, Game.CREAM)
	draw_line(Vector2(bico, 60), Vector2(bico, 150), Color(0.35, 0.36, 0.36), 10)
	draw_rect(Rect2(bico - 22, 140, 44, 60), Color(0.62, 0.63, 0.6))
	draw_rect(Rect2(bico - 22, 140, 44, 60), Color(0.25, 0.26, 0.25), false, 2)
	draw_rect(Rect2(bico - 7, 200, 14, 30), Color(0.8, 0.8, 0.76))
	if aberto() and not acabou:
		draw_rect(Rect2(bico - 3, 230, 6, 16), Color("7fc4f0"))
	for gota in gotas:
		draw_circle(gota, 4, Color("7fc4f0"))
	draw_rect(Rect2(850, 110, 44, 340), Color(0.07, 0.08, 0.08))
	draw_rect(Rect2(850, 110 + 340 - 340 * min(agua, 100) / 100, 44, 340 * min(agua, 100) / 100), Color("3f8fd0"))
	var medidor_baixo = 110 + 340 - 340 * (alvo - faixas[nivel]) / 100
	var medidor_cima = 110 + 340 - 340 * (alvo + faixas[nivel]) / 100
	draw_rect(Rect2(850, medidor_cima, 44, medidor_baixo - medidor_cima), Color(0.45, 0.9, 0.45, 0.35))
	draw_rect(Rect2(850, 110, 44, 340), Game.AMBER, false, 2)
	draw_string(fonte, Vector2(812, 100), "NÍVEL %d%%" % agua, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Game.CREAM)
	draw_string(fonte, Vector2(812, 470), "FAIXA VERDE", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Game.GOOD)
	draw_rect(Rect2(66, 110, 44, 340), Color(0.07, 0.08, 0.08))
	var perda = 340 * min(perdido / limite_perda, 1.0)
	draw_rect(Rect2(66, 110 + 340 - perda, 44, perda), Game.BAD)
	draw_rect(Rect2(66, 110, 44, 340), Game.AMBER, false, 2)
	draw_string(fonte, Vector2(28, 100), "ÁGUA PERDIDA", HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Game.CREAM)
	draw_rect(Rect2(0, 0, 960, 60), Color(0.06, 0.07, 0.065))
	draw_rect(Rect2(0, 500, 960, 40), Color(0.06, 0.07, 0.065))
	var borda = Game.AMBER
	if alerta > 0:
		borda = Game.BAD
	draw_rect(Rect2(0, 0, 960, 540), borda, false, 3)
