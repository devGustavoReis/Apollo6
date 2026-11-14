extends CharacterBody3D
## Removable inspection controller. Equipment and game logic live in separate scenes.

@onready var cabin: Node3D = get_parent()
@onready var camera: Camera3D = $Camera3D
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var help: Label = $CanvasLayer/Help
var seated := true
var pitch := 0.0

func _ready() -> void:
	_set_seated(true)

func _set_seated(value: bool) -> void:
	seated = value
	velocity = Vector3.ZERO
	pitch = 0.0
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	collider.disabled = seated
	if seated:
		global_transform = cabin.get_node("PlayerStart/SeatedEye").global_transform
		camera.position = Vector3.ZERO
		help.text = "ENTER · levantar   |   Clique · olhar   |   ESC · liberar mouse"
	else:
		global_transform = cabin.get_node("PlayerStart/ExplorationStart").global_transform
		camera.position = Vector3(0, 1.55, 0)
		help.text = "WASD · mover   |   Mouse · olhar   |   ENTER · sentar   |   ESC · liberar mouse"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			_set_seated(not seated)
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.0025)
		pitch = clampf(pitch - event.relative.y * 0.0025, -1.2, 1.2)
		camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	if seated:
		return
	var direction := Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		direction = Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		).normalized()
	var motion := basis * Vector3(direction.x, 0, direction.y)
	velocity.x = motion.x * 1.5
	velocity.z = motion.z * 1.5
	velocity.y -= 9.8 * delta
	move_and_slide()
