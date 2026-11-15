extends Node3D
## Cena 3D low poly do painel de manobra da injeção translunar.
## O S-IVB com o LM e o CSM em órbita sobre a Terra, o anel de orientação da queima,
## a separação com a abertura dos painéis do adaptador e, por fim, o voo acelerado da
## trajetória até a Lua. separation_minigame.gd comanda a cena pelas propriedades públicas
## e pelas funções ignite(), cutoff(), separation_step(), abort() e play_flight().

signal flight_finished

const EARTH_SHADER := preload("res://assets/shaders/menu/earth.gdshader")
const BACKDROP := preload("res://scripts/ui/menu_backdrop.gd")
## Graus mostrados na cena para cada grau de desvio: deixa a deriva legível na tela.
const ATT_SCALE := 1.6
const GUIDE_DISTANCE := 18.0
const SUN_DIR := Vector3(0.62, 0.42, 0.66)
const CAMERA_POS := Vector3(7.6, 4.2, 20.0)
const CAMERA_LOOK := Vector3(0.0, -1.6, -5.5)
const SIDE_POS := Vector3(12.5, 3.2, 5.0)
const MAP := Vector3(0, 800, 0)
const MAP_MOON := Vector3(30, 0, -8)
const PARKING_RADIUS := 3.9
const FLIGHT_TIME := 7.0
## Fração da rota percorrida no fim da animação: a nave mal deixou a Terra. O resto da
## travessia, cerca de 3 dias, acontece na cabine.
const FLIGHT_REACH := 0.17

const WHITE := Color(0.88, 0.88, 0.85)
const DARK := Color(0.13, 0.13, 0.15)
const STEEL := Color(0.62, 0.64, 0.68)
const GOLD := Color(0.86, 0.64, 0.22)
const GOOD := Color(0.45, 0.9, 0.45)
const WARN := Color(1.0, 0.8, 0.25)

## Estado que o painel envia a cada quadro.
var attitude := Vector2.ZERO
var thrust := 0.0
var shake := 0.0
var pogo := false
var show_guide := false
var guidance_color := GOOD

var ship: Node3D
var csm: Node3D
var camera: Camera3D
var earth: MeshInstance3D
var _body: Node3D
var _panels: Array[Node3D] = []
var _flame: MeshInstance3D
var _core: MeshInstance3D
var _engine_light: OmniLight3D
var _flash: OmniLight3D
var _lamps: Array[MeshInstance3D] = []
var _guide: MeshInstance3D
var _guide_warn: MeshInstance3D
var _tip: MeshInstance3D
var _line: ImmediateMesh
var _line_mat: StandardMaterial3D
var _flame_level := 0.0
var _ignition_kick := 0.0
var _time := 0.0
var _sep_step := 0
var _sep_time := -1.0
var _tumble := Vector3.ZERO
var _map: Node3D
var _map_ship: Node3D
var _path := PackedVector3Array()
var _path_color := GOOD
var _path_mesh: ImmediateMesh
var _trail: ImmediateMesh
var _flight := -1.0
var _flight_error := 0.0
var _flight_done := false
var _rng := RandomNumberGenerator.new()
var _moon: MeshInstance3D
var _map_earth: MeshInstance3D
var _moon_ring: MeshInstance3D
## Depois do corte, a Terra vai ficando para trás.
var _departing := false


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.5, 0.66)
	e.ambient_light_energy = 0.38
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.97, 0.9)
	add_child(sun)
	sun.look_at_from_position(SUN_DIR * 10.0, Vector3.ZERO)
	var mask: ImageTexture = BACKDROP._land_mask()
	earth = _earth(50.0, mask)
	earth.position = Vector3(0, -58, -14)
	# O equador fica voltado para cima: a nave sobrevoa oceanos e continentes, não o polo.
	earth.rotation_degrees = Vector3(0, 0, 90)
	add_child(earth)
	_moon = _sphere(self, 5.0, Color(0.72, 0.71, 0.68), 12)
	_moon.position = Vector3(-70, 34, -420)
	_build_ship()
	_build_guide()
	_build_map(mask)
	camera = Camera3D.new()
	camera.fov = 52.0
	camera.near = 0.1
	camera.far = 3000.0
	add_child(camera)
	camera.make_current()
	camera.look_at_from_position(CAMERA_POS, CAMERA_LOOK)


# ---------- Comandos do painel ----------

func ignite() -> void:
	_ignition_kick = 1.0
	_flash.position = Vector3(0, 0, 5.2)
	_flash.light_color = Color(1.0, 0.6, 0.3)
	_flash.light_energy = 6.0


func cutoff() -> void:
	thrust = 0.0
	show_guide = false
	_departing = true


## 1: lógica ligada (luzes verdes). 2: pirotécnicos armados (âmbar piscando). 3: separação.
func separation_step(step: int) -> void:
	_sep_step = step
	if step >= 3 and _sep_time < 0.0:
		_sep_time = 0.0
		_flash.position = Vector3(0, 0, -3.2)
		_flash.light_color = Color(1.0, 0.95, 0.85)
		_flash.light_energy = 9.0


## Queima abortada: o motor apaga e a nave sai girando.
func abort() -> void:
	thrust = 0.0
	show_guide = false
	_tumble = Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.9, 0.9), _rng.randf_range(0.4, 0.9))


## Voo da trajetória até a Lua. `error` desvia o fim da rota e muda sua cor.
func play_flight(error: float) -> void:
	if _flight >= 0.0:
		return
	_flight = 0.0
	_flight_error = error
	_path_color = GOOD if error < 0.12 else WARN
	# Só o mapa fica à vista: a cena da órbita some atrás da câmera do voo.
	for node in [earth, _moon, ship, _guide, _guide_warn, _tip]:
		node.visible = false
	_build_path()
	_map.visible = true


func finish_flight() -> void:
	if _flight < 0.0:
		play_flight(_flight_error)
	_flight = FLIGHT_TIME


func flight_progress() -> float:
	return clampf(_flight / FLIGHT_TIME, 0.0, 1.0) if _flight >= 0.0 else 0.0


# ---------- Animação ----------

func _process(delta: float) -> void:
	_time += delta
	if _flight >= 0.0:
		_animate_flight(delta)
		return
	var shown := attitude * ATT_SCALE
	if _tumble != Vector3.ZERO:
		ship.rotate_object_local(Vector3(_tumble.x, _tumble.y, 0.0).normalized() if _tumble.length() > 0.0 else Vector3.UP, _tumble.z * delta)
	else:
		ship.basis = Basis.from_euler(Vector3(deg_to_rad(-shown.y), deg_to_rad(-shown.x), sin(_time * 0.4) * 0.02))
	earth.rotate_x(delta * (0.008 + 0.03 * thrust))
	if _departing:
		# A nave já está em rota de escape: a Terra desce e se afasta devagar.
		earth.position += Vector3(0.0, -1.1, 0.5) * delta
	_animate_flame(delta)
	_animate_guide()
	_animate_separation(delta)
	_flash.light_energy = lerpf(_flash.light_energy, 0.0, 1.0 - exp(-delta * 5.0))
	_ignition_kick = maxf(0.0, _ignition_kick - delta * 1.8)
	var amount := shake + _ignition_kick * 4.0
	camera.h_offset = (sin(_time * 43.0) + sin(_time * 71.3)) * 0.02 * amount
	camera.v_offset = (cos(_time * 57.1) + sin(_time * 83.7)) * 0.02 * amount


func _animate_flame(delta: float) -> void:
	_flame_level = lerpf(_flame_level, thrust, 1.0 - exp(-delta * (10.0 if thrust > _flame_level else 14.0)))
	var flicker := 1.0 + sin(_time * 47.0) * 0.07 + _rng.randf_range(-0.06, 0.06)
	if pogo:
		flicker += sin(_time * 19.0) * 0.35
	var length := (2.2 + 4.5 * _flame_level + _ignition_kick * 3.0) * flicker
	_flame.visible = _flame_level > 0.03
	_core.visible = _flame.visible
	_flame.scale = Vector3(1.0 + _ignition_kick * 0.6, length, 1.0 + _ignition_kick * 0.6)
	_flame.position.z = 4.7 + length * 0.5
	_core.scale = Vector3(1.0, length * 0.55, 1.0)
	_core.position.z = 4.7 + length * 0.275
	_engine_light.light_energy = _flame_level * 3.2 * flicker


func _animate_guide() -> void:
	_guide.visible = show_guide
	_guide_warn.visible = show_guide
	_tip.visible = show_guide
	(_guide.material_override as StandardMaterial3D).albedo_color = guidance_color
	_line.clear_surfaces()
	if not show_guide:
		return
	# Linha do nariz até onde a nave aponta. O anel marca a direção certa da queima.
	var nose := ship.basis * Vector3(0, 0, -6.6)
	var tip := ship.basis * Vector3(0, 0, -GUIDE_DISTANCE)
	_tip.position = tip
	(_tip.material_override as StandardMaterial3D).albedo_color = guidance_color
	_line_mat.albedo_color = guidance_color
	_line.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
	for i in 12:
		if i % 2 == 0:
			_line.surface_add_vertex(nose.lerp(tip, i / 12.0))
			_line.surface_add_vertex(nose.lerp(tip, (i + 1) / 12.0))
	_line.surface_end()


func _animate_separation(delta: float) -> void:
	var lamp_color := Color(0.1, 0.1, 0.1)
	if _sep_step == 1:
		lamp_color = GOOD
	elif _sep_step == 2:
		lamp_color = WARN if fmod(_time, 0.6) < 0.3 else Color(0.25, 0.18, 0.05)
	for lamp in _lamps:
		(lamp.material_override as StandardMaterial3D).albedo_color = lamp_color
	if _sep_time < 0.0:
		return
	_sep_time += delta
	# Os quatro painéis abrem como pétalas, o CSM se afasta e começa a virar.
	var open := smoothstep(0.0, 1.6, _sep_time)
	var drift := maxf(0.0, _sep_time - 1.4) * 0.45
	for panel in _panels:
		var mid: float = panel.get_meta("angle")
		var radial := Vector3(cos(mid), sin(mid), 0.0)
		var tangent := Vector3(-sin(mid), cos(mid), 0.0)
		panel.basis = Basis(tangent, -deg_to_rad(110.0) * open)
		panel.position = (panel.get_meta("hinge") as Vector3) + radial * drift + Vector3(0, 0, drift * 0.3)
	csm.position.z = -minf(_sep_time, 5.0) * 0.5
	csm.rotation.y = smoothstep(1.2, 5.0, _sep_time) * 0.7
	var side := smoothstep(0.3, 4.0, _sep_time)
	camera.look_at_from_position(CAMERA_POS.lerp(SIDE_POS, side), CAMERA_LOOK.lerp(Vector3(0, 0, -4.5), side))


func _animate_flight(delta: float) -> void:
	if not _flight_done:
		_flight = minf(_flight + delta, FLIGHT_TIME)
	var u := flight_progress()
	# Só as primeiras horas da travessia: a nave deixa a órbita da Terra e desacelera ao
	# subir, como numa órbita de transferência. A rota tracejada mostra o resto até a Lua.
	var p := FLIGHT_REACH * (1.0 - pow(1.0 - u, 1.6))
	_map_earth.rotate_y(delta * 0.12)
	var pulse := 1.0 + 0.18 * sin(_time * 4.0)
	_moon_ring.scale = Vector3(pulse, 1.0, pulse)
	var count := _path.size()
	var reach := p * (count - 1)
	var index := mini(int(reach), count - 2)
	var here := _path[index].lerp(_path[index + 1], reach - index)
	_map_ship.position = here
	var ahead := _path[mini(index + 2, count - 1)]
	if ahead.distance_to(here) > 0.001:
		_map_ship.look_at(ahead, Vector3.UP)
	# Rastro percorrido: três linhas paralelas para ficar grosso na meia resolução.
	_trail.clear_surfaces()
	_trail.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in index + 1:
		_ribbon(_trail, _path[i], here if i == index else _path[i + 1], 0.32, _path_color)
	_trail.surface_end()
	# A câmera começa atrás da nave, olhando para a Lua, e sobe até mostrar a Terra ficando
	# para trás, a nave logo depois dela e a Lua como destino no fim da rota.
	var s := smoothstep(0.0, 1.0, u)
	var from := MAP + Vector3(-9.0, 8.0, 14.0)
	var to := MAP + Vector3(10.0, 27.0, 25.0)
	var look_from := MAP + Vector3(5.0, 0.0, -1.5)
	var look_to := MAP + Vector3(13.0, 0, -3.5)
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	camera.look_at_from_position(from.lerp(to, s), look_from.lerp(look_to, s))
	if u >= 1.0 and not _flight_done:
		_flight_done = true
		flight_finished.emit()


# ---------- Montagem ----------

func _mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Cilindro ao longo de Z. O raio `front` fica voltado para -Z (a frente da nave).
func _cyl(parent: Node3D, front: float, back: float, length: float, z: float, color: Color, sides := 14) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = front
	mesh.bottom_radius = back
	mesh.height = length
	mesh.radial_segments = sides
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _mat(color)
	instance.rotation_degrees.x = -90.0
	instance.position.z = z
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, unshaded := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _mat(color, unshaded)
	instance.position = at
	parent.add_child(instance)
	return instance


func _sphere(parent: Node3D, radius: float, color: Color, sides := 10, unshaded := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = sides
	mesh.rings = maxi(3, sides / 2)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _mat(color, unshaded)
	parent.add_child(instance)
	return instance


func _earth(radius: float, mask: ImageTexture) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 48
	mesh.rings = 24
	var mat := ShaderMaterial.new()
	mat.shader = EARTH_SHADER
	mat.set_shader_parameter("land_mask", mask)
	mat.set_shader_parameter("sun_dir", SUN_DIR.normalized())
	mat.set_shader_parameter("spin", 0.0)
	mat.set_shader_parameter("lon_shift", 0.18)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _glow(color: Color) -> StandardMaterial3D:
	var m := _mat(color, true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## S-IVB com o adaptador (SLA), o LM guardado dentro e o CSM na frente. A frente é -Z.
func _build_ship() -> void:
	ship = Node3D.new()
	add_child(ship)
	_body = Node3D.new()
	_body.position = Vector3(0, 0, 2.0)
	ship.add_child(_body)
	_cyl(_body, 1.1, 1.1, 6.4, 0.0, WHITE, 16)
	_cyl(_body, 1.12, 1.12, 0.35, 2.7, DARK, 16)
	_cyl(_body, 1.12, 1.12, 0.18, -2.75, DARK, 16)
	_cyl(_body, 1.11, 1.13, 0.5, 3.45, STEEL, 16)
	for side in [-1.0, 1.0]:
		_box(_body, Vector3(0.42, 0.55, 0.95), Vector3(side * 1.24, 0.0, 2.9), DARK)
	_cyl(_body, 0.28, 0.62, 1.0, 4.2, Color(0.30, 0.30, 0.33), 12)
	for i in 4:
		var a := i * PI * 0.5 + PI * 0.25
		var lamp := _box(_body, Vector3(0.14, 0.14, 0.14), Vector3(cos(a) * 1.13, sin(a) * 1.13, -2.75), Color(0.1, 0.1, 0.1), true)
		_lamps.append(lamp)
	# Chama do J-2: cone externo laranja e núcleo claro, somados à luz.
	_flame = _cyl(_body, 0.52, 0.06, 1.0, 5.0, Color.WHITE, 10)
	_flame.material_override = _glow(Color(1.0, 0.55, 0.2, 0.7))
	_core = _cyl(_body, 0.3, 0.04, 1.0, 5.0, Color.WHITE, 8)
	_core.material_override = _glow(Color(1.0, 0.92, 0.7, 0.85))
	_engine_light = OmniLight3D.new()
	_engine_light.light_color = Color(1.0, 0.6, 0.3)
	_engine_light.omni_range = 9.0
	_engine_light.position = Vector3(0, 0, 5.4)
	_body.add_child(_engine_light)
	_flash = OmniLight3D.new()
	_flash.omni_range = 14.0
	_flash.light_energy = 0.0
	_body.add_child(_flash)
	# LM dentro do adaptador: aparece quando os painéis abrem.
	_cyl(_body, 0.55, 0.55, 0.65, -3.75, GOLD, 8)
	_box(_body, Vector3(0.7, 0.62, 0.55), Vector3(0, 0, -4.35), STEEL)
	for i in 4:
		_panels.append(_sla_panel(i))
	csm = Node3D.new()
	_body.add_child(csm)
	_cyl(csm, 0.25, 0.46, 0.6, -5.1, DARK, 10)
	_cyl(csm, 0.7, 0.7, 1.8, -6.3, Color(0.80, 0.80, 0.78), 16)
	_cyl(csm, 0.71, 0.71, 0.12, -5.8, DARK, 16)
	_cyl(csm, 0.71, 0.71, 0.12, -6.8, DARK, 16)
	for i in 4:
		var a := i * PI * 0.5
		_box(csm, Vector3(0.16, 0.16, 0.22), Vector3(cos(a) * 0.76, sin(a) * 0.76, -6.95), STEEL)
	_cyl(csm, 0.12, 0.7, 1.2, -7.8, STEEL, 16)
	_cyl(csm, 0.05, 0.12, 0.35, -8.55, DARK, 8)


## Um quarto do adaptador, articulado na borda de trás para abrir como pétala.
func _sla_panel(index: int) -> Node3D:
	var gap := 0.03
	var a0 := index * PI * 0.5 + gap
	var a1 := (index + 1) * PI * 0.5 - gap
	var mid := (a0 + a1) * 0.5
	var hinge := Vector3(cos(mid) * 1.1, sin(mid) * 1.1, -3.2)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 6
	for j in steps:
		var points := []
		for k in 2:
			var a := lerpf(a0, a1, float(j + k) / steps)
			points.append(Vector3(cos(a) * 1.1, sin(a) * 1.1, -3.2) - hinge)
			points.append(Vector3(cos(a) * 0.7, sin(a) * 0.7, -5.4) - hinge)
		for v in [points[0], points[1], points[3], points[0], points[3], points[2]]:
			tool.add_vertex(v)
	tool.generate_normals()
	var panel := Node3D.new()
	panel.position = hinge
	panel.set_meta("hinge", hinge)
	panel.set_meta("angle", mid)
	_body.add_child(panel)
	var instance := MeshInstance3D.new()
	instance.mesh = tool.commit()
	var mat := _mat(Color(0.78, 0.78, 0.76))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = mat
	panel.add_child(instance)
	return panel


func _ring(radius: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.06
	mesh.outer_radius = radius + 0.06
	mesh.rings = 40
	mesh.ring_segments = 4
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _mat(color, true)
	instance.rotation_degrees.x = 90.0
	instance.position = Vector3(0, 0, -GUIDE_DISTANCE)
	add_child(instance)
	return instance


## Anéis de orientação à frente da nave: dentro do menor, a queima está bem apontada.
func _build_guide() -> void:
	_guide = _ring(GUIDE_DISTANCE * tan(deg_to_rad(3.0 * ATT_SCALE)), GOOD)
	_guide_warn = _ring(GUIDE_DISTANCE * tan(deg_to_rad(8.0 * ATT_SCALE)), Color(0.7, 0.55, 0.2))
	_tip = _sphere(self, 0.22, GOOD, 8, true)
	_line = ImmediateMesh.new()
	_line_mat = _mat(GOOD, true)
	var line := MeshInstance3D.new()
	line.mesh = _line
	add_child(line)
	for node in [_guide, _guide_warn, _tip]:
		node.visible = false


## Mapa do voo, longe da cena principal: Terra, Lua, órbita de espera e a rota.
func _build_map(mask: ImageTexture) -> void:
	_map = Node3D.new()
	_map.position = MAP
	_map.visible = false
	add_child(_map)
	_map_earth = _earth(3.0, mask)
	_map.add_child(_map_earth)
	var moon := _sphere(_map, 0.9, Color(0.72, 0.71, 0.68), 12)
	moon.position = MAP_MOON
	var orbit := TorusMesh.new()
	orbit.inner_radius = PARKING_RADIUS - 0.03
	orbit.outer_radius = PARKING_RADIUS + 0.03
	orbit.rings = 48
	orbit.ring_segments = 3
	var orbit_ring := MeshInstance3D.new()
	orbit_ring.mesh = orbit
	orbit_ring.material_override = _mat(Color(0.5, 0.6, 0.7), true)
	_map.add_child(orbit_ring)
	for entry in [["TERRA", Vector3(0, 4.2, 0)], ["LUA · DESTINO", MAP_MOON + Vector3(0, 2.6, 0)]]:
		var label := Label3D.new()
		label.text = entry[0]
		label.position = entry[1]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.0011
		label.font_size = 40
		label.outline_size = 8
		label.modulate = Color(0.96, 0.74, 0.36)
		_map.add_child(label)
	# Anel âmbar pulsando em volta da Lua: o destino da travessia.
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.5
	ring_mesh.outer_radius = 1.62
	ring_mesh.rings = 40
	ring_mesh.ring_segments = 3
	_moon_ring = MeshInstance3D.new()
	_moon_ring.mesh = ring_mesh
	_moon_ring.material_override = _mat(Color(0.96, 0.74, 0.36), true)
	_moon_ring.position = MAP_MOON
	_map.add_child(_moon_ring)
	_map_ship = Node3D.new()
	_map.add_child(_map_ship)
	var mini := Node3D.new()
	mini.scale = Vector3.ONE * 0.5
	_map_ship.add_child(mini)
	_cyl(mini, 0.7, 0.7, 1.8, 0.0, Color(0.85, 0.85, 0.82), 10)
	_cyl(mini, 0.12, 0.7, 1.2, -1.5, STEEL, 10)
	var beacon := _sphere(mini, 0.5, Color(1.0, 0.85, 0.5), 6, true)
	beacon.position = Vector3(0, 0, 1.2)
	_path_mesh = ImmediateMesh.new()
	_trail = ImmediateMesh.new()
	for mesh in [_path_mesh, _trail]:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		# A malha muda a cada quadro: um volume fixo evita que o recorte por AABB a esconda.
		instance.custom_aabb = AABB(Vector3(-10, -5, -25), Vector3(55, 10, 40))
		var mat := _mat(Color.WHITE, true)
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		instance.material_override = mat
		_map.add_child(instance)


## Faixa horizontal de `a` até `b`, legível de cima mesmo na meia resolução.
func _ribbon(mesh: ImmediateMesh, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var along := b - a
	if along.length() < 0.0001:
		return
	var side := along.cross(Vector3.UP).normalized() * width * 0.5
	for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(v)


func _bezier(points: Array, t: float) -> Vector3:
	var u := 1.0 - t
	return points[0] * u * u * u + points[1] * 3.0 * u * u * t + points[2] * 3.0 * u * t * t + points[3] * t * t * t


## Rota da órbita de espera, do lado oposto à Lua, até a Lua. Com erro, o fim passa ao lado.
func _build_path() -> void:
	var toward := MAP_MOON.normalized()
	var across := Vector3(-toward.z, 0, toward.x)
	var start := -toward * PARKING_RADIUS
	var miss := across * (0.0 if _flight_error < 0.12 else _flight_error * 6.0)
	var finish := MAP_MOON - toward * 1.4 + across * 1.1 + miss
	var controls := [start, start + across * 11.0, finish - toward * 9.0 + across * 5.0, finish]
	_path.clear()
	for i in 81:
		_path.append(_bezier(controls, i / 80.0))
	_path_mesh.clear_surfaces()
	_path_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var faint := Color(_path_color.r, _path_color.g, _path_color.b) * 0.5
	for i in range(0, _path.size() - 1, 2):
		_ribbon(_path_mesh, _path[i], _path[i + 1], 0.16, faint)
	_path_mesh.surface_end()
	_map_ship.position = _path[0]
