extends Control
## Menu principal: iniciar, dificuldade, configurações, créditos e sair.
## Visual de TV antiga: cenário lunar 3D em meia resolução (menu_backdrop.gd), logotipo
## (menu_logo.gd), fonte de pixels (pixel_font.gd) e filtro de tubo sobre a tela inteira.

const BACKDROP := preload("res://scripts/ui/menu_backdrop.gd")
const LOGO := preload("res://scripts/ui/menu_logo.gd")
const PIXEL_FONT := preload("res://scripts/ui/pixel_font.gd")
const STARS_SHADER := preload("res://assets/shaders/menu/starfield.gdshader")
const PIXEL_SHADER := preload("res://assets/shaders/menu/pixelate.gdshader")
const CRT_SHADER := preload("res://assets/shaders/menu/crt.gdshader")

const DIFF_KEYS := ["easy", "normal", "hard"]
const VERSION := "v1.0"
const WHITE := Color(0.98, 0.98, 0.96)
const GRAY := Color(0.70, 0.71, 0.74)
const FOOTER := Color(0.84, 0.84, 0.86)
const SHADOW := Color(0, 0, 0, 0.85)
const BUS_LABELS := {"Master": "GERAL", "Music": "MÚSICA", "Voice": "VOZES", "SFX": "EFEITOS", "Ambience": "AMBIENTE"}

## O filtro de TV vale para a sessão inteira, não só para esta visita ao menu.
static var crt_enabled := true

var _difficulty := 1
var _items: Array[Button] = []
var _diff_item: Button
var _hint: Label
var _hints := {}
var _sub_panel: Control
var _last_item: Button
var _backdrop: Node3D
var _logo: Node2D
var _world: SubViewport
var _stars: ColorRect
var _crt: ColorRect
var _move_sound: AudioStreamPlayer
var _select_sound: AudioStreamPlayer
var _quiet := true  ## evita o som de navegação enquanto o menu é montado


func _ready() -> void:
	Sound.enter_scene("menu")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _build_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_scenery()
	_build_interface()
	_build_screen()
	_move_sound = _tone_player([[660.0, 0.035]], -20.0)
	_select_sound = _tone_player([[660.0, 0.05], [990.0, 0.09]], -16.0)
	_on_difficulty(_difficulty)
	resized.connect(_layout)
	_layout()
	_items[0].grab_focus()
	_quiet = false


func _process(_delta: float) -> void:
	if size.x > 0.0 and size.y > 0.0:
		_backdrop.aim(get_local_mouse_position() / size - Vector2(0.5, 0.5))


func _unhandled_input(event: InputEvent) -> void:
	if _sub_panel and event.is_action_pressed("ui_cancel"):
		_close_panel()
		accept_event()


# ---------- Cenário ----------

func _build_scenery() -> void:
	_stars = ColorRect.new()
	_stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.material = _shader(STARS_SHADER)
	add_child(_stars)
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = 2
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.material = _shader(PIXEL_SHADER)
	add_child(container)
	_world = SubViewport.new()
	_world.transparent_bg = true
	_world.handle_input_locally = false
	_world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_world)
	_backdrop = Node3D.new()
	_backdrop.set_script(BACKDROP)
	_world.add_child(_backdrop)
	_logo = Node2D.new()
	_logo.set_script(LOGO)
	_world.add_child(_logo)
	_world.size_changed.connect(_layout)


func _layout() -> void:
	(_stars.material as ShaderMaterial).set_shader_parameter("view_size", size)
	_logo.position = Vector2(_world.size.x * 0.503, _world.size.y * 0.218).round()


# ---------- Interface ----------

func _build_interface() -> void:
	var tagline := _text("PLANEJE  •  EXPLORE  •  SOBREVIVA", 3, GRAY)
	tagline.add_theme_font_override("font", _spaced(3))
	_pin(tagline, Vector2(0.5, 0.338))
	_pin(_text("UMA MISSÃO LUNAR FICTÍCIA · 1969", 2, Color(0.55, 0.56, 0.62)), Vector2(0.5, 0.385))

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 6)
	menu.custom_minimum_size = Vector2(352, 0)
	menu.anchor_left = 0.5
	menu.anchor_right = 0.5
	menu.anchor_top = 0.468
	menu.anchor_bottom = 0.468
	menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(menu)
	var start := _menu_item(menu, "INICIAR MISSÃO", 50)
	start.pressed.connect(_on_start)
	_diff_item = _menu_item(menu, "", 34, 2)
	_diff_item.gui_input.connect(_on_diff_input)
	var settings := _menu_item(menu, "CONFIGURAÇÕES")
	settings.pressed.connect(_on_settings)
	var credits := _menu_item(menu, "CRÉDITOS")
	credits.pressed.connect(_on_credits)
	var quit := _menu_item(menu, "SAIR")
	quit.pressed.connect(func(): get_tree().quit())
	start.focus_neighbor_top = start.get_path_to(quit)
	quit.focus_neighbor_bottom = quit.get_path_to(start)
	_hints[settings] = "VOLUME, TELA CHEIA E FILTRO DE TV"
	_hints[credits] = "QUEM FEZ O APOLLO6"
	_hints[quit] = "ENCERRAR O JOGO"

	# Faixa de ajuda do item em foco, sobre uma placa escura para destacar do solo.
	var band := CenterContainer.new()
	band.anchor_right = 1.0
	band.anchor_top = 0.893
	band.anchor_bottom = 0.893
	band.grow_vertical = Control.GROW_DIRECTION_BOTH
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.0, 0.0, 0.03, 0.55)
	plate_style.set_content_margin_all(8)
	plate_style.content_margin_left = 16
	plate_style.content_margin_right = 16
	plate.add_theme_stylebox_override("panel", plate_style)
	band.add_child(plate)
	_hint = _text("", 2, Color(0.95, 0.93, 0.84))
	_hint.add_theme_constant_override("line_spacing", 4)
	plate.add_child(_hint)

	_corner(_text("APOLLO6 " + VERSION, 2, FOOTER), 0.0)
	_corner(_text("NASA SPACE APPS CHALLENGE 2026", 2, FOOTER), 1.0)


func _text(content: String, zoom: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", PIXEL_FONT.px(zoom))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", zoom)
	label.add_theme_constant_override("shadow_offset_y", zoom)
	return label


## Fonte com uma coluna extra de pixels entre as letras, para títulos e itens do menu.
func _spaced(zoom: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = PIXEL_FONT.get_font()
	font.spacing_glyph = zoom
	return font


## Prende o rodapé a um canto inferior da tela (0 = esquerdo, 1 = direito).
func _corner(label: Label, side: float) -> void:
	var margin := 44.0 if side < 0.5 else -44.0
	label.anchor_left = side
	label.anchor_right = side
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = margin
	label.offset_right = margin
	label.offset_top = -30.0
	label.offset_bottom = -30.0
	label.grow_horizontal = Control.GROW_DIRECTION_END if side < 0.5 else Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(label)


## Centraliza o controle em um ponto da tela, dado em frações.
func _pin(control: Control, at: Vector2) -> void:
	control.anchor_left = at.x
	control.anchor_right = at.x
	control.anchor_top = at.y
	control.anchor_bottom = at.y
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	control.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(control)


## Item do menu: texto cinza que ganha moldura branca quando está em foco.
func _menu_item(parent: Node, content: String, height := 44, zoom := 3) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, height)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.0, 0.0, 0.02, 0.55)
	frame.border_color = WHITE
	frame.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", frame)
	var label := _text(content, zoom, GRAY)
	label.add_theme_font_override("font", _spaced(zoom))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(label)
	button.set_meta("label", label)
	button.focus_entered.connect(_on_item_focus.bind(button))
	button.focus_exited.connect(func(): label.add_theme_color_override("font_color", GRAY))
	button.mouse_entered.connect(func():
		if button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus())
	button.pressed.connect(func(): _select_sound.play())
	parent.add_child(button)
	_items.append(button)
	return button


func _on_item_focus(button: Button) -> void:
	button.get_meta("label").add_theme_color_override("font_color", WHITE)
	_last_item = button
	_show_hint(_hints.get(button, ""))
	if not _quiet:
		_move_sound.play()


func _show_hint(content: String) -> void:
	_hint.text = content
	_hint.get_parent().visible = content != ""


# ---------- Dificuldade e início ----------

func _on_diff_input(event: InputEvent) -> void:
	var step := 0
	if event.is_action_pressed("ui_left"):
		step = -1
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		step = 1
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		step = -1 if event.position.x < _diff_item.size.x * 0.5 else 1
	if step != 0:
		_diff_item.accept_event()
		_select_sound.play()
		_on_difficulty(wrapi(_difficulty + step, 0, DIFF_KEYS.size()))


func _on_difficulty(index: int) -> void:
	_difficulty = index
	var s: Dictionary = MissionState.DIFFICULTIES[DIFF_KEYS[index]]
	_diff_item.get_meta("label").text = "DIFICULDADE  ◀ %s ▶" % s["name"]
	var info := "%s\nARMAZENAMENTO: %d ITENS · CARGA MÁX.: %.0f KG" % [s["summary"], int(s["storage"]), s["mass_limit"]]
	_hints[_items[0]] = info
	_hints[_diff_item] = info
	if _last_item == _items[0] or _last_item == _diff_item:
		_show_hint(info)


func _on_start() -> void:
	Game.start_new_mission(DIFF_KEYS[_difficulty])


# ---------- Painéis ----------

func _open_panel(title: String) -> VBoxContainer:
	_close_panel()
	for item in _items:
		item.focus_mode = Control.FOCUS_NONE
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0.02, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_sub_panel = shade
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub_panel.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var heading := _text(title, 3, Game.AMBER)
	heading.add_theme_font_override("font", _spaced(3))
	box.add_child(heading)
	return box


func _close_panel() -> void:
	if _sub_panel == null:
		return
	Sound.play_cue("back", "Interface")
	_sub_panel.queue_free()
	_sub_panel = null
	for item in _items:
		item.focus_mode = Control.FOCUS_ALL
	if _last_item:
		_quiet = true
		_last_item.grab_focus()
		_quiet = false


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(func(): _select_sound.play())
	if callback.is_valid():
		button.pressed.connect(callback)
	parent.add_child(button)
	return button


static func is_fullscreen(mode: int) -> bool:
	return mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN


## Tela cheia lê o modo real da janela a cada clique, em vez de guardar um SIM/NÃO próprio.
## Rodando dentro da aba Game do editor (F5 com o jogo embutido) a janela pertence ao
## editor e o pedido é ignorado; o botão avisa em vez de fingir que mudou.
func _fullscreen_toggle(parent: Node) -> void:
	var button := _button(parent, "", Callable())
	if Engine.is_embedded_in_editor():
		button.text = "TELA CHEIA: INDISPONÍVEL NO EDITOR"
		button.tooltip_text = "Rode o jogo fora da aba Game do editor para usar tela cheia."
		button.disabled = true
		return
	var window := get_window()
	var refresh := func(): button.text = "TELA CHEIA: %s" % ("SIM" if is_fullscreen(window.mode) else "NÃO")
	button.pressed.connect(func():
		if is_fullscreen(window.mode):
			window.mode = Window.MODE_WINDOWED
			# Volta para uma janela menor que a tela, centralizada; senão a janela
			# ocupa a tela toda e parece que nada mudou.
			var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
			var target := Vector2i(1280, 720)
			if target.x >= screen.size.x or target.y >= screen.size.y:
				target = Vector2i(screen.size * 0.75)
			window.size = target
			window.position = screen.position + (screen.size - target) / 2
		else:
			window.mode = Window.MODE_FULLSCREEN
		refresh.call())
	refresh.call()


## Botão que alterna entre SIM e NÃO.
func _toggle(parent: Node, text: String, on: bool, callback: Callable) -> void:
	var state := [on]
	var button := _button(parent, "", Callable())
	var refresh := func(): button.text = "%s: %s" % [text, "SIM" if state[0] else "NÃO"]
	button.pressed.connect(func():
		state[0] = not state[0]
		refresh.call()
		callback.call(state[0]))
	refresh.call()


func _on_settings() -> void:
	var box := _open_panel("CONFIGURAÇÕES")
	for bus_name in ["Master", "Music", "Voice", "SFX", "Ambience"]:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus < 0:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var label := _text(BUS_LABELS[bus_name], 2, Game.CREAM)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.custom_minimum_size = Vector2(150, 0)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Sound.volume(bus_name)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(func(value): Sound.set_volume(bus_name, value))
		row.add_child(slider)
		box.add_child(row)
	_fullscreen_toggle(box)
	_toggle(box, "FILTRO DE TV", crt_enabled, func(on):
		crt_enabled = on
		_crt.visible = on)
	_toggle(box, "TREMOR DE TELA", Game.screen_shake, func(on): Game.screen_shake = on)
	_button(box, "FECHAR", _close_panel).grab_focus()


func _on_credits() -> void:
	var box := _open_panel("CRÉDITOS")
	var text := _text(
		"APOLLO6 — Equipe Apollo 6\nCiência da Computação · UNIFAGOC · Ubá, MG\n\n" +
		"Gustavo Raymundo Reis\nRamon Elias Fernandes Siqueira\nPedro da Silva Palma\nPedro Gonçalves de Freitas\nGuilherme Vieira\nIsaque Bahia\n\n" +
		"Missão, personagens e diálogos fictícios, inspirados no programa Apollo da NASA.\n" +
		"Thomas Walker não é um astronauta real.\n" +
		"Dados de referência: NASA (ver docs/nasa_sources.md).\n" +
		"Feito em Godot 4, com auxílio de ferramentas de IA.", 2, Game.CREAM)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_constant_override("line_spacing", 8)
	box.add_child(text)
	_button(box, "FECHAR", _close_panel).grab_focus()


# ---------- Tela, tema e som ----------

func _build_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_crt = ColorRect.new()
	_crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt.material = _shader(CRT_SHADER)
	_crt.visible = crt_enabled
	layer.add_child(_crt)
	# A imagem surge do preto, como um televisor esquentando.
	var curtain := ColorRect.new()
	curtain.color = Color.BLACK
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)
	var tween := create_tween()
	tween.tween_property(curtain, "color:a", 0.0, 0.9)
	tween.tween_callback(curtain.queue_free)


func _shader(shader: Shader) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = PIXEL_FONT.get_font()
	t.default_font_size = PIXEL_FONT.px(2)
	t.set_color("font_color", "Label", Game.CREAM)
	var panel := _box(Color(0.02, 0.03, 0.06, 0.96), WHITE, 3)
	panel.set_content_margin_all(24)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("normal", "Button", _box(Color(0.07, 0.08, 0.12), GRAY.darkened(0.35), 2))
	t.set_stylebox("hover", "Button", _box(Color(0.14, 0.15, 0.22), WHITE, 2))
	t.set_stylebox("pressed", "Button", _box(Color(0.24, 0.20, 0.12), Game.AMBER, 2))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), WHITE, 3))
	t.set_color("font_color", "Button", Game.CREAM)
	t.set_color("font_hover_color", "Button", WHITE)
	t.set_color("font_focus_color", "Button", WHITE)
	t.set_color("font_pressed_color", "Button", Game.AMBER)
	var track := _box(Color(0.08, 0.09, 0.13), GRAY.darkened(0.35), 2)
	track.set_content_margin_all(5)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _box(Game.AMBER.darkened(0.25), Color(0, 0, 0, 0), 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(Game.AMBER, Color(0, 0, 0, 0), 0))
	t.set_icon("grabber", "HSlider", _knob(Game.CREAM))
	t.set_icon("grabber_highlight", "HSlider", _knob(WHITE))
	t.set_icon("grabber_disabled", "HSlider", _knob(GRAY))
	return t


func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_content_margin_all(10)
	return box


func _knob(color: Color) -> ImageTexture:
	var image := Image.create(10, 22, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.03, 0.03, 0.06))
	image.fill_rect(Rect2i(2, 2, 6, 18), color)
	return ImageTexture.create_from_image(image)


## Bipes de onda quadrada no barramento de efeitos. Cada nota é [frequência em Hz, duração em s].
func _tone_player(notes: Array, volume_db: float) -> AudioStreamPlayer:
	var rate := 22050
	var data := PackedByteArray()
	for note in notes:
		var samples := int(rate * note[1])
		var start := data.size()
		data.resize(start + samples * 2)
		for i in samples:
			var envelope := minf(1.0, minf(i, samples - i) / 60.0)
			var wave := 1.0 if fmod(i * note[0] / rate, 1.0) < 0.5 else -1.0
			data.encode_s16(start + i * 2, int(wave * 6000.0 * envelope))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	var player := AudioStreamPlayer.new()
	player.stream = wav
	player.volume_db = volume_db
	if AudioServer.get_bus_index("SFX") >= 0:
		player.bus = "Interface"
	add_child(player)
	return player
