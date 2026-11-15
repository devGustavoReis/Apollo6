extends CharacterBody3D
## Thomas Walker em microgravidade. Começa sentado na cadeira central.
## Em voo livre a velocidade se conserva: só contato com superfícies muda a trajetória.
## ESPAÇO empurra na direção do olhar e WASD dá impulsos curtos, ambos só encostado ou segurando.

signal unbuckled

const EYE_OFFSET := Vector3(0, 0.43, 0)
const FLOAT_START := Vector3(0, 1.0, 0.55)
const BARRIER_LAYER := 8
const PUSH_SPEED := 1.4
const NUDGE_SPEED := 0.6
const RESTITUTION := 0.25
const FRICTION := 0.6
const GRAB_SPEED := 0.25
const CONTACT_GRACE := 0.3
const HELP_SPEED := 0.5
const RIGHT_HAND := Vector3(0.2, -0.24, -0.34)
const LEFT_HAND := Vector3(-0.2, -0.24, -0.34)
const SUIT := Color(0.86, 0.86, 0.82)
const GLOVE := Color(0.95, 0.95, 0.92)

var camera: Camera3D
var seated := true
var frozen := false
var yaw := 0.0
var pitch := 0.0
var moved_distance := 0.0
var look_amount := 0.0
var grabbing := false
var contact_time := 99.0
var still_time := 0.0
var last_impact := {}
var right_hand: Node3D
var left_hand: Node3D
var body: Node3D
var hand_busy := false
var hand_time := 0.0
var push_time := 0.0
var _shape: CollisionShape3D
var _push_was_down := false
var _nudge_was := Vector2.ZERO


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
	right_hand = _make_hand(1.0)
	right_hand.position = RIGHT_HAND
	left_hand = _make_hand(-1.0)
	left_hand.position = LEFT_HAND
	body = _make_body()
	body.scale = Vector3(1.10, 1.14, 1.08)
	add_child(body)
	var eye: Marker3D = cabin.get_node("PlayerStart/SeatedEye")
	global_position = eye.global_position - EYE_OFFSET
	seated = true
	_shape.disabled = true


func _box(size: Vector3, color: Color, where: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	box.material = material
	mesh.mesh = box
	mesh.position = where
	return mesh


func _make_hand(side: float) -> Node3D:
	var hand := Node3D.new()
	hand.name = "RightHand" if side > 0.0 else "LeftHand"
	hand.add_child(_box(Vector3(0.08, 0.05, 0.1), GLOVE, Vector3.ZERO))
	hand.add_child(_box(Vector3(0.025, 0.03, 0.05), GLOVE, Vector3(-0.05 * side, 0.0, -0.02)))
	hand.add_child(_box(Vector3(0.09, 0.08, 0.25), SUIT, Vector3(0.02 * side, -0.01, 0.17)))
	hand.add_child(_box(Vector3(0.095, 0.085, 0.03), Color(0.25, 0.32, 0.55), Vector3(0.02 * side, -0.01, 0.06)))
	camera.add_child(hand)
	return hand


func _make_body() -> Node3D:
	var node := Node3D.new()
	node.name = "Body"
	node.add_child(_box(Vector3(0.42, 0.5, 0.24), SUIT, Vector3(0, -0.05, 0.1)))
	node.add_child(_box(Vector3(0.16, 0.08, 0.03), Color(0.25, 0.32, 0.55), Vector3(0, 0.08, -0.03)))
	node.add_child(_box(Vector3(0.15, 0.5, 0.16), SUIT, Vector3(-0.11, -0.55, 0.12)))
	node.add_child(_box(Vector3(0.15, 0.5, 0.16), SUIT, Vector3(0.11, -0.55, 0.12)))
	node.add_child(_box(Vector3(0.16, 0.1, 0.24), Color(0.4, 0.4, 0.4), Vector3(-0.11, -0.84, 0.08)))
	node.add_child(_box(Vector3(0.16, 0.1, 0.24), Color(0.4, 0.4, 0.4), Vector3(0.11, -0.84, 0.08)))
	return node


func _process(delta: float) -> void:
	if right_hand == null:
		return
	hand_time += delta
	push_time = maxf(push_time - delta, 0.0)
	var sway := Vector3(0, sin(hand_time * 1.3) * 0.006, 0)
	var reach := Vector3(0, 0.06, -0.14) * sin(push_time / 0.35 * PI)
	if seated:
		sway = Vector3(0, -0.04, 0.04)
	if not hand_busy:
		right_hand.position = RIGHT_HAND + sway + reach
		right_hand.rotation = Vector3.ZERO
	left_hand.position = LEFT_HAND + Vector3(0, -sway.y, 0) + reach
	body.visible = camera.rotation.x < -0.2 or seated


func look(relative: Vector2) -> void:
	yaw -= relative.x * 0.0025
	pitch = clampf(pitch - relative.y * 0.0025, -1.35, 1.35)
	if seated:
		yaw = clampf(yaw, -1.5, 1.5)
	look_amount += relative.length()
	rotation = Vector3(0, yaw, 0)
	camera.rotation.x = pitch


func unbuckle() -> void:
	if not seated:
		return
	seated = false
	Sound.play_cue("belt")
	frozen = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", FLOAT_START, 0.9).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(left_hand, "rotation:z", -0.30, 0.28)
	tween.finished.connect(func():
		left_hand.rotation.z = 0.0
		_shape.disabled = false
		frozen = false
		grabbing = true
		velocity = Vector3.ZERO
		unbuckled.emit())


func can_push() -> bool:
	return grabbing or contact_time < CONTACT_GRACE


func needs_help() -> bool:
	return not seated and not can_push() and velocity.length() < 0.05 and still_time > 2.0


func _physics_process(delta: float) -> void:
	if seated or frozen:
		velocity = Vector3.ZERO
		_push_was_down = Input.is_action_pressed("move_up")
		return
	var push_down := Input.is_action_pressed("move_up")
	var push_edge := push_down and not _push_was_down
	_push_was_down = push_down
	var nudge := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_forward", "move_back"))
	var nudge_edge := nudge.length() > 0.1 and _nudge_was.length() <= 0.1
	_nudge_was = nudge
	if push_edge and can_push():
		velocity = -camera.global_basis.z * PUSH_SPEED
		push_time = 0.35
		_release()
	elif nudge_edge and can_push():
		velocity = (camera.global_basis * Vector3(nudge.x, 0, nudge.y)).normalized() * NUDGE_SPEED
		push_time = 0.2
		_release()
	elif push_edge and needs_help():
		velocity = (FLOAT_START - global_position).normalized() * HELP_SPEED
		still_time = 0.0
	drift(delta)


func _release() -> void:
	grabbing = false
	contact_time = CONTACT_GRACE
	still_time = 0.0


## Avança a deriva um passo. Público para os testes de física da cabine.
func drift(delta: float) -> void:
	var before := global_position
	var hit := move_and_collide(velocity * delta)
	if hit != null:
		_contact(hit)
	else:
		contact_time += delta
	moved_distance += before.distance_to(global_position)
	if velocity.length() < 0.05 and not grabbing:
		still_time += delta
	else:
		still_time = 0.0


func _contact(hit: KinematicCollision3D) -> void:
	var normal := hit.get_normal()
	var into := velocity.dot(normal)
	contact_time = 0.0
	if into >= 0.0:
		return
	var tangent := velocity - normal * into
	var before := velocity
	velocity = tangent * FRICTION - normal * into * RESTITUTION
	if velocity.length() < GRAB_SPEED:
		velocity = Vector3.ZERO
		grabbing = true
	last_impact = {"normal": normal, "speed_in": before.length(), "normal_in": -into, "speed_out": velocity.length(), "grabbed": grabbing}
	if -into > 0.15:
		Sound.play_at("contact", self)
