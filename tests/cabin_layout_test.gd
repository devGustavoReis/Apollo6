extends SceneTree

var cabin: Node3D
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func ray(a: Vector3, b: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a,b)
	query.exclude = [cabin.get_node("PreviewPlayer").get_rid()]
	query.hit_back_faces = true
	return cabin.get_world_3d().direct_space_state.intersect_ray(query)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	cabin = load("res://scenes/spacecraft_interior.tscn").instantiate()
	root.add_child(cabin)
	await physics_frame
	await physics_frame
	var player = cabin.get_node("PreviewPlayer")
	check(player.global_position.is_equal_approx(Vector3(0,1.12,-0.3)),"Seated eye position")
	check(player.camera.global_basis.z.is_equal_approx(Vector3.BACK),"Initial view faces console")
	check(not ray(Vector3(0,2.2,0.6),Vector3(0,3.1,0.6)),"Hatch aperture obstructed")
	check(not ray(Vector3(0,1.29,-1.94),Vector3(0,1.29,-2.3)),"Opaque wall beyond front glass")
	var glass_hit := ray(Vector3(0,1.29,-1.5),Vector3(0,1.29,-2.1))
	check(not glass_hit.is_empty() and str(glass_hit.collider.name)=="Glass0","Front aperture glass only")
	for x in [-1.0,0.0,1.0]:
		check(not ray(Vector3(x,0.3,0.7),Vector3(x,-0.3,0.7)).is_empty(),"Floor coverage")
	check(not ray(Vector3(0,1,1.5),Vector3(0,1,2.3)).is_empty(),"Rear wall collision")
	player._set_seated(false)
	for i in range(90):
		await physics_frame
	check(player.position.y > -0.01 and player.position.y < 0.1,"Player must rest on deck")
	# Verify circulation with the exact player capsule at standing height.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.22
	capsule.height = 1.65
	for p in [Vector3(0,0.84,0.72),Vector3(-1.1,0.84,0.72),Vector3(1.1,0.84,0.72),Vector3(0,0.84,1.05)]:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY,p)
		query.exclude = [player.get_rid()]
		check(cabin.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Circulation clearance at "+str(p))
	# Straight movement must stop at the rear wall.
	player.set_physics_process(false)
	for i in range(120):
		player.velocity = Vector3(0,0,1.5)
		player.move_and_slide()
		await physics_frame
	check(player.position.z < 1.65 and player.position.z > 1.4,"Rear wall must stop the player")
	# Reserve future equipment envelopes and check access from the aisle.
	var envelopes: Array[AABB] = []
	var ignored: Array[RID] = [player.get_rid()]
	for body in cabin.get_node("EquipmentSlots").find_children("*", "CollisionObject3D", true, false):
		ignored.append(body.get_rid())
	for marker in cabin.get_node("EquipmentSlots").get_children():
		var dimensions: Vector3 = marker.get_meta("max_size_m")
		var envelope: AABB = marker.global_transform * AABB(
			Vector3(-dimensions.x * 0.5, 0, -dimensions.z * 0.5), dimensions)
		for previous in envelopes:
			check(not envelope.intersects(previous), "Equipment envelopes overlap: "+str(marker.name))
		envelopes.append(envelope)
		var shape := BoxShape3D.new()
		shape.size = dimensions * 0.98
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = marker.global_transform.translated(Vector3(0,dimensions.y*0.5+0.01,0))
		query.exclude = ignored
		check(cabin.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Equipment intersects shell: "+str(marker.name))
	# Capture a rendered review image when using a graphics driver.
	if DisplayServer.get_name() != "headless":
		player._set_seated(false)
		player.position = Vector3(0,0.02,1.04)
		player.camera.rotation.x = 0.12
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/cabin_review.png")
	print("CABIN CHECKS: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
