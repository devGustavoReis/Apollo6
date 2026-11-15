extends CharacterBody3D
## Thomas Walker em microgravidade. Começa sentado na cadeira central.
## WASD move na direção do olhar, ESPAÇO sobe, CTRL desce. Soltar as teclas estabiliza.

signal unbuckled

const SPEED := 1.6
const ACCEL := 3.0
const DAMPING := 2.6
const EYE_OFFSET := Vector3(0, 0.35, 0)
## Ponto livre atrás das cadeiras, usado ao soltar o cinto (ver docs/cabin_layout.md).
const FLOAT_START := Vector3(0, 1.0, 0.55)
## Camada das barreiras que só o jogador enxerga, como o tampão do vão da escotilha.
const BARRIER_LAYER := 8

var camera: Camera3D
var seated := true
var frozen := false
var yaw := 0.0
var pitch := 0.0
var moved_distance := 0.0
var look_amount := 0.0
var _shape: CollisionShape3D


func setup(cabin: Node3D) -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1 | BARRIER_LAYER
	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.0
	_shape.shape = capsule
	add_child(_shape)
	camera = Camera3D.new()
	camera.position = EYE_OFFSET
	camera.fov = 78.0
	camera.near = 0.04
	add_child(camera)
	camera.make_current()
	var eye: Marker3D = cabin.get_node("PlayerStart/SeatedEye")
	global_position = eye.global_position - EYE_OFFSET
	seated = true
	_shape.disabled = true


func look(relative: Vector2) -> void:
	yaw -= relative.x * 0.0025
	pitch = clampf(pitch - relative.y * 0.0025, -1.35, 1.35)
	if seated:
		yaw = clampf(yaw, -1.5, 1.5)
	look_amount += relative.length()
	rotation = Vector3(0, yaw, 0)
	camera.rotation.x = pitch


var _touching_surface := false


func unbuckle() -> void:
	if not seated:
		return
	seated = false
	Sound.play_cue("belt")
	frozen = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", FLOAT_START, 0.9).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(func():
		_shape.disabled = false
		frozen = false
		unbuckled.emit())


func _physics_process(delta: float) -> void:
	if seated or frozen:
		velocity = Vector3.ZERO
		return
	var input := Vector3(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_down", "move_up"),
		Input.get_axis("move_forward", "move_back"))
	var direction := camera.global_basis * Vector3(input.x, 0, input.z) + Vector3.UP * input.y
	if direction.length() > 0.01:
		velocity = velocity.move_toward(direction.normalized() * SPEED, ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, DAMPING * delta)
	var before := global_position
	move_and_slide()
	moved_distance += before.distance_to(global_position)
	var touching := get_slide_collision_count() > 0
	if touching and not _touching_surface and before.distance_squared_to(global_position) > 0.000003:
		Sound.play_at("contact", self)
	_touching_surface = touching
