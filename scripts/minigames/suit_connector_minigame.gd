extends Control

signal terminou(acertou)

var nivel = 1
var folga = 0
var tolerancias = [16.0, 12.0, 9.0]
var derivas = [14.0, 24.0, 36.0]
var limites = [4, 3, 3]
var tempos = [60.0, 50.0, 45.0]
var nomes = ["AZUL", "VERMELHO"]
var funcoes = ["ENTRADA DE OXIGÊNIO", "SAÍDA DE GÁS"]
var cores = [Color("4f8fe0"), Color("d9534f")]
var centro = Vector2(400, 285)
var etapa = 0
var angulo = 0.0
var encaixe = 0.0
var sentido = 1.0
var troca = 1.5
var erros = 0
var brilho = 0.0
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
	sortear()
	var titulo = Game.make_label(str(TranslationServer.translate("TRAJE · ENCAIXAR AS MANGUEIRAS")), 20, Game.AMBER)
	titulo.position = Vector2(16, 6)
	add_child(titulo)
	contador = Game.make_label("", 20, Color.WHITE)
	contador.position = Vector2(660, 6)
	add_child(contador)
	aviso = Game.make_label("", 15, Color.WHITE)
	aviso.position = Vector2(16, 33)
	add_child(aviso)
	var rodape = Game.make_label(str(TranslationServer.translate("Empurrar o conector desalinhado desgasta a vedação.")), 15)
	rodape.position = Vector2(16, 510)
	add_child(rodape)
	atualizar_textos()
	centralizar()
	get_viewport().size_changed.connect(centralizar)


func centralizar():
	var tela = get_viewport_rect().size
	position = Vector2((tela.x - 960) / 2, 16)


func sortear():
	encaixe = randf() * 120.0
	angulo = encaixe + 40.0 + randf() * 40.0


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			empurrar()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			angulo -= 5.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			angulo += 5.0


func _unhandled_input(event):
	if event.is_action_pressed("move_up"):
		empurrar()


func desvio():
	return fposmod(angulo - encaixe + 60.0, 120.0) - 60.0


func alinhado():
	return abs(desvio()) < tolerancias[nivel] + folga * 3


func encerrar(resultado):
	acabou = true
	acertou = resultado


func empurrar():
	if acabou:
		return
	if alinhado():
		etapa += 1
		brilho = 0.6
		if etapa == 2:
			encerrar(true)
		else:
			sortear()
	else:
		erros += 1
		alerta = 0.6
		if erros > limites[nivel]:
			encerrar(false)


func passo(delta, giro):
	tempo -= delta
	troca -= delta
	if troca <= 0:
		troca = 1.0 + randf() * 1.5
		sentido = -sentido
	angulo += sentido * derivas[nivel] * delta
	angulo += giro * 110.0 * delta
	if tempo <= 0:
		encerrar(false)


func _process(delta):
	if alerta > 0:
		alerta -= delta
	if brilho > 0:
		brilho -= delta
	if acabou:
		espera -= delta
		if espera <= 0:
			set_process(false)
			terminou.emit(acertou)
	else:
		var giro = Input.get_axis("ui_left", "ui_right") + Input.get_axis("move_left", "move_right")
		passo(delta, clamp(giro, -1.0, 1.0))
	atualizar_textos()
	queue_redraw()


func atualizar_textos():
	contador.text = "TEMPO %d · ERROS %d/%d" % [ceil(max(tempo, 0)), erros, limites[nivel]]
	contador.modulate = Game.GOOD
	if erros > 0 or tempo < 10:
		contador.modulate = Game.WARN
	if acabou and acertou:
		aviso.text = str(TranslationServer.translate("As duas mangueiras estão travadas. Voltando à cabine..."))
		aviso.modulate = Game.GOOD
	elif acabou:
		aviso.text = str(TranslationServer.translate("O encaixe não ficou seguro. Voltando à cabine..."))
		aviso.modulate = Game.BAD
	elif alerta > 0:
		aviso.text = str(TranslationServer.translate("Desalinhado! O conector não entrou."))
		aviso.modulate = Game.BAD
	elif alinhado():
		aviso.text = str(TranslationServer.translate("ALINHADO! Empurre agora: ESPAÇO ou clique."))
		aviso.modulate = Game.GOOD
	else:
		aviso.text = str(TranslationServer.translate("Gire o conector com A/D, SETAS ou a roda do mouse até as travas ficarem sobre os encaixes."))
		aviso.modulate = Game.CREAM


func _draw():
	var fonte = get_theme_default_font()
	draw_rect(Rect2(0, 0, 960, 540), Color(0.1, 0.11, 0.12))
	draw_rect(Rect2(150, 60, 500, 440), Color(0.78, 0.77, 0.72))
	for y in range(90, 500, 44):
		draw_line(Vector2(150, y), Vector2(650, y), Color(0.66, 0.65, 0.6), 2)
	var parte = min(etapa, 1)
	var cor = cores[parte]
	draw_circle(centro, 150, Color(0.2, 0.21, 0.22))
	draw_arc(centro, 150, 0, TAU, 64, cor, 10)
	for k in range(3):
		var ponto = centro + Vector2(118, 0).rotated(deg_to_rad(encaixe + k * 120))
		draw_circle(ponto, 20, Color(0.05, 0.06, 0.06))
		draw_arc(ponto, 20, 0, TAU, 24, cor, 3)
	draw_line(centro, centro + Vector2(0, 230), Color(0.3, 0.31, 0.32), 46)
	draw_circle(centro, 86, Color(0.62, 0.63, 0.62))
	draw_circle(centro, 60, cor.darkened(0.2))
	draw_circle(centro, 30, Color(0.12, 0.13, 0.13))
	var cor_trava = Game.CREAM
	if alinhado() or brilho > 0:
		cor_trava = Game.GOOD
	if alerta > 0:
		cor_trava = Game.BAD
	for k in range(3):
		var ponta = centro + Vector2(118, 0).rotated(deg_to_rad(angulo + k * 120))
		draw_line(centro + Vector2(70, 0).rotated(deg_to_rad(angulo + k * 120)), ponta, Color(0.62, 0.63, 0.62), 14)
		draw_circle(ponta, 13, cor_trava)
	draw_string(fonte, Vector2(690, 110), str(TranslationServer.translate("MANGUEIRAS")), HORIZONTAL_ALIGNMENT_LEFT, 250, 16, Game.AMBER)
	for i in range(2):
		var marca = "[ ]"
		var cor_texto = Game.CREAM
		if etapa > i:
			marca = "[x]"
			cor_texto = Game.GOOD
		elif etapa == i:
			cor_texto = cores[i]
		draw_rect(Rect2(690, 128 + i * 52, 14, 14), cores[i])
		draw_string(fonte, Vector2(712, 141 + i * 52), marca + " " + nomes[i], HORIZONTAL_ALIGNMENT_LEFT, 240, 14, cor_texto)
		draw_string(fonte, Vector2(712, 159 + i * 52), funcoes[i], HORIZONTAL_ALIGNMENT_LEFT, 240, 12, cor_texto)
	draw_string(fonte, Vector2(690, 270), str(TranslationServer.translate("DESVIO")), HORIZONTAL_ALIGNMENT_LEFT, 250, 16, Game.AMBER)
	draw_rect(Rect2(690, 282, 240, 22), Color(0.07, 0.08, 0.08))
	var limite = tolerancias[nivel] + folga * 3
	draw_rect(Rect2(810 - limite * 2, 282, limite * 4, 22), Color(0.45, 0.9, 0.45, 0.35))
	draw_rect(Rect2(810 + desvio() * 2 - 3, 278, 6, 30), cor_trava)
	draw_rect(Rect2(690, 282, 240, 22), Game.AMBER, false, 2)
	draw_string(fonte, Vector2(690, 350), "A / D ou ← / →   girar", HORIZONTAL_ALIGNMENT_LEFT, 250, 13, Game.CREAM)
	draw_string(fonte, Vector2(690, 372), str(TranslationServer.translate("ESPAÇO ou clique  empurrar")), HORIZONTAL_ALIGNMENT_LEFT, 250, 13, Game.CREAM)
	draw_string(fonte, Vector2(690, 394), "Azul entra, vermelho sai.", HORIZONTAL_ALIGNMENT_LEFT, 250, 13, Game.AMBER)
	draw_rect(Rect2(0, 0, 960, 60), Color(0.06, 0.07, 0.065))
	draw_rect(Rect2(0, 500, 960, 40), Color(0.06, 0.07, 0.065))
	var borda = Game.AMBER
	if alerta > 0:
		borda = Game.BAD
	draw_rect(Rect2(0, 0, 960, 540), borda, false, 3)
