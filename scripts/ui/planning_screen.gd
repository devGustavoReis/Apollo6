extends Control
## Catálogo de carga e resumo do plano. MissionState continua sendo a fonte das regras.

const STARFIELD := preload("res://scripts/ui/starfield.gd")
const EQUIPMENT_ATLAS := preload("res://assets/ui/planning/equipment_atlas.png")
const ASSIST_ATLAS := preload("res://assets/ui/planning/assist_atlas.png")
const SPRITES := {
	"food_day": Vector2i(0, 0), "water_day": Vector2i(1, 0),
	"sample_kit": Vector2i(2, 0), "seismometer": Vector2i(3, 0),
	"retroreflector": Vector2i(0, 1), "solar_wind": Vector2i(1, 1),
	"camera": Vector2i(2, 1), "magnetometer": Vector2i(3, 1),
	"battery_pack": Vector2i(0, 2), "propellant_reserve": Vector2i(1, 2),
	"spare_parts": Vector2i(2, 2),
}
const ASSIST_SPRITES := {
	"fastening_kit": Vector2i(0, 0), "sealing_kit": Vector2i(1, 0),
	"signal_meter": Vector2i(0, 1), "blackout_kit": Vector2i(1, 1),
}
const CATEGORIES := {
	"science": ["Instrumentos", "Leve pelo menos um instrumento científico."],
	"supply": ["Suprimentos", "Garanta comida e água para os %d dias da missão."],
	"reserve": ["Reservas", "Leve reservas para lidar com imprevistos na viagem e no pouso."],
	"assist": ["Ferramentas", "Ferramentas opcionais: %d%% de chance de recuperar um erro na tarefa correspondente."],
}
const INK := Color("#091520")
const PANEL := Color("#10202e")
const CARD := Color("#182c3b")
const OUTLINE := Color("#304758")
const TEXT := Color("#f1f6fa")
const MUTED := Color("#aec4d2")
const MINT := Color("#83e4ce")
const AMBER := Color("#f7c584")
const RED := Color("#ffaeac")

var _tabs: Dictionary = {}
var _category_grids: Dictionary = {}
var _item_controls: Dictionary = {}
var _meters: Dictionary = {}
var _catalog_scroll: ScrollContainer
var _category_hint: Label
var _food: Label
var _water: Label
var _engine: Label
var _science: Label
var _issues: VBoxContainer
var _status: Label
var _launch: Button
var _info_dialog: AcceptDialog


func _ready() -> void:
	Sound.enter_scene("planning")
	theme = _planning_theme()
	var background := Control.new()
	background.set_script(STARFIELD)
	add_child(background)
	var tint := ColorRect.new()
	tint.color = Color(0.035, 0.09, 0.14, 0.63)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tint)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 32
	margin.offset_top = 24
	margin.offset_right = -32
	margin.offset_bottom = -22
	add_child(margin)
	var layout := _stack(14)
	margin.add_child(layout)
	_build_header(layout)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	_build_catalog(columns)
	_build_summary(columns)
	_build_footer(layout)

	_info_dialog = AcceptDialog.new()
	_info_dialog.theme = theme
	_info_dialog.dialog_autowrap = true
	_info_dialog.get_ok_button().text = "Fechar"
	add_child(_info_dialog)

	MissionState.changed.connect(_refresh)
	_select_category("science")
	_refresh()


func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	parent.add_child(header)
	var title := _stack(2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	title.add_child(_label("Planejamento da missão", 38))
	title.add_child(_label("Monte a carga da nave e confira o plano antes de lançar.", 17, MUTED, true))
	var difficulty := PanelContainer.new()
	difficulty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	difficulty.add_theme_stylebox_override("panel", _box(CARD, OUTLINE, 10, 12, 7))
	difficulty.add_child(_label("Dificuldade  ·  " + str(MissionState.settings()["name"]), 15, MINT))
	header.add_child(difficulty)


func _build_catalog(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 2.3
	parent.add_child(panel)
	var contents := _stack(10)
	panel.add_child(contents)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 7)
	contents.add_child(tabs)
	for category: String in CATEGORIES:
		var tab := Button.new()
		tab.text = CATEGORIES[category][0]
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_select_category.bind(category))
		tabs.add_child(tab)
		_tabs[category] = tab
	_category_hint = _label("", 15, MUTED, true)
	contents.add_child(_category_hint)

	_catalog_scroll = _scroll()
	_catalog_scroll.resized.connect(_adjust_catalog_columns)
	contents.add_child(_catalog_scroll)
	var grids := VBoxContainer.new()
	grids.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_scroll.add_child(grids)
	for category: String in CATEGORIES:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grids.add_child(grid)
		_category_grids[category] = grid
		for item: Dictionary in MissionState.catalog:
			if item["category"] == category:
				grid.add_child(_item_card(item))


func _select_category(category: String) -> void:
	for key in _category_grids:
		var selected: bool = key == category
		_category_grids[key].visible = selected
		_tabs[key].set_pressed_no_signal(selected)
	var hint: String = CATEGORIES[category][1]
	match category:
		"supply":
			hint = hint % MissionState.MISSION_DAYS
		"assist":
			hint = hint % int(MissionState.MINIGAME_ASSIST_CHANCE * 100.0)
	_category_hint.text = hint
	_catalog_scroll.scroll_vertical = 0


func _adjust_catalog_columns() -> void:
	for grid: GridContainer in _category_grids.values():
		grid.columns = 2 if _catalog_scroll.size.x >= 590.0 else 1


func _item_card(item: Dictionary) -> PanelContainer:
	var id: String = item["id"]
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var contents := _stack(8)
	card.add_child(contents)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	contents.add_child(top)
	var assist := ASSIST_SPRITES.has(id)
	var positions := ASSIST_SPRITES if assist else SPRITES
	if positions.has(id):
		var icon_frame := PanelContainer.new()
		icon_frame.add_theme_stylebox_override("panel", _box(INK, OUTLINE, 8, 4, 4))
		icon_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top.add_child(icon_frame)
		var sprite := TextureRect.new()
		var texture := AtlasTexture.new()
		texture.atlas = ASSIST_ATLAS if assist else EQUIPMENT_ATLAS
		var cell := texture.atlas.get_size() / (2.0 if assist else 4.0)
		texture.region = Rect2(Vector2(positions[id]) * cell, cell)
		texture.filter_clip = true
		sprite.texture = texture
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.custom_minimum_size = Vector2(66, 66)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_frame.add_child(sprite)
	var captions := _stack(2)
	captions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(captions)
	captions.add_child(_label(item["name"], 17, TEXT, true))
	var description := _label(item["description"], 14, MUTED, true)
	captions.add_child(description)
	var stats := _label(_item_stats(item), 14, MINT, true)
	contents.add_child(stats)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 5)
	contents.add_child(actions)
	var details := Button.new()
	details.text = "Detalhes"
	details.tooltip_text = "Ver detalhes de " + str(item["name"])
	details.theme_type_variation = &"TextButton"
	details.pressed.connect(_show_item_info.bind(item))
	actions.add_child(details)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(gap)

	_item_controls[id] = {"card": card}
	if int(item["max"]) == 1:
		var toggle := Button.new()
		toggle.custom_minimum_size.x = 106
		toggle.pressed.connect(_toggle_item.bind(id))
		var loaded := _label("Na carga", 14, MINT)
		loaded.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		actions.add_child(loaded)
		actions.add_child(toggle)
		_item_controls[id]["toggle"] = toggle
		_item_controls[id]["loaded"] = loaded
	else:
		var minus := _step_button("−", "Retirar um dia de " + str(item["name"]), id, -1)
		var plus := _step_button("+", "Adicionar um dia de " + str(item["name"]), id, 1)
		var count := _label("", 15)
		count.custom_minimum_size.x = 62
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		actions.add_child(minus)
		actions.add_child(count)
		actions.add_child(plus)
		_item_controls[id].merge({"minus": minus, "count": count, "plus": plus})
	return card


func _item_stats(item: Dictionary) -> String:
	var stats := "US$ %s mi  ·  %d kg" % [_decimal(item["cost"]), int(item["mass"])]
	if item["category"] == "supply":
		return stats + " por dia"
	if float(item["power"]) > 0.0:
		stats += "  ·  %d W" % int(item["power"])
	if int(item["science"]) > 0:
		stats += "  ·  +%d pts" % int(item["science"])
	return stats


func _step_button(text: String, hint: String, id: String, delta: int) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = hint
	button.custom_minimum_size = Vector2(34, 32)
	button.pressed.connect(func(): _change_quantity(id, delta))
	return button


func _toggle_item(id: String) -> void:
	_change_quantity(id, -1 if MissionState.qty(id) > 0 else 1)


func _change_quantity(id: String, delta: int) -> void:
	var previous := MissionState.qty(id)
	MissionState.set_qty(id, previous + delta)
	if MissionState.qty(id) != previous:
		Sound.play_cue("add" if delta > 0 else "remove", "Interface")


func _build_summary(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 346
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var shell := _stack(11)
	panel.add_child(shell)
	shell.add_child(_label("Resumo do plano", 23))
	var scroll := _scroll()
	shell.add_child(scroll)
	var contents := _stack(9)
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contents)

	var metrics := GridContainer.new()
	metrics.columns = 2
	metrics.add_theme_constant_override("h_separation", 8)
	metrics.add_theme_constant_override("v_separation", 8)
	contents.add_child(metrics)
	_add_meter(metrics, "budget", "Orçamento")
	_add_meter(metrics, "mass", "Massa da carga")
	_add_meter(metrics, "power", "Energia")
	var science := _stat_tile(metrics, "Ciência prevista")
	_science = _label("", 17)
	science.add_child(_science)

	var supplies := HBoxContainer.new()
	supplies.add_theme_constant_override("separation", 8)
	contents.add_child(supplies)
	var food := _stat_tile(supplies, "Comida")
	_food = _label("", 17)
	food.add_child(_food)
	var water := _stat_tile(supplies, "Água")
	_water = _label("", 17)
	water.add_child(_water)

	_engine = _label("", 14, MUTED, true)
	contents.add_child(_engine)
	_issues = _stack(5)
	contents.add_child(_issues)


func _stat_tile(parent: Container, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(CARD, OUTLINE, 8, 9, 7))
	parent.add_child(panel)
	var contents := _stack(4)
	panel.add_child(contents)
	contents.add_child(_label(title, 13, MUTED))
	return contents


func _add_meter(parent: Container, id: String, title: String) -> void:
	var tile := _stat_tile(parent, title)
	var value := _label("", 16, TEXT, true)
	tile.add_child(value)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 5
	tile.add_child(bar)
	_meters[id] = [value, bar]


func _build_footer(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL, OUTLINE, 11, 12, 9))
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	panel.add_child(row)
	var back := Button.new()
	back.text = "Voltar ao menu"
	back.pressed.connect(func():
		Sound.play_cue("back", "Interface")
		Game.go("menu"))
	row.add_child(back)
	var help := Button.new()
	help.text = "Ajuda"
	help.pressed.connect(_show_help)
	row.add_child(help)
	_status = _label("", 15, MUTED, true)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_status)
	_launch = Button.new()
	_launch.text = "Aprovar e lançar  ›"
	_launch.theme_type_variation = &"LaunchButton"
	_launch.custom_minimum_size = Vector2(190, 42)
	_launch.pressed.connect(func():
		Sound.play_cue("confirm", "Interface")
		Game.launch())
	_launch.gui_input.connect(func(event: InputEvent):
		if _launch.disabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Sound.play_cue("warning", "Interface"))
	row.add_child(_launch)


func _refresh() -> void:
	for id: String in _item_controls:
		_refresh_card(id)
	var ms := MissionState
	var s := ms.settings()
	var cost := ms.plan_cost()
	var mass := ms.plan_mass()
	var power := ms.plan_power()
	var capacity := ms.plan_power_capacity()
	_set_meter("budget", "US$ %s / %s mi" % [_decimal(cost), _decimal(s["budget"])], cost, s["budget"], RED)
	_set_meter("mass", "%d / %d kg" % [int(mass), int(s["mass_limit"])], mass, s["mass_limit"], RED)
	_set_meter("power", "%d / %d W" % [int(power), int(capacity)], power, capacity, AMBER)
	var science := ms.plan_science()
	_science.text = "%d pontos" % science
	_science.add_theme_color_override("font_color", MINT if science > 0 else AMBER)
	_show_days(_food, ms.qty("food_day"))
	_show_days(_water, ms.qty("water_day"))
	_engine.text = "Motor no pouso: %.0f s a 100%%" % ms.plan_landing_fuel()

	var validation := ms.validate_plan()
	_update_issues(validation["errors"], validation["warnings"])
	_launch.disabled = not validation["ok"]
	_launch.tooltip_text = "\n".join(validation["errors"]) if _launch.disabled else ""
	var missing: int = validation["errors"].size()
	_status.text = "Plano pronto para lançar" if missing == 0 else (
		"1 requisito pendente" if missing == 1 else "%d requisitos pendentes" % missing
	)
	_status.add_theme_color_override("font_color", MINT if missing == 0 else AMBER)


func _refresh_card(id: String) -> void:
	var quantity := MissionState.qty(id)
	var controls: Dictionary = _item_controls[id]
	var selected := quantity > 0
	var card: PanelContainer = controls["card"]
	card.theme_type_variation = &"LoadedCard" if selected else &"CargoCard"
	if controls.has("toggle"):
		controls["loaded"].visible = selected
		var toggle: Button = controls["toggle"]
		toggle.text = "Retirar" if selected else "+ Adicionar"
		toggle.tooltip_text = ("Retirar " if selected else "Adicionar ") + str(MissionState.items[id]["name"])
		toggle.theme_type_variation = &"SelectedButton" if selected else &"AddButton"
	else:
		controls["count"].text = "%d dia%s" % [quantity, "" if quantity == 1 else "s"]
		controls["minus"].disabled = quantity == 0
		controls["plus"].disabled = quantity >= int(MissionState.items[id]["max"])


func _set_meter(id: String, text: String, value: float, limit: float, over_color: Color) -> void:
	var caption: Label = _meters[id][0]
	var bar: ProgressBar = _meters[id][1]
	var color := over_color if value > limit + 0.001 else MINT
	caption.text = text
	caption.add_theme_color_override("font_color", color if value > limit + 0.001 else TEXT)
	bar.max_value = maxf(limit, 0.001)
	bar.value = value
	bar.add_theme_stylebox_override("fill", _box(color, Color.TRANSPARENT, 3, 0, 0))


func _show_days(label: Label, days: int) -> void:
	var minimum := MissionState.MISSION_DAYS
	label.text = "%d / %d dias" % [days, minimum]
	label.add_theme_color_override("font_color", RED if days < minimum else AMBER if days == minimum else MINT)


func _update_issues(errors: Array, warnings: Array) -> void:
	for child in _issues.get_children():
		_issues.remove_child(child)
		child.queue_free()
	if not errors.is_empty():
		_issues.add_child(_label("Para poder lançar", 15, RED))
		for error: String in errors:
			_issues.add_child(_label("•  " + error, 14, TEXT, true))
	if not warnings.is_empty():
		_issues.add_child(_label("Alertas da missão", 15, AMBER))
		for warning: String in warnings:
			_issues.add_child(_label("•  " + warning, 14, MUTED, true))


func _show_item_info(item: Dictionary) -> void:
	var description: String = item["description"]
	if item["category"] == "assist":
		description += "\n\nA ferramenta tem %d%% de chance de concluir a tarefa após um erro. Ela é opcional." % int(MissionState.MINIGAME_ASSIST_CHANCE * 100.0)
	_open_info(item["name"], "%s\n\nOrigem dos números\n%s" % [description, item["source"]])


func _show_help() -> void:
	_open_info("Como planejar a missão", (
		"1. Adicione um instrumento científico para coletar dados na Lua.\n\n"
		+ "2. Confira se há comida e água para %d dias e se a carga está dentro do orçamento e da massa permitida.\n\n"
		+ "3. Se quiser, leve bateria, propelente ou ferramentas para lidar com imprevistos. "
		+ "Use o resumo para comparar os limites e os alertas antes de lançar.\n\n"
		+ "A aba Ferramentas mostra a assistência disponível para as tarefas da cabine."
	) % MissionState.MISSION_DAYS)


func _open_info(title: String, body: String) -> void:
	_info_dialog.title = title
	_info_dialog.dialog_text = body
	_info_dialog.popup_centered(Vector2i(520, 0))


func _decimal(value: float) -> String:
	return ("%.1f" % value).replace(".", ",")


func _stack(spacing: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", spacing)
	return box


func _label(text: String, font_size: int, color := TEXT, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	return scroll


func _box(bg: Color, border: Color, radius: int, horizontal: int, vertical: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


func _planning_theme() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Inter", "Segoe UI", "Noto Sans", "sans-serif"])
	result.default_font = font
	result.default_font_size = 16
	result.set_color("font_color", "Label", TEXT)
	result.set_stylebox("panel", "PanelContainer", _box(PANEL, OUTLINE, 12, 14, 13))
	for variant in [&"CargoCard", &"LoadedCard"]:
		result.set_type_variation(variant, &"PanelContainer")
	result.set_stylebox("panel", &"CargoCard", _box(CARD, OUTLINE, 9, 10, 9))
	result.set_stylebox("panel", &"LoadedCard", _box(Color("#1b3843"), Color("#509c90"), 9, 10, 9))

	result.set_stylebox("normal", "Button", _box(INK, OUTLINE, 7, 10, 6))
	result.set_stylebox("hover", "Button", _box(Color("#233f4c"), MINT, 7, 10, 6))
	result.set_stylebox("pressed", "Button", _box(Color("#21504f"), MINT, 7, 10, 6))
	result.set_stylebox("disabled", "Button", _box(INK, OUTLINE, 7, 10, 6))
	result.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, AMBER, 7, 10, 6))
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", TEXT)
	result.set_color("font_pressed_color", "Button", MINT)
	result.set_color("font_disabled_color", "Button", Color("#8195a2"))
	for variant in [&"TextButton", &"AddButton", &"SelectedButton", &"LaunchButton"]:
		result.set_type_variation(variant, &"Button")
	result.set_stylebox("normal", &"TextButton", _box(Color.TRANSPARENT, Color.TRANSPARENT, 7, 6, 6))
	result.set_color("font_color", &"TextButton", MUTED)
	result.set_stylebox("normal", &"AddButton", _box(Color("#204651"), Color("#45736e"), 7, 10, 6))
	result.set_stylebox("normal", &"SelectedButton", _box(Color("#21504f"), Color("#509c90"), 7, 10, 6))
	result.set_color("font_color", &"SelectedButton", MINT)
	result.set_stylebox("normal", &"LaunchButton", _box(MINT, MINT, 8, 12, 8))
	result.set_stylebox("hover", &"LaunchButton", _box(Color("#b6f7e7"), MINT, 8, 12, 8))
	result.set_stylebox("pressed", &"LaunchButton", _box(Color("#69c4b0"), MINT, 8, 12, 8))
	result.set_color("font_color", &"LaunchButton", INK)
	result.set_color("font_hover_color", &"LaunchButton", INK)
	result.set_color("font_pressed_color", &"LaunchButton", INK)
	result.set_stylebox("background", "ProgressBar", _box(INK, Color.TRANSPARENT, 3, 0, 0))
	return result
