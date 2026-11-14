extends Control

var alvo = Vector2.ZERO
var velocidade = Vector2.ZERO
var cor_velocidade = Color.WHITE
var alcance = 60.0


func _ready():
	custom_minimum_size = Vector2(150, 150)


func _draw():
	var centro = size / 2
	var raio = size.x / 2 - 4
	draw_circle(centro, raio, Color(0.02, 0.03, 0.03))
	draw_arc(centro, raio, 0, TAU, 40, Game.AMBER.darkened(0.25), 2)
	draw_arc(centro, raio / 2, 0, TAU, 32, Color(1, 1, 1, 0.2), 1)
	draw_line(centro - Vector2(raio, 0), centro + Vector2(raio, 0), Color(1, 1, 1, 0.2), 1)
	draw_line(centro - Vector2(0, raio), centro + Vector2(0, raio), Color(1, 1, 1, 0.2), 1)
	var ponto = alvo / alcance * raio
	if ponto.length() > raio - 6:
		ponto = ponto.normalized() * (raio - 6)
	draw_circle(centro + ponto, 6, Game.AMBER)
	var seta = velocidade * 10
	if seta.length() > raio - 6:
		seta = seta.normalized() * (raio - 6)
	draw_line(centro, centro + seta, cor_velocidade, 3)
	draw_rect(Rect2(centro - Vector2(4, 4), Vector2(8, 8)), Game.CREAM)
