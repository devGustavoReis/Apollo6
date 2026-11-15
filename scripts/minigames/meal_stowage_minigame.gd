extends Control

signal terminou(acertou)

var nivel = 1
var folga = 0
var tempos = [90.0, 75.0, 60.0]
var conjuntos = [
	[Vector2(2, 2), Vector2(2, 1), Vector2(1, 2), Vector2(1, 1)],
	[Vector2(2, 2), Vector2(3, 1), Vector2(1, 2), Vector2(2, 1)],
	[Vector2(2, 2), Vector2(3, 1), Vector2(1, 2), Vector2(2, 1), Vector2(1, 1)],
]
var bandeja = [Vector2(40, 100), Vector2(220, 100), Vector2(40, 290), Vector2(140, 290), Vector2(320, 290)]
var cores = [Color("d9a05b"), Color("6fb7e0"), Color("8fd18a"), Color("e07a5f"), Color("c79be0")]
var nomes = ["REFEIÇÃO", "BEBIDA", "SOPA", "SOBREMESA", "TALHER"]
var origem = Vector2(580, 150)
var celula = 80
var colunas = 4
var linhas = 3
var tamanhos = []
var casas = []
var na_mao = -1
var mouse = Vector2.ZERO
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
	tempo = tempos[nivel] + folga * 15
	tamanhos = conjuntos[nivel]
	for i in range(tamanhos.size()):
		casas.append(Vector2(-1, -1))
	var titulo = Game.make_label(str(TranslationServer.translate("COMIDA · GUARDAR AS EMBALAGENS")), 20, Game.AMBER)
	titulo.position = Vector2(16, 6)
	add_child(titulo)
	contador = Game.make_label("", 20, Color.WHITE)
	contador.position = Vector2(650, 6)
	add_child(contador)
	aviso = Game.make_label("", 15, Color.WHITE)
	aviso.position = Vector2(16, 33)
	add_child(aviso)
	var rodape = Game.make_label(str(TranslationServer.translate("Resto de comida solto estraga, cheira mal e produz gás.")), 15)
	rodape.position = Vector2(16, 510)
	add_child(rodape)
	atualizar_textos()
	centralizar()
	get_viewport().size_changed.connect(centralizar)


func centralizar():
	var tela = get_viewport_rect().size
	position = Vector2((tela.x - 960) / 2, 16)


func _gui_input(event):
	if event is InputEventMouseMotion:
		mouse = event.position
	if acabou:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse = event.position
		if event.pressed:
			pegar(event.position)
		else:
			soltar(event.position)


func _notification(what):
	if what == NOTIFICATION_PAUSED:
		na_mao = -1


func caixa(i):
	var canto = bandeja[i]
	if casas[i].x >= 0:
		canto = origem + casas[i] * celula
	return Rect2(canto, tamanhos[i] * celula)


func casa_do_mouse(i, pos):
	var canto = pos - tamanhos[i] * celula / 2.0 - origem
	return Vector2(round(canto.x / celula), round(canto.y / celula))


func cabe(i, casa):
	if casa.x < 0 or casa.y < 0 or casa.x + tamanhos[i].x > colunas or casa.y + tamanhos[i].y > linhas:
		return false
	var nova = Rect2(casa, tamanhos[i])
	for j in range(tamanhos.size()):
		if j != i and casas[j].x >= 0 and nova.intersects(Rect2(casas[j], tamanhos[j])):
			return false
	return true


func guardadas():
	var total = 0
	for casa in casas:
		if casa.x >= 0:
			total += 1
	return total


func pegar(pos):
	for i in range(tamanhos.size()):
		if caixa(i).has_point(pos):
			na_mao = i
			casas[i] = Vector2(-1, -1)
			return


func soltar(pos):
	if na_mao < 0:
		return
	var i = na_mao
	na_mao = -1
	var casa = casa_do_mouse(i, pos)
	if cabe(i, casa):
		casas[i] = casa
		if guardadas() == tamanhos.size():
			encerrar(true)
	elif Rect2(origem, Vector2(colunas, linhas) * celula).has_point(pos):
		alerta = 0.5


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
		if tempo <= 0:
			encerrar(false)
	atualizar_textos()
	queue_redraw()


func atualizar_textos():
	contador.text = str(TranslationServer.translate("TEMPO %d · GUARDADAS %d/%d")) % [ceil(max(tempo, 0)), guardadas(), tamanhos.size()]
	contador.modulate = Game.GOOD
	if tempo < 15:
		contador.modulate = Game.WARN
	if acabou and acertou:
		aviso.text = str(TranslationServer.translate("Tudo coube e a bolsa foi fechada. Voltando à cabine..."))
		aviso.modulate = Game.GOOD
	elif acabou:
		aviso.text = str(TranslationServer.translate("O tempo acabou com embalagens de fora. Voltando à cabine..."))
		aviso.modulate = Game.BAD
	elif alerta > 0:
		aviso.text = str(TranslationServer.translate("Não cabe aí. Procure outro espaço na bolsa."))
		aviso.modulate = Game.BAD
	else:
		aviso.text = str(TranslationServer.translate("Arraste cada embalagem vazia para a bolsa. Todas precisam caber sem ficar uma sobre a outra."))
		aviso.modulate = Game.CREAM


func desenhar_embalagem(i, canto, transparencia):
	var cor = cores[i]
	cor.a = transparencia
	var area = Rect2(canto + Vector2(4, 4), tamanhos[i] * celula - Vector2(8, 8))
	draw_rect(area, cor)
	draw_rect(area, cores[i].darkened(0.45), false, 3)
	draw_line(area.position + Vector2(8, 12), area.position + Vector2(area.size.x - 8, 12), cores[i].darkened(0.3), 3)
	draw_string(get_theme_default_font(), area.position + Vector2(0, area.size.y / 2 + 5), nomes[i], HORIZONTAL_ALIGNMENT_CENTER, area.size.x, 12, Color(0.1, 0.1, 0.1, transparencia))


func _draw():
	var fonte = get_theme_default_font()
	draw_rect(Rect2(0, 0, 960, 540), Color(0.1, 0.11, 0.12))
	draw_rect(Rect2(24, 80, 500, 400), Color(0.14, 0.15, 0.15))
	draw_rect(Rect2(24, 80, 500, 400), Color(0.3, 0.31, 0.3), false, 2)
	draw_string(fonte, Vector2(24, 76), str(TranslationServer.translate("EMBALAGENS VAZIAS")), HORIZONTAL_ALIGNMENT_LEFT, 300, 13, Game.AMBER)
	var bolsa = Rect2(origem, Vector2(colunas, linhas) * celula)
	draw_rect(bolsa.grow(12), Color(0.55, 0.53, 0.46))
	draw_rect(bolsa, Color(0.07, 0.08, 0.08))
	for x in range(colunas + 1):
		draw_line(origem + Vector2(x * celula, 0), origem + Vector2(x * celula, linhas * celula), Color(1, 1, 1, 0.12), 1)
	for y in range(linhas + 1):
		draw_line(origem + Vector2(0, y * celula), origem + Vector2(colunas * celula, y * celula), Color(1, 1, 1, 0.12), 1)
	draw_string(fonte, Vector2(origem.x, origem.y - 22), str(TranslationServer.translate("BOLSA DE LIXO")), HORIZONTAL_ALIGNMENT_LEFT, 320, 13, Game.AMBER)
	for i in range(tamanhos.size()):
		if i != na_mao:
			desenhar_embalagem(i, caixa(i).position, 1.0)
	if na_mao >= 0:
		var casa = casa_do_mouse(na_mao, mouse)
		var cor = Game.BAD
		if cabe(na_mao, casa):
			cor = Game.GOOD
		if bolsa.grow(40).has_point(mouse):
			draw_rect(Rect2(origem + casa * celula, tamanhos[na_mao] * celula), cor, false, 3)
		desenhar_embalagem(na_mao, mouse - tamanhos[na_mao] * celula / 2.0, 0.8)
	if acabou and acertou:
		draw_rect(Rect2(origem + Vector2(-12, -12), Vector2(colunas * celula + 24, 14)), Color(0.75, 0.72, 0.6))
	draw_rect(Rect2(0, 0, 960, 60), Color(0.06, 0.07, 0.065))
	draw_rect(Rect2(0, 500, 960, 40), Color(0.06, 0.07, 0.065))
	var borda = Game.AMBER
	if alerta > 0:
		borda = Game.BAD
	draw_rect(Rect2(0, 0, 960, 540), borda, false, 3)
