extends Node3D
## Cenário 3D do menu principal: módulo lunar pousado, regolito, pedras, bandeira e a Terra.
## Fica no SubViewport de meia resolução, como a cabine e o pouso.
## As posições na tela usam frações de um quadro 16:9 (0,0 = canto superior esquerdo).

const LM_MODEL := "res://assets/models/landing/lunar_module.glb"
const GROUND_SHADER := preload("res://assets/shaders/menu/moon_ground.gdshader")
const EARTH_SHADER := preload("res://assets/shaders/menu/earth.gdshader")
const LUNAR_FLAG := preload("res://assets/models/landing/lunar_flag.glb")
const FOIL_SHADER := preload("res://assets/shaders/menu/gold_foil.gdshader")

const SUN_DIR := Vector3(0.74, 0.42, 0.52)  ## aponta para o Sol
const CAMERA_POS := Vector3(5.7, 1.6, 11.5)
const CAMERA_PITCH := 8.7
const CAMERA_FOV := 40.0
const ASPECT := 16.0 / 9.0
const LM_YAW := 228.0
const PARALLAX := Vector2(0.28, 0.12)  ## deslocamento máximo da câmera, em metros

## Pedras posicionadas pela tela: [fração x, fração y, raio em metros].
const ROCKS := [
	[0.545, 0.925, 0.50], [0.865, 0.835, 0.80], [0.395, 0.835, 0.30], [0.610, 0.850, 0.20],
	[0.685, 0.825, 0.36], [0.405, 0.895, 0.20], [0.265, 0.955, 0.20], [0.775, 0.820, 0.16],
	[0.945, 0.940, 0.28], [0.470, 0.800, 0.22],
]

## Contornos simplificados dos continentes, em pares longitude/latitude.
const CONTINENTS := [
	# América do Norte e Central
	[-168, 66, -156, 71, -140, 70, -125, 70, -110, 68, -95, 69, -85, 69, -82, 64, -94, 60, -93, 57,
		-85, 55, -80, 51, -78, 57, -77, 62, -70, 62, -65, 60, -60, 55, -56, 52, -60, 47, -65, 44,
		-70, 42, -74, 40, -76, 35, -81, 31, -80, 25, -82, 28, -84, 30, -90, 29, -94, 29, -97, 26,
		-97, 22, -95, 18, -91, 19, -90, 21, -87, 21, -88, 16, -84, 15, -83, 10, -80, 9, -77, 8,
		-80, 7, -83, 8, -85, 10, -87, 13, -92, 15, -96, 16, -102, 18, -105, 20, -106, 23, -110, 23,
		-115, 30, -117, 33, -121, 35, -124, 40, -124, 47, -128, 51, -133, 55, -140, 60, -150, 60,
		-155, 58, -162, 55, -158, 58, -165, 61, -166, 65],
	# Cuba e Hispaniola
	[-85, 22, -80, 23, -75, 20.5, -78, 20],
	[-74, 19.8, -69, 19.6, -68.5, 18.3, -74, 18.2],
	# América do Sul
	[-77, 8, -72, 12, -62, 10.5, -52, 5, -50, 0, -44, -2.5, -35, -6, -37, -12, -39, -18, -41, -22,
		-48, -26, -53, -33, -58, -38, -63, -41, -65, -47, -68, -53, -71, -54, -74, -50, -73, -42,
		-71, -30, -70, -18, -76, -14, -81, -6, -80, -2, -78, 2],
	# Groenlândia e Islândia
	[-52, 82, -30, 83, -18, 78, -22, 70, -40, 65, -44, 60, -50, 62, -54, 68, -58, 75, -68, 78, -60, 82],
	[-24, 65.5, -14, 66, -14, 64, -22, 63.5],
	# África e Madagascar
	[-17, 21, -16, 15, -13, 9, -8, 4.5, 5, 5, 9, 4, 9, -1, 13, -8, 12, -17, 15, -27, 18, -34,
		25, -34, 32, -28, 35, -22, 40, -15, 39, -6, 42, -1, 51, 11, 43, 12, 37, 21, 33, 30, 25, 32,
		20, 31, 10, 34, 10, 37, 0, 36, -6, 35, -10, 30],
	[44, -16, 49, -12, 50, -16, 47, -25, 44, -23],
	# Europa e Ásia
	[-9, 37, -9, 43, -2, 43.5, -1, 46, -4.5, 48.5, 2, 51, 8, 54, 8, 57, 12, 56, 11, 59, 5, 59,
		5, 62, 14, 68, 25, 71, 40, 67, 44, 66, 55, 69, 68, 69, 75, 73, 100, 77, 113, 74, 130, 71,
		160, 70, 180, 69, 180, 65, 178, 62, 163, 57, 156, 51, 156, 57, 142, 59, 135, 54, 141, 48,
		132, 43, 127, 39, 129, 35, 126, 34, 121, 39, 117, 38, 122, 31, 120, 25, 110, 21, 108, 16,
		109, 12, 105, 9, 100, 13, 103, 2, 100, 7, 98, 13, 94, 17, 91, 22, 87, 21, 80, 15, 80, 10,
		77, 8, 73, 17, 72, 21, 67, 25, 57, 25, 50, 30, 48, 30, 51, 25, 56, 24, 59, 22, 55, 17,
		45, 13, 43, 13, 39, 21, 35, 28, 34, 31, 36, 36, 30, 36, 27, 37, 26, 40, 23, 38, 20, 40,
		13, 45, 18, 40, 16, 38, 12, 42, 9, 44, 3, 43, 0, 39, -2, 37],
	# Ilhas Britânicas e Japão
	[-5, 50, 1, 51, 0, 54, -2, 56, -3, 58.5, -6, 57, -5, 54, -3, 53, -5, 52],
	[130, 31, 136, 34, 141, 36, 142, 40, 141, 45, 144, 44, 141, 41, 139, 38, 133, 35],
	# Sudeste Asiático e Oceania
	[95, 5.5, 98, 4, 104, -2, 106, -6, 104, -5.5, 100, -1],
	[109, 1, 113, -3.5, 116, -4, 118, 1, 117, 7, 113, 4],
	[131, -1, 138, -2, 145, -5, 150, -10, 146, -8, 141, -9, 138, -8, 133, -4],
	[114, -22, 114, -34, 118, -35, 129, -32, 138, -35, 146, -39, 150, -37, 153, -28, 146, -19,
		142, -11, 140, -17, 136, -12, 130, -12, 125, -14, 121, -19],
	[173, -35, 178, -38, 175, -41, 172, -44, 167, -46, 171, -42, 174, -39],
	# Antártida
	[-180, -90, -180, -74, -150, -76, -120, -73, -90, -72, -62, -74, -57, -64, -55, -67, -45, -78,
		-20, -73, 10, -70, 40, -68, 70, -68, 100, -66, 130, -66, 160, -70, 180, -74, 180, -90],
]

var camera: Camera3D
var _camera_basis: Basis
var _aim := Vector2.ZERO
var _aim_target := Vector2.ZERO


func _ready() -> void:
	_camera_basis = Basis.from_euler(Vector3(deg_to_rad(CAMERA_PITCH), 0.0, 0.0))
	_build_light()
	_build_ground()
	_build_lunar_module()
	_build_rocks()
	_build_flag()
	_build_earth()
	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.near = 0.2
	camera.far = 6000.0
	camera.position = CAMERA_POS
	camera.basis = _camera_basis
	add_child(camera)
	camera.make_current()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


## Em janelas mais estreitas que 16:9, preserva a largura do quadro
## para não cortar o módulo lunar e a Terra.
func _fit_camera() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y <= 0.0:
		return
	if view.x / view.y < ASPECT:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(CAMERA_FOV) * 0.5) * ASPECT))
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = CAMERA_FOV


## Desloca a câmera de leve conforme o ponteiro (-0,5 a 0,5 em cada eixo), para dar profundidade.
func aim(offset: Vector2) -> void:
	_aim_target = offset.clampf(-0.5, 0.5)


func _process(delta: float) -> void:
	if camera == null or _aim.is_equal_approx(_aim_target):
		return
	_aim = _aim.lerp(_aim_target, minf(1.0, delta * 3.0))
	camera.position = CAMERA_POS + _camera_basis.x * _aim.x * 2.0 * PARALLAX.x - _camera_basis.y * _aim.y * 2.0 * PARALLAX.y


# ---------- Enquadramento ----------

## Direção no mundo de um ponto da tela.
func _ray(screen: Vector2) -> Vector3:
	var t := tan(deg_to_rad(CAMERA_FOV) * 0.5)
	return (_camera_basis * Vector3((screen.x * 2.0 - 1.0) * t * ASPECT, (1.0 - screen.y * 2.0) * t, -1.0)).normalized()


## Ponto do solo visto em uma posição da tela (abaixo do horizonte).
func _ground_at(screen: Vector2) -> Vector3:
	var dir := _ray(screen)
	return CAMERA_POS + dir * (-CAMERA_POS.y / dir.y)


func _screen_of(point: Vector3) -> Vector2:
	var local := _camera_basis.inverse() * (point - CAMERA_POS)
	var t := tan(deg_to_rad(CAMERA_FOV) * 0.5)
	return Vector2(0.5 + local.x / -local.z / (t * ASPECT) * 0.5, 0.5 - local.y / -local.z / t * 0.5)


# ---------- Montagem ----------

func _build_light() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.60, 0.75)
	e.ambient_light_energy = 0.34
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.97, 0.91)
	sun.light_energy = 1.75
	sun.shadow_enabled = true
	sun.shadow_blur = 0.3
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	sun.look_at_from_position(SUN_DIR * 50.0, Vector3.ZERO)
	# Luz de preenchimento azulada, como a claridade refletida pela Terra.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.62, 0.72, 1.0)
	fill.light_energy = 0.28
	add_child(fill)
	fill.look_at_from_position(Vector3(-0.8, 0.35, 0.5) * 50.0, Vector3.ZERO)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	ground.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("sun_dir", SUN_DIR.normalized())
	ground.material_override = mat
	add_child(ground)


func _build_lunar_module() -> void:
	var lm: Node3D = preload("res://scripts/landing/lunar_module_visual.gd").create()
	lm.rotation_degrees.y = LM_YAW
	add_child(lm)


func _build_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1969
	for entry in ROCKS:
		_add_rock(rng, _ground_at(Vector2(entry[0], entry[1])), entry[2])
	var flag_base := _ground_at(Vector2(0.722, 0.862))
	for i in 70:
		var at := Vector3(rng.randf_range(-45.0, 60.0), 0.0, rng.randf_range(-110.0, 6.0))
		var radius := rng.randf_range(0.06, 0.34) * (1.0 + absf(at.z) / 60.0)
		if at.length() < 5.5 or at.distance_to(flag_base) < 1.5:
			continue
		_add_rock(rng, at, radius)
	# Elevações baixas e distantes, para o horizonte não ser uma linha reta.
	for i in 9:
		var hill := _add_rock(rng, Vector3(rng.randf_range(-420.0, 520.0), 0.0, rng.randf_range(-900.0, -480.0)), 1.0)
		hill.scale = Vector3(rng.randf_range(60.0, 150.0), rng.randf_range(5.0, 13.0), rng.randf_range(40.0, 90.0))
		hill.position.y = 0.0
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_rock(rng: RandomNumberGenerator, at: Vector3, radius: float) -> MeshInstance3D:
	var rock := MeshInstance3D.new()
	rock.mesh = _rock_mesh(rng)
	rock.scale = Vector3(radius * rng.randf_range(0.9, 1.4), radius * rng.randf_range(0.6, 0.9), radius * rng.randf_range(0.9, 1.3))
	rock.position = at + Vector3(0, radius * 0.18, 0)
	rock.rotation.y = rng.randf() * TAU
	var mat := StandardMaterial3D.new()
	var tone := rng.randf_range(0.40, 0.52)
	mat.albedo_color = Color(tone, tone * 0.985, tone * 0.96)
	mat.roughness = 1.0
	rock.material_override = mat
	add_child(rock)
	return rock


## Pedra facetada: esfera de poucos lados, deformada por ruído e com normais planas.
func _rock_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 7
	sphere.rings = 4
	var tool := SurfaceTool.new()
	tool.create_from(sphere, 0)
	tool.deindex()
	var source: PackedVector3Array = tool.commit_to_arrays()[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.9
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(0, source.size(), 3):
		var tri := PackedVector3Array()
		for j in 3:
			var v := source[i + j]
			v *= 1.0 + noise.get_noise_3dv(v) * 0.55
			v.y = maxf(v.y, -0.3)
			tri.append(v)
		var normal := (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
		if normal.dot(tri[0] + tri[1] + tri[2]) < 0.0:
			normal = -normal
		vertices.append_array(tri)
		normals.append_array(PackedVector3Array([normal, normal, normal]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_flag() -> void:
	var base := _ground_at(Vector2(0.722, 0.862))
	# Altura do mastro que leva o topo até 53% da tela.
	var low := 1.0
	var high := 9.0
	for i in 20:
		var mid := (low + high) * 0.5
		if _screen_of(base + Vector3(0, mid, 0)).y > 0.53:
			low = mid
		else:
			high = mid
	var height := (low + high) * 0.5
	var flag := LUNAR_FLAG.instantiate() as Node3D
	flag.position = base
	flag.scale = Vector3.ONE * height
	flag.rotation_degrees.y = -8.0
	add_child(flag)


func _build_earth() -> void:
	var dir := _ray(Vector2(0.872, 0.385))
	var distance := 1500.0
	var depth := distance * dir.dot(-_camera_basis.z)
	var radius := depth * 0.072 * 2.0 * tan(deg_to_rad(CAMERA_FOV) * 0.5) * ASPECT
	var earth := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	earth.mesh = sphere
	earth.position = CAMERA_POS + dir * distance
	# Polo norte inclinado para a câmera e girado para a esquerda, com as Américas de frente.
	var to_camera := -dir
	earth.basis = Basis(to_camera, deg_to_rad(18.0)) * Basis(_camera_basis.x, deg_to_rad(12.0))
	var local := earth.basis.inverse() * to_camera
	var mat := ShaderMaterial.new()
	mat.shader = EARTH_SHADER
	mat.set_shader_parameter("land_mask", _land_mask())
	mat.set_shader_parameter("lon_shift", (180.0 - 74.0) / 360.0 - atan2(local.x, local.z) / TAU)
	mat.set_shader_parameter("sun_dir", (SUN_DIR.normalized() + to_camera * 1.5).normalized())
	earth.material_override = mat
	earth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(earth)


## Máscara terra/mar de 2° por pixel, em projeção equirretangular.
func _land_mask() -> ImageTexture:
	var image := Image.create(180, 90, false, Image.FORMAT_L8)
	for outline in CONTINENTS:
		var polygon := PackedVector2Array()
		var box := Rect2(outline[0], outline[1], 0, 0)
		for i in range(0, outline.size(), 2):
			var point := Vector2(outline[i], outline[i + 1])
			polygon.append(point)
			box = box.expand(point)
		var x0 := clampi(int((box.position.x + 180.0) / 2.0), 0, 179)
		var x1 := clampi(int((box.end.x + 180.0) / 2.0), 0, 179)
		var y0 := clampi(int((90.0 - box.end.y) / 2.0), 0, 89)
		var y1 := clampi(int((90.0 - box.position.y) / 2.0), 0, 89)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if Geometry2D.is_point_in_polygon(Vector2(-179.0 + x * 2.0, 89.0 - y * 2.0), polygon):
					image.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)
