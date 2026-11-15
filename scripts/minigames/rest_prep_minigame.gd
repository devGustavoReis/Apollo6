extends Control

signal terminou(acertou)

var nivel = 1
var folga = 0
var tempos = [60.0, 50.0, 45.0]
var pontos_por_janela = [2, 3, 4]
var intervalos = [0.0, 7.0, 4.5]
var janelas = [Vector2(150, 250), Vector2(315, 180), Vector2(480, 270), Vector2(645, 180), Vector2(810, 250)]
var nomes = [str(TranslationServer.translate("LATERAL")), "ENCONTRO", "ESCOTILHA", "ENCONTRO", str(TranslationServer.translate("LATERAL"))]
var luzes = [Vector2(330, 440), Vector2(480, 440), Vector2(630, 440)]
var acesas = [true, true, true]
var velcros = []
var donos = []
var presos = []
var proxima = 0.0
var relogio = 0.0
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
	proxima = intervalos[nivel] + folga * 2
	var total = pontos_por_janela[nivel]
	for j in range(janelas.size()):
		for k in range(total):
			velcros.append(janelas[j] + Vector2(76, 0).rotated(deg_to_rad(45 + 360.0 / total * k)))
			donos.append(j)
			presos.append(false)
	var titulo = Game.make_label(str(TranslationServer.translate("DESCANSO · ESCURECER A CABINE")), 20, Game.AMBER)
	titulo.position = Vector2(16, 6)
	add_child(titulo)
	contador = Game.make_label("", 20, Color.WHITE)
	contador.position = Vector2(690, 6)
	add_child(contador)
	aviso = Game.make_label("", 15, Color.WHITE)
	aviso.position = Vector2(16, 33)
	add_child(aviso)
	var rodape = Game.make_label(str(TranslationServer.translate("Com Sol o tempo todo lá fora, sem cortinas ninguém dorme.")), 15)
	rodape.position = Vector2(16, 510)
	add_child(rodape)
	atualizar_textos()
	centralizar()
	get_viewport().size_changed.connect(centralizar)


func centralizar():
	var tela = get_viewport_rect().size
	position = Vector2((tela.x - 960) / 2, 16)


func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicar(event.position)


func luz():
	var fontes = presos.count(false) + acesas.count(true)
	return 100.0 * fontes / (presos.size() + acesas.size())


func soltas(janela):
	var total = 0
	for i in range(velcros.size()):
		if donos[i] == janela and not presos[i]:
			total += 1
	return total


func clicar(pos):
	if acabou:
		return
	for i in range(velcros.size()):
		if pos.distance_to(velcros[i]) < 22:
			presos[i] = true
	for i in range(luzes.size()):
		if pos.distance_to(luzes[i]) < 30:
			acesas[i] = false
	if luz() == 0:
		encerrar(true)


func soltar_velcro():
	var colados = []
	for i in range(presos.size()):
		if presos[i]:
			colados.append(i)
	if colados.size() > 0:
		presos[colados[randi() % colados.size()]] = false
		alerta = 0.8


func encerrar(resultado):
	acabou = true
	acertou = resultado


func passo(delta):
	tempo -= delta
	if intervalos[nivel] > 0:
		proxima -= delta
		if proxima <= 0:
			proxima = intervalos[nivel] + folga * 2
			soltar_velcro()
	if tempo <= 0:
		encerrar(false)


func _process(delta):
	relogio += delta
	if alerta > 0:
		alerta -= delta
	if acabou:
		espera -= delta
		if espera <= 0:
			set_process(false)
			terminou.emit(acertou)
	else:
		passo(delta)
	atualizar_textos()
	queue_redraw()


func atualizar_textos():
	contador.text = str(TranslationServer.translate("TEMPO %d · LUZ %d%%")) % [ceil(max(tempo, 0)), luz()]
	contador.modulate = Game.WARN
	if luz() < 35:
		contador.modulate = Game.GOOD
	if acabou and acertou:
		aviso.text = str(TranslationServer.translate("Cabine escura e pronta para o descanso. Voltando à cabine..."))
		aviso.modulate = Game.GOOD
	elif acabou:
		aviso.text = str(TranslationServer.translate("Ainda entra luz e o tempo acabou. Voltando à cabine..."))
		aviso.modulate = Game.BAD
	elif alerta > 0:
		aviso.text = str(TranslationServer.translate("Uma ponta de velcro soltou e a luz voltou a entrar!"))
		aviso.modulate = Game.BAD
	else:
		aviso.text = str(TranslationServer.translate("Clique nos pontos de velcro que brilham em volta das janelas e apague as três lâmpadas."))
		aviso.modulate = Game.CREAM


func _draw():
	var fonte = get_theme_default_font()
	draw_rect(Rect2(0, 0, 960, 540), Color(0.3, 0.31, 0.3))
	for x in range(0, 960, 120):
		draw_line(Vector2(x, 60), Vector2(x, 500), Color(0, 0, 0, 0.15), 2)
	var total = pontos_por_janela[nivel]
	for j in range(janelas.size()):
		var claro = float(soltas(j)) / total
		var cor = Color(0.05, 0.05, 0.07).lerp(Color(1.0, 0.95, 0.72), claro)
		if claro > 0:
			var feixe = PackedVector2Array()
			feixe.append(janelas[j] + Vector2(-50, 0))
			feixe.append(janelas[j] + Vector2(50, 0))
			feixe.append(janelas[j] + Vector2(120, 260))
			feixe.append(janelas[j] + Vector2(-120, 260))
			draw_colored_polygon(feixe, Color(1.0, 0.95, 0.72, 0.1 * claro))
		if j == 2:
			draw_circle(janelas[j], 56, cor)
			draw_arc(janelas[j], 56, 0, TAU, 40, Color(0.55, 0.56, 0.55), 5)
		else:
			var caixa = Rect2(janelas[j] - Vector2(46, 52), Vector2(92, 104))
			draw_rect(caixa, cor)
			draw_rect(caixa, Color(0.55, 0.56, 0.55), false, 5)
		draw_string(fonte, janelas[j] + Vector2(-60, 100), nomes[j], HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Game.CREAM)
	draw_rect(Rect2(0, 60, 960, 440), Color(0, 0, 0, 0.72 * (1.0 - luz() / 100.0)))
	for i in range(luzes.size()):
		if acesas[i]:
			draw_circle(luzes[i], 34, Color(1.0, 0.9, 0.5, 0.25))
			draw_circle(luzes[i], 20, Color(1.0, 0.92, 0.6))
		else:
			draw_circle(luzes[i], 20, Color(0.12, 0.12, 0.11))
		draw_arc(luzes[i], 20, 0, TAU, 24, Game.AMBER, 2)
		draw_string(fonte, luzes[i] + Vector2(-50, 44), str(TranslationServer.translate("LÂMPADA")), HORIZONTAL_ALIGNMENT_CENTER, 100, 12, Game.CREAM)
	for i in range(velcros.size()):
		if presos[i]:
			draw_rect(Rect2(velcros[i] - Vector2(7, 7), Vector2(14, 14)), Color(0.42, 0.42, 0.38))
		else:
			draw_circle(velcros[i], 9, Color(1.0, 0.97, 0.8))
			draw_arc(velcros[i], 14 + sin(relogio * 6) * 3, 0, TAU, 20, Color(1.0, 0.97, 0.8, 0.7), 2)
	draw_rect(Rect2(0, 0, 960, 60), Color(0.06, 0.07, 0.065))
	draw_rect(Rect2(0, 500, 960, 40), Color(0.06, 0.07, 0.065))
	var borda = Game.AMBER
	if alerta > 0:
		borda = Game.BAD
	draw_rect(Rect2(0, 0, 960, 540), borda, false, 3)
