extends Control
## Planejamento da missão: orçamento, massa, energia, suprimentos e ciência.

const STARFIELD := preload("res://scripts/ui/starfield.gd")
const CATEGORIES := [
	["supply", "SUPRIMENTOS", "Comida e água para 8 dias. Reserva extra dá margem contra imprevistos."],
	["science", "INSTRUMENTOS CIENTÍFICOS", "Geram os dados científicos. Têm custo, massa e alguns consomem energia."],
	["reserve", "RESERVAS E EQUIPAMENTOS", "Não geram ciência, mas protegem a missão."],
]
const TUTORIAL := [
	["OBJETIVO DA MISSÃO", "Levar a tripulação até a Lua, pousar com segurança e trazer o máximo de dados científicos."],
	["ORÇAMENTO E MASSA", "Cada item custa dinheiro e pesa. O foguete tem limite de carga. Acompanhe as barras à direita."],
	["ENERGIA", "Alguns instrumentos consomem energia elétrica. Se passar da capacidade, haverá alertas durante a viagem."],
	["ESCOLHAS", "Use + e − para escolher. Passe o mouse sobre um item para ver detalhes e a origem dos números. Não basta levar o mais caro: equilíbrio é a chave."],
]

var _qty_labels := {}
var _bars := {}
var _messages: RichTextLabel
var _detail: RichTextLabel
var _launch: Button
var _tutorial_panel: PanelContainer
var _tutorial_step := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Control.new()
	bg.set_script(STARFIELD)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var s := MissionState.settings()
	root.add_child(Game.make_label("PLANEJAMENTO DA MISSÃO · DIFICULDADE %s" % s["name"], 24, Game.AMBER))
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)
	_build_catalog(columns)
	_build_summary(columns)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	root.add_child(buttons)
	var help := Button.new()
	help.text = "AJUDA"
	help.pressed.connect(_show_tutorial.bind(0))
	buttons.add_child(help)
	var back := Button.new()
	back.text = "VOLTAR AO MENU"
	back.pressed.connect(func(): Game.go("menu"))
	buttons.add_child(back)
	_launch = Button.new()
	_launch.text = "APROVAR PLANO E LANÇAR ▶"
	_launch.custom_minimum_size = Vector2(320, 40)
	_launch.pressed.connect(func(): Game.launch())
	buttons.add_child(_launch)
	MissionState.changed.connect(_refresh)
	_refresh()
	if not MissionState.tutorial_seen:
		_show_tutorial(0)


func _build_catalog(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.4
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for category in CATEGORIES:
		list.add_child(Game.make_label(category[1], 20, Game.AMBER))
		var hint := Game.make_label(category[2], 14, Color(0.65, 0.65, 0.6))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(hint)
		for item in MissionState.catalog:
			if item["category"] == category[0]:
				list.add_child(_item_row(item))
		list.add_child(HSeparator.new())


func _item_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.mouse_entered.connect(_show_detail.bind(item))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(info)
	info.add_child(Game.make_label(item["name"], 17))
	var stats := "US$ %.1f mi · %.0f kg" % [item["cost"], item["mass"]]
	if item["power"] > 0:
		stats += " · %.0f W" % item["power"]
	if item["science"] > 0:
		stats += " · +%d ciência" % item["science"]
	stats += "  (por %s)" % item["unit"]
	info.add_child(Game.make_label(stats, 14, Color(0.7, 0.7, 0.62)))
	var minus := Button.new()
	minus.text = " − "
	minus.pressed.connect(func(): MissionState.set_qty(item["id"], MissionState.qty(item["id"]) - 1))
	minus.mouse_entered.connect(_show_detail.bind(item))
	row.add_child(minus)
	var qty := Game.make_label("0", 20, Game.AMBER)
	qty.custom_minimum_size = Vector2(44, 0)
	qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(qty)
	_qty_labels[item["id"]] = qty
	var plus := Button.new()
	plus.text = " + "
	plus.pressed.connect(func(): MissionState.set_qty(item["id"], MissionState.qty(item["id"]) + 1))
	plus.mouse_entered.connect(_show_detail.bind(item))
	row.add_child(plus)
	return row


func _build_summary(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	box.add_child(Game.make_label("RESUMO DO PLANO", 20, Game.AMBER))
	for key in ["budget", "mass", "power", "food", "water", "science", "fuel"]:
		var label := Game.make_label("", 14)
		box.add_child(label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		box.add_child(bar)
		_bars[key] = [label, bar]
	_messages = RichTextLabel.new()
	_messages.bbcode_enabled = true
	_messages.fit_content = true
	_messages.add_theme_font_size_override("normal_font_size", 14)
	box.add_child(_messages)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.add_theme_font_size_override("normal_font_size", 14)
	_detail.text = "[color=#999]Passe o mouse sobre um item para ver detalhes.[/color]"
	box.add_child(_detail)


func _set_bar(key: String, text: String, value: float, max_value: float, ratio_for_color: float) -> void:
	var label: Label = _bars[key][0]
	var bar: ProgressBar = _bars[key][1]
	label.text = text
	bar.max_value = maxf(max_value, 0.001)
	bar.value = minf(value, max_value)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Game.level_color(ratio_for_color)
	bar.add_theme_stylebox_override("fill", fill)


func _refresh() -> void:
	var ms := MissionState
	var s := ms.settings()
	for id in _qty_labels:
		_qty_labels[id].text = str(ms.qty(id))
	var cost := ms.plan_cost()
	var mass := ms.plan_mass()
	var power := ms.plan_power()
	var capacity := ms.plan_power_capacity()
	_set_bar("budget", "Orçamento: US$ %.1f / %.1f mi" % [cost, s["budget"]], cost, s["budget"], cost / s["budget"] * 0.95)
	_set_bar("mass", "Massa da carga: %.0f / %.0f kg" % [mass, s["mass_limit"]], mass, s["mass_limit"], mass / s["mass_limit"] * 0.95)
	_set_bar("power", "Energia dos instrumentos: %.0f / %.0f W" % [power, capacity], power, capacity, power / capacity * 0.95 if capacity > 0 else 1.0)
	var days := ms.MISSION_DAYS
	var food := ms.qty("food_day")
	var water := ms.qty("water_day")
	_set_bar("food", "Comida: %d dias (necessário: %d)" % [food, days], food, 14, 1.0 if food < days else (0.7 if food == days else 0.3))
	_set_bar("water", "Água: %d dias (necessário: %d)" % [water, days], water, 14, 1.0 if water < days else (0.7 if water == days else 0.3))
	_set_bar("science", "Ciência potencial: %d pontos" % ms.plan_science(), ms.plan_science(), 117, 0.3 if ms.plan_science() >= 40 else 0.7)
	_set_bar("fuel", "Tempo de motor no pouso: %.0f s a 100%%" % ms.plan_landing_fuel(), ms.plan_landing_fuel(), 110, 0.3 if ms.qty("propellant_reserve") > 0 else 0.7)
	var result := ms.validate_plan()
	var text := ""
	for error in result["errors"]:
		text += "[color=#ff6655]✖ %s[/color]\n" % error
	for warning in result["warnings"]:
		text += "[color=#ffcc44]! %s[/color]\n" % warning
	if result["ok"]:
		text += "[color=#77ee77]✔ Plano viável. Houston pode aprovar o lançamento.[/color]"
	_messages.text = text
	_launch.disabled = not result["ok"]


func _show_detail(item: Dictionary) -> void:
	_detail.text = "[color=#f5bd5c]%s[/color]\n%s\n\n[color=#9a9]Origem dos números:[/color] [color=#bbb]%s[/color]" % [item["name"], item["description"], item["source"]]


func _show_tutorial(step: int) -> void:
	if _tutorial_panel:
		_tutorial_panel.queue_free()
		_tutorial_panel = null
	if step >= TUTORIAL.size():
		MissionState.tutorial_seen = true
		return
	_tutorial_step = step
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.set_anchors_preset(Control.PRESET_CENTER)
	_tutorial_panel.custom_minimum_size = Vector2(560, 0)
	_tutorial_panel.position = Vector2(-280, -120)
	add_child(_tutorial_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_tutorial_panel.add_child(box)
	box.add_child(Game.make_label("TUTORIAL %d/%d · %s" % [step + 1, TUTORIAL.size(), TUTORIAL[step][0]], 20, Game.AMBER))
	var body := Game.make_label(TUTORIAL[step][1], 18)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var skip := Button.new()
	skip.text = "PULAR"
	skip.pressed.connect(_show_tutorial.bind(TUTORIAL.size()))
	row.add_child(skip)
	var next := Button.new()
	next.text = "ENTENDI ▶" if step < TUTORIAL.size() - 1 else "COMEÇAR"
	next.pressed.connect(_show_tutorial.bind(step + 1))
	row.add_child(next)
	next.grab_focus()
