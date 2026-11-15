extends Node
## Apresentação 3D da reentrada e da amerissagem.
## Só lê o estado de reentry_game.gd (phase, phase_time, altitude, attitude, paused, result)
## e nunca o altera. Toda suavização visual é calculada aqui a partir desse estado.
## Modelos: assets/models/reentry/reentry_set.glb (fonte: assets/source/reentry/).

const MODEL := preload("res://assets/models/reentry/reentry_set.glb")
const SKY := preload("res://assets/shaders/reentry/sky.gdshader")
const EARTH := preload("res://assets/shaders/reentry/earth.gdshader")
const ATMO := preload("res://assets/shaders/reentry/atmosphere.gdshader")
const SHIELD := preload("res://assets/shaders/reentry/heat_shield.gdshader")
const PLASMA := preload("res://assets/shaders/reentry/plasma.gdshader")
const TRAIL := preload("res://assets/shaders/reentry/trail.gdshader")
const CLOUD := preload("res://assets/shaders/reentry/cloud_layer.gdshader")
const FOAM := preload("res://assets/shaders/reentry/foam.gdshader")

const EARTH_RADIUS := 6000.0
## Topo do cone: ponto onde os cabos dos paraquedas se prendem (espaço local da cápsula).
const APEX := Vector3(0, 2.95, 0)
## Direção do deslocamento durante a reentrada: escudo à frente, para a esquerda e para baixo.
const TRAVEL := Vector3(-1.0, -0.32, 0.12)
## Altitudes (m) das camadas de nuvens próximas.
const CLOUD_LEVELS := [[6500.0, 0.40, 3.0], [4500.0, 0.36, 7.0], [2000.0, 0.32, 11.0]]

var game: Node
var world: SubViewport
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var capsule: Node3D
var shield_mat: ShaderMaterial
var service_module: Node3D
var envelopes: Array[MeshInstance3D] = []
var trail: MeshInstance3D
var sparks: GPUParticles3D
var heat_light: OmniLight3D
var earth: MeshInstance3D
var earth_mat: ShaderMaterial
var atmo: MeshInstance3D
var atmo_mat: ShaderMaterial
var clouds: Array = []
var drogues: Array[Node3D] = []
var mains: Array[Node3D] = []
var lines: Array[MeshInstance3D] = []
var foam: MeshInstance3D
var foam_mat: ShaderMaterial
var splash: GPUParticles3D

var vt := 0.0            ## tempo visual, para enquanto o jogo está pausado
var burn := 0.0
var _scroll := 0.0
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _first := true
var _last_phase := ""
var _phase_clock := 0.0  ## tempo visual desde a última mudança de fase
var _vertical := 0.0     ## 0 = orientação de reentrada, 1 = pendurada nos paraquedas
var _swing := 0.0
var _drogue_release := 0.0


func setup(owner_game: Node) -> void:
	game = owner_game
	var container := SubViewportContainer.new()
	container.name = "ReentryView3D"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner_game.add_child(container)
	owner_game.move_child(container, 0)
	world = SubViewport.new()
	world.audio_listener_enable_3d = false
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(world)
	_build()
	update_view(0.0)


# ---------- Montagem ----------

func _meshes() -> Dictionary:
	var found := {}
	var inst: Node = MODEL.instantiate()
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		found[node.name] = (node as MeshInstance3D).mesh
	inst.free()
	return found


func _mesh_node(mesh: Mesh, parent: Node, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	parent.add_child(mi)
	return mi


func _shader(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


func _build() -> void:
	var m := _meshes()
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = _shader(SKY)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.52, 0.72)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.68, 0.84)
	env.fog_sky_affect = 0.0
	env.fog_density = 0.0001
	we.environment = env
	world.add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	world.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.55, -0.55, -0.62), Vector3.UP)
	sky_mat.set_shader_parameter("sun_dir", -sun.global_basis.z * -1.0)

	earth_mat = _shader(EARTH)
	earth = _mesh_node(m["EarthSphere"], world, earth_mat)
	earth.scale = Vector3.ONE * EARTH_RADIUS
	atmo_mat = _shader(ATMO)
	atmo = _mesh_node(m["AtmosphereShell"], world, atmo_mat)
	atmo.scale = Vector3.ONE * EARTH_RADIUS * 1.03

	for level in CLOUD_LEVELS:
		var mat := _shader(CLOUD)
		mat.set_shader_parameter("coverage", level[1])
		mat.set_shader_parameter("seed", level[2])
		var layer := _mesh_node(m["CloudLayer"], world, mat)
		layer.rotation_degrees.x = -90.0
		layer.scale = Vector3.ONE * 700.0
		clouds.append([layer, mat, level[0]])

	capsule = Node3D.new()
	capsule.name = "Columbia"
	world.add_child(capsule)
	_mesh_node(m["CommandModule"], capsule)
	shield_mat = _shader(SHIELD)
	_mesh_node(m["HeatShield"], capsule, shield_mat)
	for key in ["HeatEnvelope", "HeatEnvelopeOuter"]:
		var mat := _shader(PLASMA)
		mat.set_shader_parameter("opacity", 0.9 if key == "HeatEnvelope" else 0.45)
		mat.set_shader_parameter("length_fade", 1.4 if key == "HeatEnvelope" else 2.2)
		var e := _mesh_node(m[key], capsule, mat)
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		envelopes.append(e)
	trail = _mesh_node(m["ReentryTrail"], capsule, _shader(TRAIL))
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	heat_light = OmniLight3D.new()
	heat_light.light_color = Color(1.0, 0.5, 0.18)
	heat_light.omni_range = 7.0
	heat_light.light_energy = 0.0
	heat_light.position = Vector3(0, -1.2, 0)
	capsule.add_child(heat_light)
	sparks = _sparks()
	capsule.add_child(sparks)

	service_module = Node3D.new()
	world.add_child(service_module)
	_mesh_node(m["ServiceModule"], service_module)

	var chute_white := _double_sided(Color(0.93, 0.9, 0.84))
	var chute_orange := _double_sided(Color(0.84, 0.39, 0.18))
	for i in 2:
		drogues.append(_chute(m["DrogueChute"], chute_white, chute_orange))
	for i in 3:
		mains.append(_chute(m["MainChute"], chute_white, chute_orange))
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.86, 0.84, 0.78)
	line_mat.roughness = 1.0
	var line_mesh := CylinderMesh.new()
	line_mesh.top_radius = 0.045
	line_mesh.bottom_radius = 0.045
	line_mesh.height = 1.0
	line_mesh.radial_segments = 4
	line_mesh.rings = 1
	for i in 30:
		var line := _mesh_node(line_mesh, world, line_mat)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line.visible = false
		lines.append(line)

	foam_mat = _shader(FOAM)
	foam = _mesh_node(m["FoamDisc"], world, foam_mat)
	foam.rotation_degrees.x = -90.0
	foam.visible = false
	splash = _splash_particles()
	world.add_child(splash)

	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.2
	camera.far = 20000.0
	world.add_child(camera)
	camera.make_current()
	world.size_changed.connect(_fit_camera)
	_fit_camera()


## O HUD ocupa uma faixa 16:9 centralizada. Em telas mais estreitas (4:3), a câmera mantém
## a largura de 16:9, para paraquedas e cápsula continuarem dentro dessa faixa.
func _fit_camera() -> void:
	var size := Vector2(world.size)
	if size.y <= 0.0:
		return
	if size.x / size.y < 16.0 / 9.0 - 0.01:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(62.0) * 0.5) * 16.0 / 9.0))
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 62.0


func _double_sided(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# tecido fino: a luz atravessa um pouco, sem manchas escuras no lado de dentro
	mat.backlight_enabled = true
	mat.backlight = color * 0.55
	return mat


func _chute(mesh: Mesh, white: Material, orange: Material) -> Node3D:
	var root := Node3D.new()
	world.add_child(root)
	var mi := _mesh_node(mesh, root)
	for s in mesh.get_surface_count():
		var name := mesh.surface_get_material(s).resource_name if mesh.surface_get_material(s) else ""
		mi.set_surface_override_material(s, orange if name == "ChuteOrange" else white)
	root.visible = false
	return root


func _sparks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 56
	p.lifetime = 0.45
	p.local_coords = true
	p.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 2.0
	pm.emission_ring_inner_radius = 1.8
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 26.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.55, 1.0))
	ramp.add_point(0.4, Color(1.0, 0.45, 0.12, 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.35, 0.08, 0.04, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _splash_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 1.6
	p.one_shot = true
	p.explosiveness = 0.92
	p.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 2.2
	pm.emission_ring_inner_radius = 1.6
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.spread = 38.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.95, 0.98, 1.0, 0.95))
	ramp.set_color(1, Color(0.8, 0.9, 0.95, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# ---------- Mapeamento do estado ----------

## Altitude real (m) -> distância visual (unidades) entre a cápsula e o mar.
## Comprimida acima de 3.050 m para a curvatura da Terra caber na cena.
static func visual_height(altitude: float) -> float:
	if altitude <= 3000.0:
		return altitude * 0.03
	return 90.0 + (altitude - 3000.0) * 0.009


## Intensidade do calor (0..1) derivada da fase e do tempo da fase.
func heat_level() -> float:
	if game.phase != "entry":
		return 0.0
	var u: float = clampf(game.phase_time / game.ENTRY_TIME, 0.0, 1.0)
	return smoothstep(0.0, 0.28, u) * (1.0 - smoothstep(0.62, 1.0, u))


func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	if not game.paused:
		vt += delta
		_phase_clock += delta
	update_view(delta if not game.paused else 0.0)


func update_view(delta: float) -> void:
	var phase: String = game.phase
	if phase != _last_phase:
		_on_phase(phase, _last_phase)
		_last_phase = phase
	var alt: float = game.altitude
	var h := visual_height(alt)
	var heat := heat_level()
	burn = maxf(burn, heat)
	var low := clampf(1.0 - (alt - 3000.0) / 14000.0, 0.0, 1.0)
	_update_environment(alt, h, low)
	_update_capsule(phase, delta, heat)
	_update_chutes(phase)
	_update_splash(phase, h)
	_update_camera(phase, delta, heat)


func _on_phase(phase: String, previous: String) -> void:
	_phase_clock = 0.0
	if phase == "intro" or phase == "separation":
		burn = 0.0
		_vertical = 0.0
		_drogue_release = 0.0
	if phase == "splash":
		splash.restart()
		splash.emitting = true


func _update_environment(alt: float, h: float, low: float) -> void:
	var sea_y := -0.15 - h
	earth.position = Vector3(0, sea_y - EARTH_RADIUS, 0)
	atmo.position = earth.position
	var high := clampf((alt - 9000.0) / 30000.0, 0.0, 1.0)
	atmo_mat.set_shader_parameter("strength", high)
	sky_mat.set_shader_parameter("low", low)
	var speed := 0.0
	match game.phase:
		"intro", "separation": speed = 0.02
		"entry": speed = lerpf(0.02, 0.004, clampf(game.phase_time / game.ENTRY_TIME, 0.0, 1.0))
		_: speed = 0.0
	_scroll += speed * get_process_delta_time() * (0.0 if game.paused else 1.0)
	earth_mat.set_shader_parameter("scroll", _scroll)
	earth_mat.set_shader_parameter("cloud_fade", clampf((alt - 1500.0) / 8000.0, 0.0, 1.0))
	earth_mat.set_shader_parameter("waves", clampf(1.0 - alt / 2500.0, 0.0, 1.0))
	earth_mat.set_shader_parameter("wave_time", vt)
	env.fog_density = lerpf(0.00006, 0.0016, low)
	env.fog_light_color = Color(0.03, 0.06, 0.14).lerp(Color(0.36, 0.48, 0.62), low)
	env.ambient_light_color = Color(0.32, 0.4, 0.6).lerp(Color(0.55, 0.64, 0.78), low)
	env.ambient_light_energy = lerpf(0.28, 0.55, low)
	for entry in clouds:
		var layer: MeshInstance3D = entry[0]
		var mat: ShaderMaterial = entry[1]
		var level_alt: float = entry[2]
		layer.position = Vector3(0, visual_height(level_alt) - h, 0)
		mat.set_shader_parameter("visibility", clampf(1.0 - (alt - 11000.0) / 3000.0, 0.0, 1.0))
		mat.set_shader_parameter("drift", Vector2(vt * 0.002, vt * 0.001))


func _entry_basis() -> Basis:
	var up := (-TRAVEL).normalized()
	var q := Quaternion(Vector3.UP, up)
	# ângulo de ataque leve e escotilha virada para a câmera
	return Basis(q) * Basis(Vector3.UP, deg_to_rad(-25.0)) * Basis(Vector3.RIGHT, deg_to_rad(-12.0))


func _update_capsule(phase: String, delta: float, heat: float) -> void:
	var hanging := phase in ["drogue", "window", "mains", "splash", "failed"]
	var target_vertical := 1.0 if hanging else 0.0
	if delta <= 0.0 and _first:
		_vertical = target_vertical
	_vertical = move_toward(_vertical, target_vertical, delta / 1.4)
	var blend := smoothstep(0.0, 1.0, _vertical)
	# oscilação: atitude do jogo + pêndulo leve
	var target_swing := 0.0
	if phase in ["drogue", "window", "failed"]:
		target_swing = float(game.attitude) * 0.42 + sin(vt * 1.7) * 0.03
	elif phase == "mains":
		target_swing = sin(vt * 1.1) * 0.05
	elif phase == "splash":
		target_swing = sin(vt * 1.3) * 0.06 * maxf(0.0, 1.0 - _phase_clock * 0.25) + 0.08
	_swing = lerpf(_swing, target_swing, 1.0 - exp(-delta * 8.0)) if delta > 0.0 else target_swing
	var hang_basis := Basis(Vector3.BACK, _swing)
	var hang_origin := APEX - hang_basis * APEX
	if phase == "splash":
		hang_origin.y += sin(vt * 1.6) * 0.08 - 0.25
	var basis := Basis(_entry_basis().get_rotation_quaternion().slerp(hang_basis.get_rotation_quaternion(), blend))
	var shake := Vector3.ZERO
	if heat > 0.0 and delta > 0.0:
		shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.03 * heat
	capsule.transform = Transform3D(basis, hang_origin * blend + shake)
	# efeitos de calor
	shield_mat.set_shader_parameter("heat", heat)
	shield_mat.set_shader_parameter("burn", burn)
	shield_mat.set_shader_parameter("flicker", vt * 4.0)
	for e in envelopes:
		var mat: ShaderMaterial = e.material_override
		mat.set_shader_parameter("heat", heat)
		mat.set_shader_parameter("flow", vt)
		e.visible = heat > 0.002
	var tmat: ShaderMaterial = trail.material_override
	tmat.set_shader_parameter("heat", heat)
	tmat.set_shader_parameter("flow", vt)
	tmat.set_shader_parameter("reach", clampf(heat * 1.4, 0.15, 1.0))
	trail.visible = heat > 0.002
	heat_light.light_energy = heat * 5.0
	sparks.emitting = heat > 0.25
	sparks.amount_ratio = clampf(heat, 0.0, 1.0)
	# módulo de serviço: preso no início, afasta-se na separação e some na reentrada
	var sep := 0.0
	if phase == "separation":
		sep = clampf(game.phase_time / game.SEPARATION_TIME, 0.0, 1.0)
	elif phase != "intro":
		sep = 1.0 + float(game.phase_time) * 0.6 if phase == "entry" else 9.0
	service_module.visible = sep < 2.5
	var eb := _entry_basis()
	var away := sep * sep * 16.0
	service_module.transform = Transform3D(eb * Basis(Vector3.RIGHT, sep * 0.5), eb * Vector3(0, -0.02, 0) + (eb * Vector3.DOWN) * away * 0.6 + Vector3(0, -away * 0.2, -away * 1.1))


func _update_chutes(phase: String) -> void:
	var used := 0
	var apex_world := capsule.transform * APEX
	# estabilizadores (drogues): abrem no início de "drogue", são soltos quando os principais abrem
	var show_drogues := phase in ["drogue", "window", "failed", "mains"]
	if phase == "mains":
		_drogue_release = minf(_drogue_release + get_process_delta_time() * (0.0 if game.paused else 1.0), 2.0)
	var deploy := 1.0
	if phase == "drogue":
		deploy = clampf(_phase_clock / 0.7, 0.05, 1.0)
	for i in drogues.size():
		var d := drogues[i]
		d.visible = show_drogues and _drogue_release < 1.6
		if not d.visible:
			continue
		var side := -1.0 if i == 0 else 1.0
		var top := apex_world + Vector3(side * 1.6 + _swing * -2.0, 7.0 * deploy, side * 0.3)
		if _drogue_release > 0.0:
			top += Vector3(side * 3.0, 6.0, 0) * _drogue_release
		var breathe := 1.0 + sin(vt * 3.0 + i) * 0.04
		d.transform = Transform3D(Basis(Vector3.BACK, -side * 0.15) * Basis.from_scale(Vector3(1.0, 0.75 + 0.25 * deploy, 1.0) * 1.15 * deploy * breathe), top)
		if _drogue_release <= 0.0:
			used = _rig_lines(d, apex_world, 1.15 * deploy, 4, used)
	# principais: três cúpulas, abertura sincronizada ao evento real (phase "mains")
	var show_mains := phase in ["mains", "splash"]
	var opened := 1.0
	if phase == "mains":
		opened = clampf(game.phase_time / 0.8, 0.2, 1.0)
	var collapse := 0.0
	if phase == "splash":
		collapse = clampf(_phase_clock / 2.5, 0.0, 1.0)
	for i in mains.size():
		var c := mains[i]
		c.visible = show_mains and collapse < 1.0
		if not c.visible:
			continue
		var side := float(i) - 1.0
		var radius := lerpf(1.2, 4.2, smoothstep(0.0, 1.0, (opened - 0.2) / 0.8))
		var stretch := lerpf(2.2, 1.0, opened)
		var breathe := 1.0 + sin(vt * 2.0 + i * 1.7) * 0.03
		var top := apex_world + Vector3(side * 5.2 - _swing * 3.0, 14.0, (1.0 - absf(side)) * -1.2)
		var tilt := Basis(Vector3.BACK, -side * 0.28)
		if collapse > 0.0:
			top = top.lerp(Vector3(side * 9.0 + 6.0, -0.4, -3.0 + side * 2.0), collapse)
			tilt = tilt.slerp(Basis(Vector3.BACK, -1.3), collapse)
		var scale := Vector3(radius * breathe, radius * 0.9 * stretch * (1.0 - collapse * 0.8), radius * breathe)
		c.transform = Transform3D(tilt * Basis.from_scale(scale), top)
		if collapse < 0.6:
			used = _rig_lines(c, apex_world, radius, 5, used)
	for k in range(used, lines.size()):
		lines[k].visible = false


## Cabos: da ponta do cone até a confluência, e da confluência até a saia da cúpula.
func _rig_lines(canopy: Node3D, apex_world: Vector3, radius: float, count: int, used: int) -> int:
	var skirt_center := canopy.transform.origin
	var confluence := apex_world.lerp(skirt_center, 0.55)
	used = _line(used, apex_world, confluence)
	for k in count:
		var a := float(k) / count * TAU + 0.4
		var local := Vector3(cos(a), 0.0, sin(a))
		var skirt := canopy.transform.basis * local + skirt_center
		used = _line(used, confluence, skirt)
	return used


func _line(index: int, a: Vector3, b: Vector3) -> int:
	if index >= lines.size():
		return index
	var line := lines[index]
	var dir := b - a
	var length := dir.length()
	if length < 0.01:
		line.visible = false
		return index + 1
	var y := dir / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	line.transform = Transform3D(Basis(x, y * length, z), (a + b) * 0.5)
	line.visible = true
	return index + 1


func _update_splash(phase: String, h: float) -> void:
	var sea_y := -0.15 - h
	splash.position = Vector3(0, sea_y, 0)
	foam.visible = phase == "splash"
	if foam.visible:
		var life := clampf(_phase_clock / 6.0, 0.0, 1.0)
		foam.position = Vector3(0, sea_y + 0.03, 0)
		foam.scale = Vector3.ONE * lerpf(2.5, 15.0, sqrt(life))
		foam_mat.set_shader_parameter("life", life)


func _update_camera(phase: String, delta: float, heat: float) -> void:
	var look := Vector3.ZERO
	var pos := Vector3.ZERO
	match phase:
		"intro", "separation", "entry":
			# três quartos: espaço à direita para o rastro e para o arco da Terra
			look = Vector3(2.6, -0.9, 0.0)
			pos = Vector3(3.2, 2.2, 13.5)
		"drogue", "window", "failed":
			look = Vector3(0.0, 3.4, 0.0)
			pos = Vector3(3.0, 5.0, 17.5)
		"mains":
			look = Vector3(0.0, 7.4, 0.0)
			pos = Vector3(4.5, 8.0, 30.0)
		"splash":
			# cápsula abaixo do painel de resultado, entre a espuma e o reflexo
			look = Vector3(0.0, 3.6, 0.0)
			pos = Vector3(6.0, 5.5, 17.0)
	if _first or delta <= 0.0 and _cam_pos == Vector3.ZERO:
		_cam_pos = pos
		_cam_look = look
		_first = false
	else:
		var k := 1.0 - exp(-delta * 2.2)
		_cam_pos = _cam_pos.lerp(pos, k)
		_cam_look = _cam_look.lerp(look, k)
	var shake := Vector3.ZERO
	if heat > 0.0 and delta > 0.0:
		shake = Vector3(sin(vt * 37.0), sin(vt * 41.0 + 1.0), 0.0) * 0.05 * heat
	camera.position = _cam_pos + shake
	camera.look_at(_cam_look + shake * 0.5, Vector3.UP)
