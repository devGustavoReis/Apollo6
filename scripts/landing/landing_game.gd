extends Node
## Minigame do pouso lunar com física simplificada e previsível.
## W/S: potência do motor. A/D e setas: inclinação. Sem teclas, o módulo se nivela sozinho.
## Gravidade lunar real: 1,62 m/s². Demais números: simplificação de gameplay
## inspirada nos limites de projeto do trem de pouso do LM (ver docs/nasa_sources.md).

const MOON_G := 1.62
const MAX_ACCEL := 3.4
const MAX_TILT := 20.0
const TILT_RATE := 35.0
const THROTTLE_RATE := 0.45
const AREA_LIMIT := 260.0
const RADAR_SCRIPT := preload("res://scripts/ui/landing_radar.gd")
const LM_MODEL := "res://assets/models/landing/lunar_module.glb"

@onready var world: SubViewport = $ViewportContainer/SubViewport

var state := "intro"
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var tilt := Vector2.ZERO  ## x = lateral (direita +), y = frente (+)
var throttle := 0.4
var _low_fuel_announced := false
var limits := {}
var lm: Node3D
var flame: MeshInstance3D
var camera: Camera3D
var marker: MeshInstance3D
var marker_mat: StandardMaterial3D
var beacon: MeshInstance3D
var dust: CPUParticles3D
var radar: Control
var _readouts := {}
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _message: Label


func _ready() -> void:
	Sound.enter_scene("landing")
	limits = MissionState.settings()
	_build_world()
	_build_hud()
	_reset_physics()
	if MissionState.last_failure.get("stage", "") == "landing":
		_show_failure()
	else:
		_show_intro()


func _reset_physics() -> void:
	var drift: float = limits["land_drift"]
	pos = Vector3(-drift * 6.0, limits["land_alt"], 0)
	vel = Vector3(drift, -8.0, drift * 0.5)
	tilt = Vector2.ZERO
	throttle = 0.4
	_low_fuel_announced = false
	MissionState.lm_fuel = MissionState.lm_fuel_max
	_apply_visuals()


# ---------- Mundo ----------

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.57, 0.62)
	e.ambient_light_energy = 0.35
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-15, -35, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var ground_noise := FastNoiseLite.new()
	ground_noise.frequency = 0.03
	ground_noise.fractal_octaves = 4
	noise.noise = ground_noise
	noise.color_ramp = Gradient.new()
	noise.color_ramp.set_color(0, Color(0.38, 0.37, 0.35))
	noise.color_ramp.set_color(1, Color(0.62, 0.61, 0.58))
	mat.albedo_texture = noise
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(50, 50, 1)
	mat.roughness = 1.0
	ground.material_override = mat
	world.add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1107
	for i in 40:
		var crater := MeshInstance3D.new()
		var torus := TorusMesh.new()
		var r := rng.randf_range(3.0, 16.0)
		torus.inner_radius = r
		torus.outer_radius = r * 1.25
		torus.rings = 10
		torus.ring_segments = 4
		crater.mesh = torus
		crater.scale = Vector3(1, 0.12, 1)
		crater.position = Vector3(rng.randf_range(-250, 250), 0, rng.randf_range(-250, 250))
		if crater.position.length() < 30:
			continue
		crater.material_override = _flat(Color(0.5, 0.49, 0.46))
		world.add_child(crater)
	for i in 120:
		var rock := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var s := rng.randf_range(0.2, 1.1)
		sphere.radius = s
		sphere.height = s * 1.4
		sphere.radial_segments = 5
		sphere.rings = 3
		rock.mesh = sphere
		rock.position = Vector3(rng.randf_range(-200, 200), s * 0.3, rng.randf_range(-200, 200))
		rock.material_override = _flat(Color(0.45, 0.44, 0.42))
		world.add_child(rock)
	var pad := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 6.0
	ring.outer_radius = 6.6
	ring.rings = 24
	ring.ring_segments = 3
	pad.mesh = ring
	pad.scale = Vector3(1, 0.05, 1)
	pad.position = Vector3(0, 0.02, 0)
	var pad_mat := _flat(Color(1.0, 0.7, 0.25))
	pad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad.material_override = pad_mat
	world.add_child(pad)
	var pad_marks := Node3D.new()
	world.add_child(pad_marks)
	for angle in [0.0, 90.0, 180.0, 270.0]:
		var mark_dir := Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle)))
		_box(Vector3(1.4, 0.04, 1.4), Color(0.95, 0.95, 0.9), mark_dir * 8.0 + Vector3(0, 0.02, 0), pad_marks)
	beacon = MeshInstance3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = 0.25
	beam.bottom_radius = 0.25
	beam.height = 60.0
	beam.radial_segments = 6
	beacon.mesh = beam
	var beam_mat := _flat(Color(1.0, 0.7, 0.25, 0.4))
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beacon.material_override = beam_mat
	beacon.position = Vector3(0, 30, 0)
	world.add_child(beacon)
	var stars := MultiMeshInstance3D.new()
	var star_mm := MultiMesh.new()
	star_mm.transform_format = MultiMesh.TRANSFORM_3D
	var star_mesh := BoxMesh.new()
	star_mesh.size = Vector3(4, 4, 4)
	var star_mat := _flat(Color(1, 0.97, 0.9))
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mesh.material = star_mat
	star_mm.mesh = star_mesh
	star_mm.instance_count = 300
	for i in star_mm.instance_count:
		var star_dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.03, 1), rng.randf_range(-1, 1)).normalized()
		var star_size := rng.randf_range(0.8, 1.6)
		star_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * star_size), star_dir * 1100.0))
	stars.multimesh = star_mm
	world.add_child(stars)
	var earth := MeshInstance3D.new()
	var earth_mesh := SphereMesh.new()
	earth_mesh.radius = 12
	earth_mesh.height = 24
	earth_mesh.radial_segments = 12
	earth_mesh.rings = 6
	earth.mesh = earth_mesh
	var earth_mat := _flat(Color.WHITE)
	earth_mat.albedo_texture = _earth_texture()
	earth_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	earth_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	earth.material_override = earth_mat
	earth.position = Vector3(-120, 160, -400)
	world.add_child(earth)
	_build_lm()
	marker = MeshInstance3D.new()
	var marker_ring := TorusMesh.new()
	marker_ring.inner_radius = 2.7
	marker_ring.outer_radius = 3.0
	marker_ring.rings = 16
	marker_ring.ring_segments = 3
	marker.mesh = marker_ring
	marker.scale = Vector3(1, 0.05, 1)
	marker_mat = _flat(Game.GOOD)
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = marker_mat
	world.add_child(marker)
	dust = CPUParticles3D.new()
	dust.emitting = false
	dust.amount = 40
	dust.lifetime = 1.2
	dust.direction = Vector3(1, 0, 0)
	dust.spread = 180.0
	dust.flatness = 1.0
	dust.gravity = Vector3(0, -MOON_G, 0)
	dust.initial_velocity_min = 5.0
	dust.initial_velocity_max = 11.0
	var grain := BoxMesh.new()
	grain.size = Vector3(0.35, 0.35, 0.35)
	var grain_mat := _flat(Color(0.75, 0.74, 0.7, 0.6))
	grain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grain.material = grain_mat
	dust.mesh = grain
	world.add_child(dust)
	camera = Camera3D.new()
	camera.fov = 70
	camera.near = 0.5
	camera.far = 3000
	world.add_child(camera)
	camera.make_current()


func _earth_texture() -> ImageTexture:
	var image := Image.create(64, 32, false, Image.FORMAT_RGB8)
	var land := FastNoiseLite.new()
	land.seed = 6
	land.frequency = 0.05
	for y in 32:
		for x in 64:
			var around := x / 64.0 * TAU
			var point := Vector3(cos(around) * 14.0, sin(around) * 14.0, y * 1.4)
			var color := Color(0.16, 0.36, 0.78)
			if land.get_noise_3dv(point) > 0.1:
				color = Color(0.3, 0.55, 0.3)
			if y < 3 or y > 28 or land.get_noise_3dv(point * 2.3 + Vector3(50, 0, 0)) > 0.35:
				color = Color(0.92, 0.94, 0.96)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m


func _box(size: Vector3, color: Color, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _flat(color)
	mi.position = at
	parent.add_child(mi)
	return mi


## Módulo lunar low-poly provisório. A origem fica no ponto de contato das sapatas.
func _build_lm() -> void:
	lm = Node3D.new()
	world.add_child(lm)
	if ResourceLoader.exists(LM_MODEL):
		lm.add_child(load(LM_MODEL).instantiate())
	else:
		_build_provisional_lm()
	flame = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.45
	cone.bottom_radius = 0.02
	cone.height = 1.0
	cone.radial_segments = 6
	flame.mesh = cone
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(1.0, 0.7, 0.3, 0.8)
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame.material_override = flame_mat
	lm.add_child(flame)


func _build_provisional_lm() -> void:
	var descent := MeshInstance3D.new()
	var oct := CylinderMesh.new()
	oct.top_radius = 1.7
	oct.bottom_radius = 1.7
	oct.height = 1.5
	oct.radial_segments = 8
	descent.mesh = oct
	descent.material_override = _flat(Color(0.8, 0.62, 0.22))
	descent.position = Vector3(0, 1.9, 0)
	lm.add_child(descent)
	_box(Vector3(2.4, 1.7, 2.2), Color(0.62, 0.62, 0.6), Vector3(0, 3.5, 0), lm)
	_box(Vector3(0.5, 0.4, 0.1), Color(0.1, 0.12, 0.15), Vector3(-0.5, 3.7, -1.12), lm)
	_box(Vector3(0.5, 0.4, 0.1), Color(0.1, 0.12, 0.15), Vector3(0.5, 3.7, -1.12), lm)
	for angle in [45.0, 135.0, 225.0, 315.0]:
		var dir := Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle)))
		var foot := dir * 2.9
		var top := dir * 1.4 + Vector3(0, 2.1, 0)
		var leg := _box(Vector3(0.12, 0.12, top.distance_to(foot)), Color(0.75, 0.6, 0.25), (top + foot) * 0.5, lm)
		leg.look_at_from_position(leg.position, foot, Vector3.UP)
		var pad := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.35
		disc.bottom_radius = 0.4
		disc.height = 0.1
		disc.radial_segments = 8
		pad.mesh = disc
		pad.material_override = _flat(Color(0.7, 0.7, 0.68))
		pad.position = foot + Vector3(0, 0.05, 0)
		lm.add_child(pad)


# ---------- HUD ----------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(330, 0)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(Game.make_label("MÓDULO LUNAR · DESCIDA", 18, Game.AMBER))
	for key in ["alt", "vy", "vh", "tilt", "throttle", "fuel", "dist"]:
		var label := Game.make_label("", 18)
		box.add_child(label)
		_readouts[key] = label
	var limits_label := Game.make_label("Limites para tocar o solo:\nV.vert ≤ %.1f · V.horiz ≤ %.1f m/s · Incl. ≤ %.0f°" % [limits["land_vy"], limits["land_vh"], limits["land_tilt"]], 14, Color(0.7, 0.7, 0.65))
	box.add_child(limits_label)
	box.add_child(Game.make_label("W/S potência · A/D e ↑/↓ inclinam\nsoltar as teclas = nivelar", 14, Color(0.8, 0.8, 0.72)))
	var radar_panel := PanelContainer.new()
	radar_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	radar_panel.position = Vector2(-206, 16)
	layer.add_child(radar_panel)
	var radar_box := VBoxContainer.new()
	radar_panel.add_child(radar_box)
	radar_box.add_child(Game.make_label("ALVO · VISTA DE CIMA", 14, Game.AMBER))
	radar = Control.new()
	radar.set_script(RADAR_SCRIPT)
	radar_box.add_child(radar)
	radar_box.add_child(Game.make_label("ponto = alvo\nlinha = deslizamento", 13, Color(0.7, 0.7, 0.65)))
	_message = Game.make_label("", 22, Game.AMBER)
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.size = Vector2(800, 40)
	_message.position = Vector2(-400, 20)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 6)
	layer.add_child(_message)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(640, 0)
	_panel.position = Vector2(-320, -190)
	layer.add_child(_panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 12)
	_panel.add_child(_panel_box)


func _show_panel(title: String, text: String, button_text: String, callback: Callable) -> void:
	for child in _panel_box.get_children():
		child.queue_free()
	_panel_box.add_child(Game.make_label(title, 24, Game.AMBER))
	var body := Game.make_label(text, 17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(600, 0)
	_panel_box.add_child(body)
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 46)
	button.pressed.connect(callback)
	_panel_box.add_child(button)
	button.call_deferred("grab_focus")
	_panel.visible = true


func _show_intro() -> void:
	_show_panel("POUSO LUNAR",
		"Leve o módulo lunar até o solo com segurança.\n\n" +
		"• W/S ajustam a potência do motor. Cerca de 48% equilibra a gravidade lunar.\n" +
		"• A/D e as setas inclinam o módulo: o motor empurra para o lado inclinado e cancela o deslizamento horizontal.\n" +
		"• Sem teclas de inclinação, o módulo se nivela sozinho.\n" +
		"• Toque o solo devagar, sem deslizar e nivelado. Verde = seguro, amarelo = atenção, vermelho = perigo.\n\n" +
		"Propelente: %.0f s de motor a 100%%. Se falhar, você repete só o pouso." % MissionState.lm_fuel_max,
		"INICIAR DESCIDA", _start)


func _show_failure() -> void:
	var f := MissionState.last_failure
	var text := ""
	for reason in f.get("reasons", []):
		text += "• " + reason + "\n"
	text += "\nComo melhorar:\n"
	for tip in f.get("tips", []):
		text += "• " + tip + "\n"
	text += "\nTentativas até agora: %d" % MissionState.landing_attempts
	_show_panel(f.get("title", "POUSO MALSUCEDIDO"), text, "REPETIR POUSO", func():
		Game.retry_from_checkpoint("landing", "landing"))


func _start() -> void:
	_panel.visible = false
	state = "flying"
	Sound.start_descent()
	Sound.play_cue("ignition")
	Houston.say_recorded("go_for_descent", "Eagle, Houston. You are go for powered descent.", "Módulo lunar, aqui é Houston. Autorizados para a descida motorizada.")


# ---------- Simulação ----------

func _physics_process(delta: float) -> void:
	if state != "flying":
		return
	step(delta,
		Input.get_axis("throttle_down", "throttle_up"),
		Vector2(Input.get_axis("tilt_left", "tilt_right"), Input.get_axis("tilt_back", "tilt_forward")))
	_apply_visuals()


## Avança a física. Público para permitir testes automáticos.
func step(delta: float, throttle_input: float, tilt_input: Vector2) -> void:
	throttle = clampf(throttle + throttle_input * THROTTLE_RATE * delta, 0.0, 1.0)
	var target := tilt_input.limit_length(1.0) * MAX_TILT
	tilt.x = move_toward(tilt.x, target.x, TILT_RATE * delta)
	tilt.y = move_toward(tilt.y, target.y, TILT_RATE * delta)
	var power := throttle if MissionState.lm_fuel > 0.0 else 0.0
	MissionState.lm_fuel = maxf(0.0, MissionState.lm_fuel - power * delta)
	Sound.set_motor(power)
	var fuel_ratio := MissionState.lm_fuel / maxf(MissionState.lm_fuel_max, 0.001)
	Sound.set_landing_margin(fuel_ratio)
	if state == "flying" and fuel_ratio < 0.20 and not _low_fuel_announced:
		_low_fuel_announced = true
		Houston.clear()
		Houston.say_recorded("low_fuel", "Eagle, Houston. Low fuel. Watch your descent rate.",
			"Eagle, aqui é Houston. Propelente baixo. Atenção à velocidade de descida.")
	var accel := thrust_direction() * power * MAX_ACCEL + Vector3.DOWN * MOON_G
	vel += accel * delta
	pos += vel * delta
	if pos.y <= 0.0:
		pos.y = 0.0
		_touchdown()
	elif Vector2(pos.x, pos.z).length() > AREA_LIMIT:
		_fail(["O módulo se afastou demais da área de pouso planejada."], ["Incline para o lado oposto ao deslizamento logo no começo."])


func thrust_direction() -> Vector3:
	return _basis().y


func _basis() -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(-tilt.y), 0, deg_to_rad(-tilt.x)))


func horizontal_speed() -> float:
	return Vector2(vel.x, vel.z).length()


func tilt_angle() -> float:
	return rad_to_deg(_basis().y.angle_to(Vector3.UP))


func _apply_visuals() -> void:
	if lm == null:
		return
	lm.position = pos
	lm.basis = _basis()
	var power := throttle if MissionState.lm_fuel > 0.0 else 0.0
	flame.visible = power > 0.02 and state == "flying"
	flame.scale = Vector3(1, 0.4 + power * 2.2, 1)
	flame.position = Vector3(0, 1.1 - flame.scale.y * 0.5, 0)
	var target_cam := pos + Vector3(0, 6.0, 15.0)
	camera.position = camera.position.lerp(target_cam, 0.15) if camera.position != Vector3.ZERO else target_cam
	camera.look_at(pos + Vector3(0, 2.0, 0), Vector3.UP)
	marker.position = Vector3(pos.x, 0.08, pos.z)
	marker_mat.albedo_color = Game.level_color(horizontal_speed() / limits["land_vh"])
	beacon.visible = pos.y > 12.0
	dust.position = Vector3(pos.x, 0.3, pos.z)
	dust.emitting = flame.visible and pos.y < 15.0
	_update_readouts()


func _update_readouts() -> void:
	var vy := -vel.y
	var vy_ratio: float = 0.0 if pos.y > 25.0 else vy / limits["land_vy"]
	_set_readout("alt", "ALTITUDE      %6.1f m" % pos.y, 0.0 if pos.y > 15.0 else 0.4)
	_set_readout("vy", "V. VERTICAL   %6.1f m/s" % -vy, vy_ratio)
	_set_readout("vh", "V. HORIZONTAL %6.1f m/s" % horizontal_speed(), horizontal_speed() / limits["land_vh"])
	_set_readout("tilt", "INCLINAÇÃO    %6.1f°" % tilt_angle(), tilt_angle() / limits["land_tilt"])
	_set_readout("throttle", "MOTOR         %6.0f%%" % (throttle * 100.0), 0.0)
	var fuel_ratio := MissionState.lm_fuel / MissionState.lm_fuel_max
	_set_readout("fuel", "PROPELENTE    %6.0f s" % MissionState.lm_fuel, 1.0 - fuel_ratio * 2.5)
	_set_readout("dist", "DIST. DO ALVO %6.0f m" % Vector2(pos.x, pos.z).length(), 0.0)
	radar.alvo = Vector2(-pos.x, -pos.z)
	radar.velocidade = Vector2(vel.x, vel.z)
	radar.cor_velocidade = Game.level_color(horizontal_speed() / limits["land_vh"])
	radar.queue_redraw()
	if state == "flying":
		if MissionState.lm_fuel <= 0.0:
			_message.text = "SEM PROPELENTE!"
		elif MissionState.lm_fuel < MissionState.lm_fuel_max * 0.2:
			_message.text = "PROPELENTE BAIXO"
		elif pos.y < 20.0 and vy > limits["land_vy"]:
			_message.text = "DESCIDA RÁPIDA DEMAIS · AUMENTE A POTÊNCIA (W)"
		elif pos.y < 30.0 and horizontal_speed() > limits["land_vh"]:
			_message.text = "DESLIZANDO · INCLINE PARA O LADO OPOSTO"
		else:
			_message.text = ""


func _set_readout(key: String, text: String, ratio: float) -> void:
	var label: Label = _readouts[key]
	label.text = text
	label.add_theme_color_override("font_color", Game.level_color(ratio))


func _touchdown() -> void:
	var vy := -vel.y
	var vh := horizontal_speed()
	var angle := tilt_angle()
	var reasons: Array = []
	var tips: Array = []
	if vy > limits["land_vy"]:
		reasons.append("Velocidade vertical de %.1f m/s, acima do limite de %.1f m/s. O trem de pouso não absorveria o impacto." % [vy, limits["land_vy"]])
		tips.append("Perto do solo, aumente a potência (W) até a velocidade vertical ficar verde.")
	if vh > limits["land_vh"]:
		reasons.append("Velocidade horizontal de %.1f m/s, acima de %.1f m/s. O módulo tombaria ao tocar o solo." % [vh, limits["land_vh"]])
		tips.append("Elimine o deslizamento ainda no alto, inclinando para o lado oposto ao movimento.")
	if angle > limits["land_tilt"]:
		reasons.append("Inclinação de %.0f°, acima de %.0f°. O módulo tocaria o solo com uma perna só." % [angle, limits["land_tilt"]])
		tips.append("Solte as teclas de inclinação nos últimos metros: o módulo se nivela sozinho.")
	if MissionState.lm_fuel <= 0.0:
		reasons.append("O propelente acabou antes do contato com o solo.")
		tips.append("Desça mais rápido no alto e economize motor. Levar a reserva de propelente também ajuda.")
	if reasons.is_empty():
		_success(vy, vh, angle)
	else:
		_fail(reasons, tips)


func _success(vy: float, vh: float, angle: float) -> void:
	state = "landed"
	Sound.end_maneuver()
	Sound.play_cue("dock")
	Sound.play_cue("success", "Interface")
	MissionState.landing_attempts += 1
	MissionState.landing_result = {
		"success": true, "vy": vy, "vh": vh, "tilt": angle,
		"fuel_left": MissionState.lm_fuel, "distance": Vector2(pos.x, pos.z).length(),
	}
	MissionState.science_collected = MissionState.science_potential()
	MissionState.add_event("landing", "Pouso lunar", "Sucesso na tentativa %d, com %.0f s de propelente sobrando." % [MissionState.landing_attempts, MissionState.lm_fuel])
	_message.text = "CONTATO! POUSO CONFIRMADO"
	Houston.clear()
	Houston.say_recorded("crew_touchdown", "Houston, Eagle. Contact. Engine stop.",
		"Houston, aqui é Eagle. Contato. Motor desligado.", "EAGLE")
	Houston.say_recorded("landing_confirmed", "We copy you down. You've got a lot of people smiling down here.",
		"Confirmamos o pouso. Tem muita gente sorrindo aqui embaixo.")
	get_tree().create_timer(maxf(4.0, Houston.radio_time_remaining()), false).timeout.connect(
		func(): Game.landing_success())


func _fail(reasons: Array, tips: Array) -> void:
	if state != "flying":
		return
	state = "crashed"
	Houston.clear()
	Sound.end_maneuver()
	Sound.play_cue("impact", "Voice", true)
	MissionState.landing_attempts += 1
	MissionState.set_failure("landing", "POUSO MALSUCEDIDO", reasons, tips)
	_message.text = "FALHA NO POUSO"
	get_tree().create_timer(1.5).timeout.connect(Game.landing_failed)
