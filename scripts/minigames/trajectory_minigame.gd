extends Control

signal terminou(erros)

var pontos = [Vector2(120, 400), Vector2(290, 200), Vector2(450, 330), Vector2(620, 180), Vector2(800, 300)]
var indice = 0
var nave = Vector2.ZERO
var mira = Vector2.ZERO
var angulo = 0.0
var arrastando = false
var erros = 0
var tolerancia = 36.0
var destino = "lua"
var acabou = false
var espera = 1.2
var alerta = 0.0
var tempo = 0.0
var estrelas = []
var contador
var aviso


func _ready():
	Sound.play_cue("switch")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	size = Vector2(960, 540)
	nave = pontos[0]
	mira = pontos[0]
	angulo = (pontos[1] - pontos[0]).angle()
	for i in range(60):
		estrelas.append(Vector2(randf() * 956, 62 + randf() * 434))
	var titulo = Game.make_label("COMPUTADOR DE NAVEGAÇÃO · CORREÇÃO DE ROTA", 20, Game.AMBER)
	titulo.position = Vector2(16, 6)
	add_child(titulo)
	contador = Game.make_label("DESVIOS: 0", 20, Color.WHITE)
	contador.position = Vector2(812, 6)
	contador.modulate = Game.GOOD
	add_child(contador)
	aviso = Game.make_label("", 15, Color.WHITE)
	aviso.position = Vector2(16, 33)
	add_child(aviso)
	var rodape = Game.make_label("Cada desvio da rota gasta mais propelente do CSM.", 15)
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
		if event.pressed and event.position.distance_to(nave) < tolerancia:
			arrastando = true
		if not event.pressed:
			arrastando = false
	if event is InputEventMouseMotion and arrastando:
		mira = event.position
		mover(mira)


func _notification(what):
	if what == NOTIFICATION_PAUSED:
		arrastando = false


func _process(delta):
	tempo += delta
	if alerta > 0:
		alerta -= delta
	if acabou:
		espera -= delta
		if espera <= 0:
			set_process(false)
			terminou.emit(erros)
	elif not arrastando:
		var direcao = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if direcao != Vector2.ZERO:
			mira += direcao * 150 * delta
			mover(mira)
	atualizar_textos()
	queue_redraw()


func mover(pos):
	var a = pontos[indice]
	var b = pontos[indice + 1]
	var perto = Geometry2D.get_closest_point_to_segment(pos, a, b)
	if pos.distance_to(perto) > tolerancia:
		erros += 1
		Sound.play_cue("warning", "Voice", true)
		arrastando = false
		nave = a
		mira = a
		alerta = 1.5
	else:
		nave = perto
		if nave.distance_to(b) < 8:
			indice += 1
			nave = b
			if indice == pontos.size() - 1:
				arrastando = false
				acabou = true
				Sound.play_cue("success", "Interface")
			else:
				angulo = (pontos[indice + 1] - pontos[indice]).angle()


func atualizar_textos():
	contador.text = "DESVIOS: " + str(erros)
	if erros > 0:
		contador.modulate = Game.WARN
	if acabou:
		aviso.text = "Rota corrigida. Voltando à cabine..."
		aviso.modulate = Game.GOOD
	elif alerta > 0:
		aviso.text = "FORA DA ROTA! A nave voltou ao último ponto. Clique nela de novo."
		aviso.modulate = Game.BAD
	else:
		aviso.text = "Clique na nave e arraste pela linha tracejada até a %s. Sem mouse: use as SETAS." % ("Terra" if destino == "terra" else "Lua")
		aviso.modulate = Game.CREAM


func _draw():
	var ultimo = pontos.size() - 1
	var lua = pontos[ultimo]
	draw_rect(Rect2(0, 0, 960, 540), Color("1b5e9e"))
	for i in range(ultimo):
		draw_line(pontos[i], pontos[i + 1], Color("2a70b3"), tolerancia * 2)
	for p in pontos:
		draw_circle(p, tolerancia, Color("2a70b3"))
	for x in range(0, 960, 40):
		draw_line(Vector2(x, 60), Vector2(x, 500), Color(1, 1, 1, 0.07), 1)
	for y in range(60, 500, 40):
		draw_line(Vector2(0, y), Vector2(960, y), Color(1, 1, 1, 0.07), 1)
	for e in estrelas:
		draw_rect(Rect2(e, Vector2(2, 2)), Color(1, 1, 1, 0.6))
	var origem = Vector2(70, 440)
	if destino == "terra":
		desenhar_lua(origem)
		desenhar_terra(lua)
	else:
		desenhar_terra(origem)
		desenhar_lua(lua)
	draw_arc(lua, 54 + sin(tempo * 4) * 3, 0, TAU, 40, Game.AMBER, 2)
	for i in range(ultimo):
		if i < indice:
			draw_line(pontos[i], pontos[i + 1], Game.GOOD, 3)
		else:
			draw_dashed_line(pontos[i], pontos[i + 1], Game.AMBER, 3, 12)
	if not acabou:
		draw_line(pontos[indice], nave, Game.GOOD, 3)
	for i in range(1, ultimo):
		if i <= indice:
			draw_circle(pontos[i], 7, Game.GOOD)
		else:
			draw_arc(pontos[i], 9, 0, TAU, 24, Game.AMBER, 2)
	var cor = Game.CREAM
	if arrastando:
		cor = Game.GOOD
	if alerta > 0:
		cor = Game.BAD
	var forma = PackedVector2Array()
	forma.append(nave + Vector2(24, 0).rotated(angulo))
	forma.append(nave + Vector2(-15, -14).rotated(angulo))
	forma.append(nave + Vector2(-8, 0).rotated(angulo))
	forma.append(nave + Vector2(-15, 14).rotated(angulo))
	draw_colored_polygon(forma, cor)
	if not arrastando and not acabou:
		draw_arc(nave, tolerancia, 0, TAU, 32, Color(1, 1, 1, 0.5), 1.5)
		if mira.distance_to(nave) > 3:
			draw_line(mira - Vector2(8, 0), mira + Vector2(8, 0), Color.WHITE, 2)
			draw_line(mira - Vector2(0, 8), mira + Vector2(0, 8), Color.WHITE, 2)
	draw_rect(Rect2(0, 0, 960, 60), Color(0.06, 0.07, 0.065))
	draw_rect(Rect2(0, 500, 960, 40), Color(0.06, 0.07, 0.065))
	var borda = Game.AMBER
	if alerta > 0:
		borda = Game.BAD
	draw_rect(Rect2(0, 0, 960, 540), borda, false, 3)


func desenhar_terra(centro):
	draw_circle(centro, 44, Color("2f6fd0"))
	draw_circle(centro + Vector2(-12, -12), 16, Color("4f9a5a"))
	draw_circle(centro + Vector2(16, 16), 11, Color("4f9a5a"))


func desenhar_lua(centro):
	draw_circle(centro, 44, Color("b8b5ad"))
	draw_circle(centro + Vector2(-16, -12), 9, Color("9a978f"))
	draw_circle(centro + Vector2(14, 16), 7, Color("9a978f"))
	draw_circle(centro + Vector2(18, -20), 5, Color("9a978f"))
