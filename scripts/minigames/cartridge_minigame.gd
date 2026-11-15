extends Control
signal completed
var step := 0
var angle := 35.0
var pointer: HSlider
var title: Label
var description: Label
var action: Button
const STEPS := ["Abrir compartimento", "Soltar trava", "Retirar cartucho usado", "Alinhar cartucho novo", "Encaixar cartucho", "Fechar compartimento"]
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.position = Vector2(180, 70)
	panel.custom_minimum_size = Vector2(600, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	title = Game.make_label("", 24)
	box.add_child(title)
	description = Game.make_label("Cartucho de LiOH remove CO₂. Operação simplificada. ESC cancela.", 15)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(560, 210)
	preview.draw.connect(_draw_cartridge.bind(preview))
	box.add_child(preview)
	pointer = HSlider.new()
	pointer.min_value = -45
	pointer.max_value = 45
	pointer.value = angle
	pointer.value_changed.connect(func(value: float): angle = value; preview.queue_redraw())
	box.add_child(pointer)
	action = Button.new()
	action.pressed.connect(_advance)
	box.add_child(action)
	_refresh()
	action.grab_focus()
func _draw_cartridge(view: Control) -> void:
	view.draw_rect(Rect2(130, 20, 290, 165), Color("#253744"))
	view.draw_rect(Rect2(220, 40, 120, 125), Color("#101923"))
	var offset := 0.0 if step < 3 or step >= 5 else 80.0
	view.draw_set_transform(Vector2(280 + offset, 100), deg_to_rad(angle if step == 3 else 0))
	view.draw_rect(Rect2(-42, -58, 84, 116), Color("#b2b8ad"))
	view.draw_rect(Rect2(-27, -26, 54, 35), Color("#476c71"))
	view.draw_line(Vector2(-40, -45), Vector2(40, -45), Color("#f4c479"), 6)
	view.draw_set_transform(Vector2.ZERO)
func _refresh() -> void:
	title.text = "LIFE SUPPORT · " + STEPS[step]
	action.text = STEPS[step].to_upper()
	pointer.visible = step == 3
func _advance() -> void:
	if step == 3 and absf(angle) > 5.0:
		description.text = "Alinhe a guia amarela. Use as setas no controle ou arraste até o centro."
		pointer.grab_focus()
		Sound.play_cue("warning")
		return
	Sound.play_cue("switch")
	step += 1
	if step == STEPS.size():
		action.disabled = true
		completed.emit()
		return
	_refresh()
	queue_redraw()
