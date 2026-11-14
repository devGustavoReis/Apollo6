extends Control
## Fundo estrelado simples para as telas de interface.

var _stars: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 1969
	for i in 220:
		_stars.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(1.0, 3.0), rng.randf_range(0.25, 0.9)])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.035))
	for star in _stars:
		var p: Vector2 = star[0] * size
		var s: float = star[1]
		draw_rect(Rect2(p.floor(), Vector2(s, s).floor()), Color(1, 0.97, 0.9, star[2]))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
