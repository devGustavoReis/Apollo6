extends Node3D
## Surface activity. MissionState owns the evidence and persistent milestones.

enum Stage { EXPLORE, WORK, FLAG, RETURN, BOARDING }

const MODULE := preload("res://assets/models/landing/lunar_module.glb")
const FLAG := preload("res://assets/models/landing/lunar_flag.glb")
const GLOVE := preload("res://assets/models/lunar_surface/eva_glove.glb")
const CASE := preload("res://assets/models/science/lunar_sample_container_closed.glb")
const CASE_OPEN := preload("res://assets/models/science/lunar_sample_container_open.glb")
const REFLECTOR := preload("res://assets/models/science/laser_retroreflector.glb")
const CAMERA := preload("res://assets/models/science/surface_camera.glb")
const SITES := {
	"sample_kit": Vector3(-34, 0, -43),
	"retroreflector": Vector3(7, 0, -57),
	"camera": Vector3(46, 0, -42),
}
const APPROACH := {
	"sample_kit": "Reach the sampling site",
	"retroreflector": "Reach the reflector deployment site",
	"camera": "Reach the survey point",
}
const ACTION := {
	"sample_kit": "Collect sample",
	"retroreflector": "Deploy laser reflector",
	"camera": "Take photo",
}
const BRIEFING := {
	"sample_kit": ["surface_sampling", "Head to the marked sampling site. Collect the identified rock and secure it in the sample case.", "Vá à área de coleta marcada. Recolha a rocha indicada e guarde-a na maleta."],
	"retroreflector": ["surface_reflector", "Proceed to the deployment site. Set the laser reflector on the marked patch and wait for the pulse from Earth.", "Siga até a área de instalação. Coloque o retrorrefletor no ponto marcado e aguarde o pulso da Terra."],
	"camera": ["surface_survey", "Go to the survey point and photograph the marked terrain.", "Vá ao ponto de observação e fotografe o terreno indicado."],
}
const BOARD := Vector3(0, 0, 3.8)
const FLAG_SITE := Vector3(5.1, 0, 1.1)
const SPAWN := Vector3(3.8, 0, 3.7)
const SPEED := 3.4
const GRAVITY := 3.2
const RANGE := 4.4

@onready var environment_model: Node3D = $EnvironmentModel
@onready var sample_rock: Node3D = $EnvironmentModel/SampleRock
@onready var earth: Node3D = $EnvironmentModel/Earth

var objective := ""
var stage := Stage.EXPLORE
var player: CharacterBody3D
var camera: Camera3D
var overview: Camera3D
var site := Vector3.ZERO
var focus := Vector3.ZERO
var board_position := Vector3.ZERO
var beacon: Label3D
var title: Label
var instruction: Label
var status: Label
var prompt: Label
var crosshair: Label
var pause_panel: CenterContainer
var flag_rig: Node3D
var flag_player: AnimationPlayer
var shutter: AudioStreamPlayer
var _yaw := 0.0
var _pitch := 0.0
var _initialized := false
var _action_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	objective = MissionState.objective
	if not MissionState.can_start_surface():
		if MissionState.checkpoints.has("landing") and not MissionState.landing_result.get("success", false):
			Game.retry_from_checkpoint("landing", "landing")
		else:
			MissionState.end_mission("lunar_ops", tr("The lunar activity is unavailable. Check the science instrument and landing result."))
			Game.finish_mission()
		return
	Sound.enter_scene("surface")
	_build_light()
	_set_surface_materials()
	for mesh_name in ["Walkable", "SampleLandmarks", "SurveyRidge", "BearingRocks"]:
		environment_model.get_node(mesh_name).create_trimesh_collision()
	_build_limits()
	_build_hud()
	var module := _instance(MODULE, Vector3.ZERO)
	module.rotation.y = PI
	_collider(Vector3(0, 1.1, -0.1), Vector3(2.6, 2.2, 2.65))
	_build_player()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_finish_setup()


func _finish_setup() -> void:
	player.position = _ground(SPAWN) + Vector3.UP * 0.09
	board_position = _ground(BOARD)
	site = _ground(SITES[objective])
	focus = site + Vector3.UP * 0.26
	if objective == "camera":
		focus = _ground(Vector3(48, 0, -50)) + Vector3.UP * 0.45
	sample_rock.visible = objective == "sample_kit" and not MissionState.science_completed
	var destination := site
	_yaw = atan2(-(destination.x - player.position.x), -(destination.z - player.position.z))
	player.rotation.y = _yaw
	_build_flag()
	_build_beacon()
	var wav_path := "res://assets/audio/lunar_surface/camera_shutter.wav"
	shutter = AudioStreamPlayer.new()
	shutter.bus = "SFX"
	shutter.process_mode = Node.PROCESS_MODE_PAUSABLE
	shutter.stream = load(wav_path)
	add_child(shutter)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_initialized = true
	if MissionState.science_completed:
		_restore_science_visual()
		if MissionState.lunar_flag_planted:
			_finish_flag(false)
		else:
			_start_flag()
		return
	_set_instruction(APPROACH[objective], site)
	Houston.say_recorded("surface_exterior", "Eagle, Houston. You’re clear to begin surface operations.",
		"Eagle, aqui é Houston. Operações na superfície autorizadas.")
	var line: Array = BRIEFING[objective]
	Houston.say_recorded(line[0], line[1], line[2])


func _build_light() -> void:
	var world := WorldEnvironment.new()
	var look := Environment.new()
	look.background_mode = Environment.BG_COLOR
	look.background_color = Color("#030408")
	look.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	look.ambient_light_color = Color("#929bad")
	look.ambient_light_energy = 0.55
	world.environment = look
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, -38, 0)
	sun.light_color = Color("#fff0d0")
	sun.light_energy = 1.02
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 125.0
	add_child(sun)


func _set_surface_materials() -> void:
	var dust := StandardMaterial3D.new()
	dust.albedo_color = Color(0.57, 0.57, 0.60)
	dust.vertex_color_use_as_albedo = true
	dust.roughness = 0.95
	var globe := StandardMaterial3D.new()
	globe.albedo_color = Color(0.82, 0.90, 1.0)
	globe.vertex_color_use_as_albedo = true
	globe.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for node in environment_model.get_children():
		if node is MeshInstance3D:
			node.material_override = globe if node == earth else dust
	if earth is MeshInstance3D:
		earth.material_override = globe


func _build_limits() -> void:
	_collider(Vector3(112, 2, 0), Vector3(2, 12, 224))
	_collider(Vector3(-112, 2, 0), Vector3(2, 12, 224))
	_collider(Vector3(0, 2, 112), Vector3(224, 12, 2))
	_collider(Vector3(0, 2, -112), Vector3(224, 12, 2))


func _collider(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = SPAWN + Vector3.UP
	player.floor_snap_length = 0.38
	player.floor_max_angle = deg_to_rad(45.0)
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.76
	capsule.radius = 0.28
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.88
	player.add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.63
	camera.fov = 66.0
	camera.far = 480.0
	player.add_child(camera)
	add_child(player)
	camera.make_current()


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 22)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(Game.make_label(tr("LUNAR SURFACE"), 16, Game.AMBER))
	title = Game.make_label(tr(MissionState.OBJECTIVES[objective]["title"]), 23)
	column.add_child(title)
	instruction = Game.make_label("", 17)
	column.add_child(instruction)
	status = Game.make_label("", 16, Game.GOOD)
	column.add_child(status)
	crosshair = _center_label(hud, 0.5, 18)
	crosshair.text = "+"
	prompt = _center_label(hud, 0.69, 23)
	_center_label(hud, 0.83, 15).text = tr("WASD  Walk    ·    Mouse  Look    ·    Esc  Pause")

	pause_panel = CenterContainer.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(pause_panel)
	var pause_card := PanelContainer.new()
	pause_panel.add_child(pause_card)
	var menu := VBoxContainer.new()
	pause_card.add_child(menu)
	menu.add_child(Game.make_label(tr("Surface operations paused"), 25, Game.AMBER))
	var resume := Button.new()
	resume.text = tr("Resume")
	resume.pressed.connect(_set_paused.bind(false))
	menu.add_child(resume)
	pause_panel.hide()


func _center_label(parent: CanvasLayer, height: float, font_size: int) -> Label:
	var label := Game.make_label("", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_top = height
	label.anchor_bottom = height
	label.anchor_right = 1.0
	label.offset_top = -font_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label


func _build_beacon() -> void:
	beacon = Label3D.new()
	beacon.text = "◇"
	beacon.modulate = Game.AMBER
	beacon.outline_size = 6
	beacon.font_size = 42
	beacon.pixel_size = 0.0015
	beacon.fixed_size = true
	beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(beacon)


func _ground(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 12, at - Vector3.UP * 20)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return Vector3(at.x, hit["position"].y, at.z) if not hit.is_empty() else at


func _instance(model: PackedScene, at: Vector3) -> Node3D:
	var node := model.instantiate() as Node3D
	node.position = at
	add_child(node)
	return node


func _set_instruction(text: String, destination: Vector3) -> void:
	instruction.text = tr(text)
	beacon.position = destination + Vector3.UP * 1.8
	beacon.show()


func _process(_delta: float) -> void:
	if stage != Stage.FLAG or get_tree().paused or not is_instance_valid(overview):
		return
	var left: Node3D = flag_rig.get_node("Left")
	var right: Node3D = flag_rig.get_node("Right")
	left.look_at(overview.to_global(Vector3(-1.08, -0.90, 0.59)), Vector3.UP, true)
	right.look_at(overview.to_global(Vector3(-0.68, -1.05, 0.59)), Vector3.UP, true)


func _physics_process(delta: float) -> void:
	if not _initialized or get_tree().paused:
		return
	if stage != Stage.EXPLORE and stage != Stage.RETURN:
		return
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := player.basis * Vector3(move.x, 0, move.y) * SPEED
	player.velocity.x = move_toward(player.velocity.x, direction.x, delta * 12.0)
	player.velocity.z = move_toward(player.velocity.z, direction.z, delta * 12.0)
	player.velocity.y = 0.0 if player.is_on_floor() else player.velocity.y - GRAVITY * delta
	player.move_and_slide()
	if player.position.y < -15.0:
		player.position = _ground(SPAWN) + Vector3.UP * 0.09
		player.velocity = Vector3.ZERO
	var available := _can_interact()
	var distance := player.position.distance_to(board_position if stage == Stage.RETURN else site)
	beacon.visible = not available
	var action: String = "Board Lunar Module" if stage == Stage.RETURN else ACTION[objective]
	prompt.text = "%s  %s" % [_key_hint(), tr(action)] if available else ""
	if not available:
		var active_instruction: String = "Return to the Lunar Module" if stage == Stage.RETURN else APPROACH[objective]
		instruction.text = "%s  ·  %d m" % [tr(active_instruction), roundi(distance)]


func _key_hint() -> String:
	for event in InputMap.action_get_events("interact"):
		if event is InputEventKey:
			var key: Key = event.physical_keycode if event.physical_keycode else event.keycode
			return "[%s]" % OS.get_keycode_string(key)
	return "[E]"


func _can_interact() -> bool:
	if stage != Stage.EXPLORE and stage != Stage.RETURN:
		return false
	var target := focus
	var area := site
	if stage == Stage.RETURN:
		area = board_position
		target = board_position + Vector3.UP * 0.9
	if player.position.distance_to(area) > RANGE:
		return false
	var aim := target - camera.global_position
	if aim.length_squared() < 0.008 or -camera.global_basis.z.dot(aim.normalized()) < 0.88:
		return false
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, target)
	ray.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or target.distance_to(hit["position"]) < 0.48


func _unhandled_input(event: InputEvent) -> void:
	if not _initialized:
		return
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
	elif get_tree().paused:
		return
	elif stage == Stage.FLAG and event.is_action_pressed("advance"):
		_finish_flag()
	elif event.is_action_pressed("interact") and _can_interact():
		_interact()
	elif (stage == Stage.EXPLORE or stage == Stage.RETURN) and event is InputEventMouseMotion:
		_yaw -= event.relative.x * 0.002
		_pitch = clampf(_pitch - event.relative.y * 0.002, -1.38, 1.38)
		player.rotation.y = _yaw
		camera.rotation.x = _pitch
	else:
		return
	get_viewport().set_input_as_handled()


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	pause_panel.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func _interact() -> void:
	if stage == Stage.RETURN:
		stage = Stage.BOARDING
		MissionState.save_checkpoint("lunar_surface")
		Game.open_transition("B")
		return
	if stage != Stage.EXPLORE:
		return
	stage = Stage.WORK
	instruction.text = tr(ACTION[objective])
	beacon.hide()
	prompt.text = ""
	player.velocity = Vector3.ZERO
	_action_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	match objective:
		"sample_kit":
			var case_at := _ground(site + Vector3(0.65, 0, 0.32))
			var case_node := _instance(CASE, case_at)
			_action_tween.tween_property(sample_rock, "global_position", sample_rock.global_position + Vector3.UP * 0.58, 0.38)
			_action_tween.tween_property(sample_rock, "global_position", case_at + Vector3.UP * 0.27, 0.44)
			_action_tween.tween_callback(func():
				sample_rock.hide()
				case_node.queue_free()
				_instance(CASE_OPEN, case_at))
		"retroreflector":
			var reflector := _place_reflector(site + Vector3.UP * 0.7)
			_action_tween.tween_property(reflector, "position:y", site.y, 0.64)
			_action_tween.tween_interval(0.33)
			_action_tween.tween_callback(_pulse.bind(reflector))
			_action_tween.tween_interval(1.6)
		"camera":
			var instrument := CAMERA.instantiate() as Node3D
			instrument.position = Vector3(0.18, -0.36, -0.49)
			camera.add_child(instrument)
			_action_tween.tween_property(instrument, "position:y", -0.20, 0.24)
			_action_tween.tween_callback(_take_photo)
			_action_tween.tween_interval(0.6)
			_action_tween.tween_callback(instrument.queue_free)
	_action_tween.tween_callback(_record_science)


func _take_photo() -> void:
	Houston.clear()
	shutter.play()


func _place_reflector(at: Vector3) -> Node3D:
	var reflector := _instance(REFLECTOR, at)
	var bearing := earth.global_position - reflector.global_position
	reflector.rotation.y = atan2(bearing.x, bearing.z)
	return reflector


func _pulse(reflector: Node3D) -> void:
	var green := StandardMaterial3D.new()
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green.albedo_color = Color("#73ff80")
	var beam := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	var receiver := reflector.to_global(Vector3(0, 0.362, 0.016))
	var origin := earth.global_position.lerp(receiver, 0.045)
	var direction := origin - receiver
	tube.top_radius = 0.028
	tube.bottom_radius = 0.028
	tube.height = direction.length()
	tube.radial_segments = 7
	beam.mesh = tube
	beam.material_override = green
	add_child(beam)
	var axis := Vector3.UP.cross(direction.normalized()).normalized()
	beam.basis = Basis(axis, Vector3.UP.angle_to(direction))
	beam.global_position = receiver.lerp(origin, 0.5)
	var glow := OmniLight3D.new()
	glow.light_color = Color("#64ff61")
	glow.light_energy = 1.25
	glow.omni_range = 1.55
	add_child(glow)
	glow.global_position = receiver
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	fade.tween_interval(1.12)
	fade.tween_callback(beam.queue_free)
	fade.tween_property(glow, "light_energy", 0.0, 0.22)
	fade.tween_callback(glow.queue_free)


func _record_science() -> void:
	if not MissionState.complete_science():
		MissionState.end_mission("lunar_ops", tr("The science evidence could not be recorded."))
		Game.finish_mission()
		return
	MissionState.save_checkpoint("lunar_surface")
	var message := ""
	match objective:
		"sample_kit":
			message = "Sample secured"
			Houston.say_recorded("surface_sample_secured", "Sample secured.", "Amostra guardada.", "THOMAS WALKER")
		"retroreflector":
			message = "Earth–Moon measurement recorded"
			Houston.say_recorded("surface_laser_return", "Laser return confirmed. Measurement recorded.", "Retorno do laser confirmado. Medição registrada.")
		"camera":
			message = "Terrain survey recorded"
	status.text = tr(message)
	_start_flag()


func _restore_science_visual() -> void:
	match objective:
		"sample_kit":
			_instance(CASE_OPEN, _ground(site + Vector3(0.65, 0, 0.32)))
		"retroreflector":
			_place_reflector(site)


func _build_flag() -> void:
	flag_rig = Node3D.new()
	flag_rig.position = _ground(FLAG_SITE)
	add_child(flag_rig)
	var pole := FLAG.instantiate() as Node3D
	pole.name = "Pole"
	pole.scale *= 2.05
	flag_rig.add_child(pole)
	for side in ["Left", "Right"]:
		var glove := GLOVE.instantiate() as Node3D
		glove.name = side
		glove.scale *= 1.38
		flag_rig.add_child(glove)
	flag_player = AnimationPlayer.new()
	flag_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	flag_rig.add_child(flag_player)
	var sequence := Animation.new()
	sequence.length = 5.2
	var times := [0.0, 0.9, 1.75, 2.65, 3.2, 4.0, 5.2]
	_add_track(sequence, "Pole:position", times, [
		Vector3(-0.72, 0.38, 0.03), Vector3(-0.38, 0.30, 0.03), Vector3(0, 0.20, 0), Vector3.ZERO,
		Vector3(0, -0.10, 0), Vector3(0, -0.10, 0), Vector3(0, -0.10, 0)])
	_add_track(sequence, "Pole:rotation_degrees", times, [
		Vector3(0, -12, 26), Vector3(0, -9, 16), Vector3(0, -6, 3), Vector3(0, -6, 0),
		Vector3(0, -6, 0), Vector3(0, -6, 0), Vector3(0, -6, 0)])
	_add_track(sequence, "Left:position", times, [
		Vector3(-1.21, 1.48, 0.11), Vector3(-0.76, 1.35, 0.09), Vector3(-0.12, 1.24, 0.08), Vector3(-0.09, 1.02, 0.08),
		Vector3(-0.09, 0.92, 0.08), Vector3(-0.67, 0.65, 0.15), Vector3(-1.30, 0.15, 0.32)])
	_add_track(sequence, "Right:position", times, [
		Vector3(-1.01, 1.02, 0.13), Vector3(-0.61, 0.93, 0.12), Vector3(0.08, 0.83, 0.10), Vector3(0.10, 0.64, 0.10),
		Vector3(0.10, 0.54, 0.10), Vector3(-0.43, 0.37, 0.2), Vector3(-1.04, 0.10, 0.32)])
	for hand in ["Left", "Right"]:
		var visibility := sequence.add_track(Animation.TYPE_VALUE)
		sequence.track_set_path(visibility, NodePath(hand + ":visible"))
		sequence.value_track_set_update_mode(visibility, Animation.UPDATE_DISCRETE)
		sequence.track_insert_key(visibility, 0.0, true)
		sequence.track_insert_key(visibility, 3.95, false)
	var library := AnimationLibrary.new()
	library.add_animation("plant", sequence)
	flag_player.add_animation_library("", library)
	flag_player.animation_finished.connect(func(_animation): _finish_flag())
	flag_rig.hide()


func _add_track(sequence: Animation, path: String, times: Array, poses: Array) -> void:
	var index := sequence.add_track(Animation.TYPE_VALUE)
	sequence.track_set_path(index, NodePath(path))
	var interpolation := Animation.INTERPOLATION_LINEAR if path.begins_with("Pole:") else Animation.INTERPOLATION_CUBIC
	sequence.track_set_interpolation_type(index, interpolation)
	for key in times.size():
		sequence.track_insert_key(index, times[key], poses[key])


func _start_flag() -> void:
	stage = Stage.FLAG
	beacon.hide()
	crosshair.hide()
	prompt.text = tr("[Enter] Skip flag sequence")
	instruction.text = tr("Planting the flag")
	overview = Camera3D.new()
	overview.fov = 48.0
	overview.far = 380.0
	add_child(overview)
	overview.position = flag_rig.position + Vector3(1.25, 1.38, 4.15)
	overview.look_at(flag_rig.position + Vector3(-0.6, 1.02, 0))
	overview.make_current()
	flag_rig.show()
	flag_player.play("plant")


func _finish_flag(play_line := true) -> void:
	if stage != Stage.FLAG and not MissionState.lunar_flag_planted:
		return
	var new_milestone := not MissionState.lunar_flag_planted
	if flag_player.is_playing():
		flag_player.stop()
	var pole := flag_rig.get_node("Pole") as Node3D
	pole.position = Vector3(0, -0.1, 0)
	pole.rotation_degrees = Vector3(0, -6, 0)
	flag_rig.get_node("Left").hide()
	flag_rig.get_node("Right").hide()
	flag_rig.show()
	camera.make_current()
	if is_instance_valid(overview):
		overview.queue_free()
	crosshair.show()
	prompt.text = ""
	stage = Stage.RETURN
	_set_instruction("Return to the Lunar Module", board_position)
	if new_milestone:
		MissionState.lunar_flag_planted = true
		MissionState.save_checkpoint("lunar_surface")
		if play_line:
			Houston.say_recorded("surface_return", "Surface operations complete. Return to the Lunar Module.", "Operação na superfície concluída. Retorne ao módulo lunar.")
