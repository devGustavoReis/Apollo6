extends Control

signal terminou(acertou)

var nivel = 1
var folga = 0
var tempos = [60.0, 50.0, 40.0]
var raios = [46.0, 36.0, 28.0]
var derivas = [0.0, 10.0, 18.0]
var area = Rect2(60, 90, 380, 380)
var mira = Vector2(250, 280)
var terra = Vector2(250, 280)
var rumo = Vector2.ZERO
var sinal = 0.0
var anterior = 0.0
var subindo = false
var trava = 0.0
var botao = false
var mouse = Vector2.ZERO
var tempo = 0.0
var acabou = false
var acertou = false
var espera = 1.5
var contador
var aviso


func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	size = Vector2(960, 540)
	tempo = tempos[nivel] + folga * 10
	terra = mira
	while terra.distance_to(mira) < 140:
		terra = Vector2(area.position.x + 40 + randf() * 300, area.position.y + 40 + randf() * 300)
	rumo = Vector2(1, 0).rotated(randf() * TAU)
	var titulo = Game.make_label("RÁDIO · RECUPERAR O SINAL DA ANTENA", 20, Game.AMBER)
	titulo.position = Vector2(16, 6)
	add_child(titulo)
	contador = Game.make_label("", 20, Color.WHITE)
	contador.position = Vector2(760, 6)
	add_child(contador)
	aviso = Game.make_label("", 15, Color.WHITE)
	aviso.position = Vector2(16, 33)
	add_child(aviso)
	var rodape = Game.make_label("A antena de alto ganho só funciona apontada para a Terra.", 15)
	rodape.position = Vector2(16, 510)
	add_child(rodape)
	medir()
	atualizar_textos()
	centralizar()
	get_viewport().size_changed.connect(centralizar)


func centralizar():
	var tela = get_viewport_rect().size
	position = Vector2((tela.x - 960) / 2, 16)


func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		botao = event.pressed
		mouse = event.position
	if event is InputEventMouseMotion:
		mouse = event.position


func _notification(what):
	if what == NOTIFICATION_PAUSED:
		botao = false


func raio():
	return raios[nivel] + folga * 6


func medir():
	sinal = clamp(1.0 - mira.distance_to(terra) / 260.0, 0.0, 1.0)


func encerrar(resultado):
	acabou = true
	acertou = resultado


# Espelha a posição dentro do visor, inclusive se um único tick cruzar várias bordas.
func refletir_eixo(pos: float, velocidade: float, minimo: float, maximo: float, delta: float) -> Vector2:
	var largura := maximo - minimo
	var fase := fposmod(pos - minimo + velocidade * delta, largura * 2.0)
	if is_zero_approx(fase):
		return Vector2(minimo, absf(velocidade))
	if is_equal_approx(fase, largura):
		return Vector2(maximo, -absf(velocidade))
	if fase < largura:
		return Vector2(minimo + fase, velocidade)
	return Vector2(minimo + 2.0 * largura - fase, -velocidade)


func passo(delta, direcao):
	if acabou or delta <= 0.0:
		return
	delta = minf(delta, maxf(tempo, 0.0))
	tempo -= delta
	mira += direcao * 170 * delta
	mira = Vector2(clamp(mira.x, area.position.x, area.end.x), clamp(mira.y, area.position.y, area.end.y))
	var minimo: Vector2 = area.position + Vector2(30, 30)
	var maximo: Vector2 = area.end - Vector2(30, 30)
	var eixo_x := refletir_eixo(terra.x, rumo.x, minimo.x, maximo.x, derivas[nivel] * delta)
	var eixo_y := refletir_eixo(terra.y, rumo.y, minimo.y, maximo.y, derivas[nivel] * delta)
	terra = Vector2(eixo_x.x, eixo_y.x)
	rumo = Vector2(eixo_x.y, eixo_y.y)
	anterior = sinal
	medir()
	if sinal > anterior + 0.0005:
		subindo = true
	elif sinal < anterior - 0.0005:
		subindo = false
	if mira.distance_to(terra) < raio():
		trava += delta
	else:
		trava = 0.0
	if trava >= 2.0:
		encerrar(true)
	elif tempo <= 0:
		encerrar(false)


func _process(delta):
	if acabou:
		espera -= delta
		if espera <= 0:
			set_process(false)
			terminou.emit(acertou)
	else:
		var direcao = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		direcao += Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if botao and area.has_point(mouse) and mouse.distance_to(mira) > 4:
			direcao = (mouse - mira).normalized()
		passo(delta, direcao.limit_length(1.0))
	atualizar_textos()
	queue_redraw()


func atualizar_textos():
	contador.text = "TEMPO %d" % ceil(max(tempo, 0))
	contador.modulate = Game.GOOD
	if tempo < 10:
		contador.modulate = Game.WARN
	if acabou and acertou:
		aviso.text = "Sinal travado. Houston na escuta. Voltando à cabine..."
		aviso.modulate = Game.GOOD
	elif acabou:
		aviso.text = "O tempo acabou sem contato. Voltando à cabine..."
		aviso.modulate = Game.BAD
	elif trava > 0:
		aviso.text = "Sinal forte! Segure a antena nesta posição até travar."
		aviso.modulate = Game.GOOD
	else:
		aviso.text = "Mova a antena com WASD ou SETAS (ou segure o clique no visor). Procure o sinal mais forte."
		aviso.modulate = Game.CREAM


func _draw():
	var fonte = get_theme_default_font()
	draw_rect(Rect2(0, 0, 960, 540), Color(0.1, 0.11, 0.12))
	draw_rect(area, Color(0.03, 0.07, 0.05))
	for i in range(1, 5):
		var passo_grade = 380.0 * i / 5
		draw_line(area.position + Vector2(passo_grade, 0), area.position + Vector2(passo_grade, 380), Color(0.3, 0.8, 0.4, 0.18), 1)
		draw_line(area.position + Vector2(0, passo_grade), area.position + Vector2(380, passo_grade), Color(0.3, 0.8, 0.4, 0.18), 1)
	var ruido = int((1.0 - sinal) * 160)
	if acabou and not acertou:
		ruido = 160
	for i in range(ruido):
		var ponto = area.position + Vector2(randf() * 376, randf() * 376)
		draw_rect(Rect2(ponto, Vector2(3, 3)), Color(0.7, 0.9, 0.75, 0.5))
	if acabou and acertou:
		draw_circle(terra, 18, Color("2f6fd0"))
		draw_circle(terra + Vector2(-5, -4), 7, Color("4f9a5a"))
	var cor_mira = Game.AMBER
	if trava > 0:
		cor_mira = Game.GOOD
	draw_arc(mira, raio(), 0, TAU, 32, cor_mira, 2)
	draw_line(mira - Vector2(14, 0), mira + Vector2(14, 0), cor_mira, 2)
	draw_line(mira - Vector2(0, 14), mira + Vector2(0, 14), cor_mira, 2)
	draw_rect(area, Game.AMBER, false, 2)
	var yaw = (mira.x - area.position.x) / 380.0 * 360.0
	var pitch = 90.0 - (mira.y - area.position.y) / 380.0 * 180.0
	draw_string(fonte, Vector2(60, 488), "PITCH %d°   YAW %d°" % [pitch, yaw], HORIZONTAL_ALIGNMENT_CENTER, 380, 14, Game.CREAM)
	draw_string(fonte, Vector2(500, 110), "INTENSIDADE DO SINAL", HORIZONTAL_ALIGNMENT_LEFT, 300, 16, Game.AMBER)
	for i in range(10):
		var cor = Color(0.18, 0.19, 0.19)
		if sinal * 10 > i:
			cor = Game.BAD
			if i >= 4:
				cor = Game.WARN
			if i >= 7:
				cor = Game.GOOD
		draw_rect(Rect2(500 + i * 30, 300 - 14 - i * 16, 22, 14 + i * 16), cor)
	draw_string(fonte, Vector2(820, 300), "%d%%" % (sinal * 100), HORIZONTAL_ALIGNMENT_LEFT, 120, 30, Game.CREAM)
	var seta = "▼ CAINDO"
	var cor_seta = Game.BAD
	if subindo:
		seta = "▲ SUBINDO"
		cor_seta = Game.GOOD
	draw_string(fonte, Vector2(820, 250), seta, HORIZONTAL_ALIGNMENT_LEFT, 130, 14, cor_seta)
	draw_string(fonte, Vector2(500, 350), "TRAVA DO SINAL", HORIZONTAL_ALIGNMENT_LEFT, 300, 16, Game.AMBER)
	draw_rect(Rect2(500, 362, 400, 26), Color(0.07, 0.08, 0.08))
	draw_rect(Rect2(500, 362, 400 * min(trava / 2.0, 1.0), 26), Game.GOOD)
	draw_rect(Rect2(500, 362, 400, 26), Game.AMBER, false, 2)
	var base = Vector2(700, 470)
	var giro = (mira.x - area.get_center().x) / 190.0 * 0.9
	draw_line(base, base + Vector2(0, -34), Color(0.6, 0.6, 0.58), 6)
	var topo = base + Vector2(0, -34)
	var lado = Vector2(34, 0).rotated(giro)
	draw_line(topo - lado, topo + lado, Game.CREAM, 8)
	draw_line(topo, topo + Vector2(0, -22).rotated(giro), Game.CREAM, 3)
	draw_rect(Rect2(base + Vector2(-40, 0), Vector2(80, 10)), Color(0.35, 0.36, 0.36))
	draw_rect(Rect2(0, 0, 960, 60), Color(0.06, 0.07, 0.065))
	draw_rect(Rect2(0, 500, 960, 40), Color(0.06, 0.07, 0.065))
	draw_rect(Rect2(0, 0, 960, 540), Game.AMBER, false, 3)
