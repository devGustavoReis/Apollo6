extends Control
signal completed

const ALIGN_STEP := 3
const ALIGN_TOLERANCE := 5.0
const STEPS := ["Abrir compartimento", "Soltar trava", "Retirar cartucho usado", "Alinhar cartucho novo", "Encaixar cartucho", "Fechar compartimento"]
const INSTRUCTIONS := [
	"Abra a tampa para acessar o filtro de CO₂.",
	"Solte a trava que prende o cartucho ao suporte.",
	"Retire o cartucho usado do trilho.",
	"Arraste o controle ou use as setas para alinhar as duas guias.",
	"Deslize o cartucho novo até o fundo do trilho.",
	"Feche a tampa para concluir a troca.",
]

var step := 0
var angle := 35.0
var pointer: HSlider
var title: Label
var description: Label
var action: Button
var _preview: Control
var _motion: Tween
var _door := 0.0
var _latch := 0.0
var _offset := 0.0
var _alignment: Label
var _housing := StyleBoxFlat.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_housing.bg_color = Color("#283c45")
	_housing.border_color = Color("#7a8e92")
	_housing.set_border_width_all(2)
	_housing.set_corner_radius_all(10)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 624
	center.add_child(panel)
	var padding := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(padding)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	padding.add_child(box)
	box.add_child(Game.make_label("SUPORTE DE VIDA  /  FILTRO LiOH", 16, Game.AMBER))
	title = Game.make_label("", 24)
	box.add_child(title)
	description = Game.make_label("", 17)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(580, 220)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.draw.connect(_draw_cartridge.bind(preview))
	_preview = preview
	box.add_child(preview)
	pointer = HSlider.new()
	pointer.min_value = -45
	pointer.max_value = 45
	pointer.step = 1.0
	pointer.value = angle
	pointer.value_changed.connect(_set_angle)
	pointer.gui_input.connect(_alignment_input)
	box.add_child(pointer)
	_alignment = Game.make_label("", 16)
	box.add_child(_alignment)
	action = Button.new()
	action.pressed.connect(_advance)
	action.custom_minimum_size.y = 44
	box.add_child(action)
	box.add_child(Game.make_label("Esc · Cancelar tentativa", 14))
	_refresh()
	action.grab_focus()
func _draw_cartridge(view: Control) -> void:
	var center := view.size.x * 0.5
	var housing := Rect2(center - 232.0, 12, 464, 194)
	view.draw_rect(housing.grow(3), Color("#11191e"))
	view.draw_style_box(_housing, housing)
	var well := Rect2(center - 136.0, 35, 124, 150)
	var tray := Rect2(center + 17.0, 35, 124, 150)
	for compartment in [well, tray]:
		view.draw_rect(compartment, Color("#101a20"))
		view.draw_rect(compartment, Color("#657a81"), false, 2.0)
	for x in [housing.position.x + 12, housing.end.x - 12]:
		for y in [housing.position.y + 12, housing.end.y - 12]:
			view.draw_circle(Vector2(x, y), 4.0, Color("#a9aaa0"), true, -1.0, true)
	var font := view.get_theme_default_font()
	view.draw_string(font, Vector2(center - 210, 113), str(TranslationServer.translate("FILTRO")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Game.CREAM)
	view.draw_string(font, Vector2(center + 157, 113), str(TranslationServer.translate("RESERVA")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Game.CREAM)

	var new_filter := step >= ALIGN_STEP
	var rotation := deg_to_rad(angle) if step == ALIGN_STEP else 0.0
	var guide := Game.GOOD if _aligned() and new_filter else Game.AMBER
	var cartridge := well.get_center() + Vector2(_offset, 0)
	view.draw_set_transform(cartridge, rotation)
	var body := Rect2(-42, -57, 84, 114)
	view.draw_rect(body, Color("#dedcc4") if new_filter else Color("#8a796b"))
	view.draw_rect(Rect2(-42, -57, 9, 114), Color("#b6b099") if new_filter else Color("#665b53"))
	view.draw_rect(body, Color("#17262d"), false, 3.0)
	view.draw_rect(Rect2(-29, -21, 58, 47), Color("#38545b"))
	view.draw_string(font, Vector2(-22, 0), "LiOH", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Game.CREAM)
	view.draw_string(font, Vector2(-22, 17), str(TranslationServer.translate("NOVO")) if new_filter else str(TranslationServer.translate("USADO")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Game.CREAM)
	view.draw_line(Vector2(-25, -44), Vector2(25, -44), guide, 4.0, true)
	view.draw_set_transform(Vector2.ZERO)
	if step == ALIGN_STEP:
		var target_start := tray.get_center() + Vector2(-26, -65)
		view.draw_line(target_start, target_start + Vector2(52, 0), guide, 3.0, true)
		view.draw_line(target_start, target_start + Vector2(0, 7), guide, 2.0, true)
		view.draw_line(target_start + Vector2(52, 0), target_start + Vector2(52, 7), guide, 2.0, true)

	var cover := Rect2(well.position, Vector2(lerpf(well.size.x, 9.0, _door), well.size.y))
	view.draw_rect(cover, Color("#526a73"))
	view.draw_rect(cover, Color("#aab6b5"), false, 2.0)
	var hinge := Vector2(well.position.x, well.get_center().y)
	view.draw_line(hinge, hinge + Vector2(20 - _latch * 32, _latch * 22), Game.AMBER, 6, true)


func _aligned() -> bool:
	return absf(angle) <= ALIGN_TOLERANCE


func _set_angle(value: float) -> void:
	angle = value
	if step == ALIGN_STEP:
		_refresh_alignment()
	_preview.queue_redraw()


func _alignment_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		pointer.accept_event()
		_advance()


func _refresh_alignment() -> void:
	var ready := _aligned()
	action.disabled = not ready or _motion != null
	var status := str(TranslationServer.translate("Guias alinhadas · Enter para confirmar")) if ready else str(TranslationServer.translate("Ajuste até as duas guias ficarem paralelas"))
	_alignment.text = str(TranslationServer.translate("Ângulo %+.0f°  ·  %s")) % [angle, status]
	_alignment.add_theme_color_override("font_color", Game.GOOD if ready else Game.AMBER)


func _refresh() -> void:
	title.text = "%d/%d   %s" % [step + 1, STEPS.size(), STEPS[step]]
	description.text = INSTRUCTIONS[step]
	action.text = (str(TranslationServer.translate("CONFIRMAR ALINHAMENTO")) if step == ALIGN_STEP else STEPS[step].to_upper())
	pointer.visible = step == ALIGN_STEP
	_alignment.visible = pointer.visible
	action.disabled = false
	if pointer.visible:
		_refresh_alignment()


func _advance() -> void:
	if _motion != null or step >= STEPS.size() or not is_visible_in_tree():
		return
	if step == ALIGN_STEP and not _aligned():
		pointer.grab_focus()
		Sound.play_cue("warning")
		return
	Sound.play_cue("switch")
	action.disabled = true
	pointer.editable = false
	_motion = create_tween().set_trans(Tween.TRANS_SINE)
	var drawings := [
		[1.0, 0.0, 0.0], [1.0, 1.0, 0.0], [1.0, 1.0, 153.0],
		[1.0, 1.0, 153.0], [1.0, 0.0, 0.0], [0.0, 0.0, 0.0],
	]
	var target: Array = drawings[step]
	_motion.tween_method(_animate.bind(Vector3(_door, _latch, _offset), Vector3(target[0], target[1], target[2])), 0.0, 1.0, 0.32)
	if step == ALIGN_STEP:
		_motion.parallel().tween_method(_set_angle, angle, 0.0, 0.32)
	_motion.tween_callback(_finish_step)


func _animate(weight: float, from: Vector3, to: Vector3) -> void:
	var pose := from.lerp(to, weight)
	_door = pose.x
	_latch = pose.y
	_offset = pose.z
	_preview.queue_redraw()


func _finish_step() -> void:
	_motion = null
	if not is_visible_in_tree() or is_queued_for_deletion():
		return
	step += 1
	if step == STEPS.size():
		Sound.play_cue("success", "Interface")
		completed.emit()
		return
	pointer.editable = true
	_refresh()
	if step == ALIGN_STEP:
		pointer.grab_focus()
	else:
		action.grab_focus()
	_preview.queue_redraw()
