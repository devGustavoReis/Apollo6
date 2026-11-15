extends Control

var modulo = Vector2.ZERO
var velocidade = Vector2.ZERO
var cor_velocidade = Color.WHITE
var alcance = 60.0
var escala_velocidade = 10.0


func _ready():
	custom_minimum_size = Vector2(170, 170)


func para_tela(ponto):
	var centro = size / 2
	var raio = size.x / 2 - 8
	return centro + ponto / alcance * raio


func _draw():
	var fonte = get_theme_default_font()
	var centro = size / 2
	var raio = size.x / 2 - 8
	draw_circle(centro, raio, Color(0.02, 0.03, 0.03))
	draw_arc(centro, raio, 0, TAU, 40, Game.AMBER.darkened(0.25), 2)
	draw_arc(centro, raio * 20.0 / alcance, 0, TAU, 32, Color(1, 1, 1, 0.2), 1)
	draw_arc(centro, raio * 40.0 / alcance, 0, TAU, 32, Color(1, 1, 1, 0.2), 1)
	draw_line(centro - Vector2(raio, 0), centro + Vector2(raio, 0), Color(1, 1, 1, 0.12), 1)
	draw_line(centro - Vector2(0, raio), centro + Vector2(0, raio), Color(1, 1, 1, 0.12), 1)
	draw_circle(centro, raio * 8.0 / alcance, Color(0.3, 0.9, 0.4, 0.25))
	draw_rect(Rect2(centro - Vector2(5, 5), Vector2(10, 10)), Game.GOOD, false, 2)
	draw_string(fonte, Vector2(centro.x - 6, 14), "↑", HORIZONTAL_ALIGNMENT_LEFT, 20, 12, Game.CREAM)
	var ponto = para_tela(modulo)
	var fora = modulo.length() > alcance
	if fora:
		ponto = centro + modulo.normalized() * (raio - 6)
		draw_string(fonte, ponto + Vector2(-20, -10), "%.0f m" % modulo.length(), HORIZONTAL_ALIGNMENT_LEFT, 60, 12, Game.WARN)
	var seta = velocidade * escala_velocidade
	if seta.length() > raio:
		seta = seta.normalized() * raio
	if seta.length() > 2:
		draw_line(ponto, ponto + seta, cor_velocidade, 3)
		var lado = seta.normalized()
		draw_line(ponto + seta, ponto + seta - lado.rotated(0.5) * 7, cor_velocidade, 3)
		draw_line(ponto + seta, ponto + seta - lado.rotated(-0.5) * 7, cor_velocidade, 3)
	var forma = PackedVector2Array([ponto + Vector2(0, -7), ponto + Vector2(6, 5), ponto + Vector2(-6, 5)])
	draw_colored_polygon(forma, Game.WARN if fora else Game.CREAM)
