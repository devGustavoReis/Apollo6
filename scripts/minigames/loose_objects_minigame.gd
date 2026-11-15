extends Control

signal terminou(acertou)

var nivel = 1
var folga = 0
var quantidades = [4, 5, 6]
var velocidades = [45.0, 60.0, 80.0]
var tempos = [60.0, 50.0, 45.0]
var limites = [6, 5, 4]
var nomes = ["CANETA", "LANTERNA", "CÂMERA", "CHECKLIST", "COLHER", "ÓCULOS"]
var cores = [Color("e8c35a"), Color("6fb7e0"), Color("e07a5f"), Color("8fd18a"), Color("c79be0"), Color("e0e0d0")]
var painel = Rect2(330, 60, 300, 50)
var posicoes = []
var direcoes = []
var presos = []
var alvos = []
var na_mao = -1
var batidas = 0
var tempo = 0.0
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
	var total = quantidades[nivel]
	for i in range(total):
		posicoes.append(Vector2(80 + randf() * 800, 170 + randf() * 190))
		var velocidade = velocidades[nivel] * pow(0.85, folga)
		direcoes.append(Vector2(velocidade, 0).rotated(randf() * TAU))
		presos.append(false)
		alvos.append(Vector2(480 + (i - (total - 1) / 2.0) * 150, 452))
	var titulo = Game.make_label("ARMÁRIO DE CARGA · PRENDER OBJETOS SOLTOS", 20, Game.AMBER)
	titulo.position = Vector2(16, 6)
	add_child(titulo)
	contador = Game.make_label("", 20, Color.WHITE)
	contador.position = Vector2(650, 6)
	add_child(contador)
	aviso = Game.make_label("", 15, Color.WHITE)
	aviso.position = Vector2(16, 33)
	add_child(aviso)
	var rodape = Game.make_label("Cada batida no painel de interruptores é um risco para a nave.", 15)
	rodape.position = Vector2(16, 510)
	add_child(rodape)
	atualizar_textos()
	centralizar()
	get_viewport().size_changed.connect(centralizar)


func centralizar():
	var tela = get_viewport_rect().size
	position = Vector2((tela.x - 960) / 2, 16)


func _gui_input(event):
	if acabou:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pegar(event.position)
		else:
			soltar(event.position)
	if event is InputEventMouseMotion and na_mao >= 0:
		posicoes[na_mao] = limitar(event.position)


func _notification(what):
	if what == NOTIFICATION_PAUSED:
		na_mao = -1


func limitar(pos):
	return Vector2(clamp(pos.x, 30, 930), clamp(pos.y, 90, 480))


func pegar(pos):
	for i in range(posicoes.size()):
		if not presos[i] and posicoes[i].distance_to(pos) < 36:
			na_mao = i
			return


func soltar(pos):
	if na_mao < 0:
		return
	var i = na_mao
	na_mao = -1
	if pos.distance_to(alvos[i]) < 42:
		presos[i] = true
		posicoes[i] = alvos[i]
		if not presos.has(false):
			encerrar(true)
	else:
		posicoes[i] = Vector2(clamp(pos.x, 30, 930), clamp(pos.y, 90, 400))


func encerrar(resultado):
	acabou = true
	acertou = resultado
	na_mao = -1


func _process(delta):
	if alerta > 0:
		alerta -= delta
	if acabou:
		espera -= delta
		if espera <= 0:
			set_process(false)
			terminou.emit(acertou)
	else:
		tempo -= delta
		for i in range(posicoes.size()):
			if not presos[i] and i != na_mao:
				flutuar(i, delta)
		if tempo <= 0 or batidas > limites[nivel]:
			encerrar(false)
	atualizar_textos()
	queue_redraw()


func flutuar(i, delta):
	var pos = posicoes[i] + direcoes[i] * delta
	if pos.x < 30 or pos.x > 930:
		direcoes[i].x = -direcoes[i].x
	if pos.y < 90 or pos.y > 400:
		direcoes[i].y = -direcoes[i].y
	pos = Vector2(clamp(pos.x, 30, 930), clamp(pos.y, 90, 400))
	if painel.grow(20).has_point(pos):
		batidas += 1
		alerta = 1.0
		direcoes[i].y = abs(direcoes[i].y)
		pos.y = painel.end.y + 22
	posicoes[i] = pos


func atualizar_textos():
	contador.text = "TEMPO %d · BATIDAS %d/%d" % [ceil(max(tempo, 0)), batidas, limites[nivel]]
	contador.modulate = Game.GOOD
	if batidas > 0 or tempo < 10:
		contador.modulate = Game.WARN
	if acabou and acertou:
		aviso.text = "Tudo preso. Voltando à cabine..."
		aviso.modulate = Game.GOOD
	elif acabou:
		aviso.text = "Não deu tempo de prender tudo. Voltando à cabine..."
		aviso.modulate = Game.BAD
	elif alerta > 0:
		aviso.text = "Um objeto bateu no painel de interruptores!"
		aviso.modulate = Game.BAD
	else:
		aviso.text = "Clique em um objeto, arraste até o velcro da mesma cor e solte."
		aviso.modulate = Game.CREAM


func desenhar_objeto(tipo, pos, cor):
	var escuro = cor.darkened(0.45)
	if tipo == 0:
		draw_rect(Rect2(pos + Vector2(-24, -4), Vector2(48, 8)), cor)
		draw_rect(Rect2(pos + Vector2(16, -4), Vector2(8, 8)), escuro)
	elif tipo == 1:
		draw_rect(Rect2(pos + Vector2(-22, -7), Vector2(32, 14)), cor)
		draw_rect(Rect2(pos + Vector2(10, -11), Vector2(12, 22)), escuro)
	elif tipo == 2:
		draw_rect(Rect2(pos + Vector2(-22, -14), Vector2(44, 28)), cor)
		draw_rect(Rect2(pos + Vector2(-16, -20), Vector2(12, 6)), cor)
		draw_circle(pos, 9, escuro)
	elif tipo == 3:
		draw_rect(Rect2(pos + Vector2(-16, -21), Vector2(32, 42)), cor)
		for linha in range(4):
			draw_rect(Rect2(pos + Vector2(-10, -13 + linha * 9), Vector2(20, 3)), escuro)
	elif tipo == 4:
		draw_circle(pos + Vector2(-14, 0), 10, cor)
		draw_rect(Rect2(pos + Vector2(-6, -3), Vector2(30, 6)), cor)
	else:
		draw_circle(pos + Vector2(-12, 0), 10, cor)
		draw_circle(pos + Vector2(12, 0), 10, cor)
		draw_circle(pos + Vector2(-12, 0), 6, escuro)
		draw_circle(pos + Vector2(12, 0), 6, escuro)


func _draw():
	var fonte = get_theme_default_font()
	draw_rect(Rect2(0, 0, 960, 540), Color(0.1, 0.11, 0.12))
	for x in range(0, 960, 120):
		draw_line(Vector2(x, 60), Vector2(x, 500), Color(1, 1, 1, 0.05), 2)
	draw_rect(Rect2(0, 410, 960, 90), Color(0.14, 0.15, 0.15))
	var cor_painel = Color(0.2, 0.21, 0.2)
	if alerta > 0:
		cor_painel = Color(0.5, 0.15, 0.12)
	draw_rect(painel, cor_painel)
	draw_rect(painel, Game.AMBER, false, 2)
	for x in range(8):
		draw_rect(Rect2(painel.position + Vector2(22 + x * 34, 14), Vector2(8, 20)), Game.CREAM)
	draw_string(fonte, Vector2(330, 128), "PAINEL DE INTERRUPTORES", HORIZONTAL_ALIGNMENT_CENTER, 300, 13, Game.AMBER)
	for i in range(alvos.size()):
		var caixa = Rect2(alvos[i] - Vector2(36, 34), Vector2(72, 68))
		draw_rect(caixa, Color(0.07, 0.08, 0.08))
		for x in range(6):
			for y in range(6):
				draw_rect(Rect2(caixa.position + Vector2(8 + x * 10, 6 + y * 10), Vector2(3, 3)), cores[i].darkened(0.5))
		draw_rect(caixa, cores[i], false, 3)
		draw_string(fonte, Vector2(alvos[i].x - 60, 498), nomes[i], HORIZONTAL_ALIGNMENT_CENTER, 120, 12, cores[i])
	for i in range(posicoes.size()):
		if i != na_mao:
			desenhar_objeto(i, posicoes[i], cores[i])
			if presos[i]:
				draw_rect(Rect2(alvos[i] + Vector2(-36, -30), Vector2(8, 60)), Color(0.75, 0.72, 0.6))
				draw_rect(Rect2(alvos[i] + Vector2(28, -30), Vector2(8, 60)), Color(0.75, 0.72, 0.6))
	if na_mao >= 0:
		draw_arc(posicoes[na_mao], 34, 0, TAU, 32, Color.WHITE, 2)
		draw_line(posicoes[na_mao], alvos[na_mao], Color(1, 1, 1, 0.25), 2)
		desenhar_objeto(na_mao, posicoes[na_mao], cores[na_mao])
	draw_rect(Rect2(0, 0, 960, 60), Color(0.06, 0.07, 0.065))
	draw_rect(Rect2(0, 500, 960, 40), Color(0.06, 0.07, 0.065))
	var borda = Game.AMBER
	if alerta > 0:
		borda = Game.BAD
	draw_rect(Rect2(0, 0, 960, 540), borda, false, 3)
