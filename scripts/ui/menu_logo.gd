extends Node2D
## Logotipo "APOLLO6" do menu: letras itálicas de metal, órbita vermelha e o foguete de papel.
## É desenhado por polígonos dentro do SubViewport de meia resolução, então sai em pixel art.
## A origem do nó é o centro das letras.

const CHROME := preload("res://assets/shaders/menu/logo_chrome.gdshader")
const TEXT := "APOLLO6"
const HEIGHT := 50.0   ## altura das letras, em pixels do SubViewport
const W := 0.93        ## largura da letra (altura = 1)
const T := 0.27        ## espessura das hastes verticais
const B := 0.22        ## espessura das barras horizontais
const GAP := 0.115
const SHEAR := 0.29    ## inclinação do itálico
const C := 0.10        ## chanfro dos cantos
const RED := Color(0.84, 0.13, 0.14)
const DARK_RED := Color(0.56, 0.07, 0.10)
const ROCKET_AT := Vector2(170, -48)
const ROCKET_ANGLE := -38.0
const ROCKET_SCALE := 1.7

var _width := 0.0


func _ready() -> void:
	_width = (TEXT.length() * W + (TEXT.length() - 1) * GAP + SHEAR) * HEIGHT
	_layer(_draw_orbit)
	_layer(_draw_extrusion)
	var chrome := ShaderMaterial.new()
	chrome.shader = CHROME
	_layer(_draw_letters).material = chrome


func _layer(painter: Callable) -> Node2D:
	var node := Node2D.new()
	node.draw.connect(painter.bind(node))
	add_child(node)
	return node


# ---------- Letras ----------

func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


## Peças de cada letra, em unidades de altura (x para a direita, y para baixo).
func _pieces(letter: String) -> Array:
	var left_stem := PackedVector2Array([Vector2(0, C), Vector2(C, 0), Vector2(T, 0), Vector2(T, 1), Vector2(C, 1), Vector2(0, 1 - C)])
	match letter:
		"A":
			var apex := W * 0.36
			return [
				PackedVector2Array([Vector2(0, 1), Vector2(apex, 0), Vector2(apex + T * 1.05, 0), Vector2(T * 1.05, 1)]),
				_rect(apex, 0, W - C, B),
				PackedVector2Array([Vector2(W - T, 0), Vector2(W - C, 0), Vector2(W, C), Vector2(W, 1), Vector2(W - T, 1)]),
				_rect(apex * 0.45 + T * 0.5, 0.58, W - T, 0.58 + B * 0.9),
			]
		"P":
			return [
				PackedVector2Array([Vector2(0, C), Vector2(C, 0), Vector2(T, 0), Vector2(T, 1), Vector2(0, 1)]),
				_rect(C, 0, W - C, B),
				PackedVector2Array([Vector2(W - T, 0), Vector2(W - C, 0), Vector2(W, C), Vector2(W, 0.6 - C), Vector2(W - C, 0.6), Vector2(W - T, 0.6)]),
				_rect(T * 0.5, 0.6 - B, W - C, 0.6),
			]
		"O":
			return [
				left_stem,
				PackedVector2Array([Vector2(W - T, 0), Vector2(W - C, 0), Vector2(W, C), Vector2(W, 1 - C), Vector2(W - C, 1), Vector2(W - T, 1)]),
				_rect(C, 0, W - C, B),
				_rect(C, 1 - B, W - C, 1),
			]
		"L":
			return [_rect(0, 0, T, 1), _rect(0, 1 - B, W * 0.94, 1)]
		"6":
			return [
				left_stem,
				_rect(C, 0, W - 0.05, B),
				_rect(T * 0.5, 0.42, W - C, 0.42 + B),
				PackedVector2Array([Vector2(W - T, 0.42), Vector2(W - C, 0.42), Vector2(W, 0.42 + C), Vector2(W, 1 - C), Vector2(W - C, 1), Vector2(W - T, 1)]),
				_rect(C, 1 - B, W - C, 1),
			]
	return []


func _paint_letters(node: Node2D, color: Color, offset: Vector2) -> void:
	var origin := Vector2(-_width * 0.5, -HEIGHT * 0.5)
	for i in TEXT.length():
		for piece in _pieces(TEXT[i]):
			var points := PackedVector2Array()
			var uvs := PackedVector2Array()
			for p in piece:
				var x: float = (i * (W + GAP) + p.x + (1.0 - p.y) * SHEAR) * HEIGHT
				points.append(origin + Vector2(x, p.y * HEIGHT) + offset)
				uvs.append(Vector2(x / _width, p.y))
			node.draw_colored_polygon(points, color, uvs)


func _draw_letters(node: Node2D) -> void:
	_paint_letters(node, Color.WHITE, Vector2.ZERO)


func _draw_extrusion(node: Node2D) -> void:
	_paint_letters(node, Color(0.05, 0.05, 0.12), Vector2(3, 3))
	_paint_letters(node, Color(0.16, 0.17, 0.32), Vector2(2, 2))
	_paint_letters(node, Color(0.27, 0.29, 0.46), Vector2(1, 1))


# ---------- Órbita e foguete ----------

func _orbit_point(angle_deg: float) -> Vector2:
	var angle := deg_to_rad(angle_deg)
	return Vector2(38, 15) + Vector2(cos(angle) * 97.0, sin(angle) * 66.0).rotated(deg_to_rad(-19.0))


func _ribbon(node: Node2D, a: Vector2, b: Vector2, wa: float, wb: float, color: Color, side := 0.0) -> void:
	var normal := (b - a).orthogonal().normalized()
	node.draw_colored_polygon(PackedVector2Array([
		a + normal * wa * (0.5 + side), b + normal * wb * (0.5 + side),
		b - normal * wb * (0.5 - side), a - normal * wa * (0.5 - side)]), color)


func _draw_orbit(node: Node2D) -> void:
	# Arco que afina nas pontas, mais grosso no trecho que passa por cima das letras.
	var steps := 72
	for pass_index in 2:
		for i in steps:
			var s0 := float(i) / steps
			var s1 := float(i + 1) / steps
			var w0 := maxf(1.0, 8.0 * pow(sin(PI * s0), 0.8))
			var w1 := maxf(1.0, 8.0 * pow(sin(PI * s1), 0.8))
			var a := _orbit_point(lerpf(-140.0, 108.0, s0))
			var b := _orbit_point(lerpf(-140.0, 108.0, s1))
			if pass_index == 0:
				_ribbon(node, a, b, w0, w1, DARK_RED)
			else:
				_ribbon(node, a, b, w0 * 0.7, w1 * 0.7, RED, -0.5)
	# Rastro até o foguete.
	var heading := Vector2.RIGHT.rotated(deg_to_rad(ROCKET_ANGLE))
	_ribbon(node, _orbit_point(14.0), ROCKET_AT - heading * 6.0 * ROCKET_SCALE, 4.0, 2.0, RED)
	var plane := Transform2D(deg_to_rad(ROCKET_ANGLE), Vector2.ONE * ROCKET_SCALE, 0.0, ROCKET_AT)
	node.draw_colored_polygon(plane * PackedVector2Array([Vector2(14, 0), Vector2(-5, 0), Vector2(-3, 5)]), Color(0.50, 0.53, 0.63))
	node.draw_colored_polygon(plane * PackedVector2Array([Vector2(14, 0), Vector2(-5, 0), Vector2(-9, 8)]), Color(0.74, 0.76, 0.84))
	node.draw_colored_polygon(plane * PackedVector2Array([Vector2(14, 0), Vector2(-10, -9), Vector2(-5, 0)]), Color(0.98, 0.98, 1.0))
