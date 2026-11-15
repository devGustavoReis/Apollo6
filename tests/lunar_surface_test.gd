extends SceneTree
## Three surface routes, checkpoint restoration, objective evidence and flag state.

var failures := 0
var ms: Node
var game: Node


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func wait_for_surface() -> Node:
	for i in 150:
		await physics_frame
		if current_scene != null and current_scene.name == "LunarSurface" and current_scene._initialized:
			return current_scene
	check(false, "Lunar surface did not initialize")
	return null


func run() -> void:
	game = root.get_node("Game")
	ms = root.get_node("MissionState")
	var houston := root.get_node("Houston")
	for id in ["sample_kit", "retroreflector", "camera"]:
		ms.reset("normal")
		ms.select_objective(id)
		ms.set_qty(id, 1)
		ms.apply_plan()
		ms.stage = "lunar_ops"
		ms.landing_result = {"success": true}
		game.go("lunar_surface")
		var surface: Node = await wait_for_surface()
		if surface == null:
			break
		check(surface.shutter.stream != null, "Single photo sound exists")
		check(houston._current.get("stream") != null and houston._queue.size() == 1 and houston._queue[0]["stream"] != null, "The two English briefings are recorded")
		check(not surface._can_interact(), "The objective must be reached on foot")
		check(surface.sample_rock.visible == (id == "sample_kit"), "Only the chosen visual activity is active")
		Input.action_press("move_forward")
		for frame in 1400:
			await physics_frame
			if surface.player.position.distance_to(surface.site) < 2.6:
				break
		Input.action_release("move_forward")
		check(surface.player.position.distance_to(surface.site) < 3.0, "The starter route is walkable to " + id)
		await physics_frame
		surface.camera.look_at(surface.focus)
		check(surface._can_interact(), "The target is reachable at " + id)
		surface._interact()
		surface._interact()
		check(not ms.science_completed, "The science result waits for the interaction")
		surface._action_tween.custom_step(5.0)
		check(ms.science_completed and surface.stage == surface.Stage.FLAG, "The selected task records science and plays the flag")
		check(not ms.lunar_flag_planted, "Evidence and the flag have independent milestones")
		var evidence_count: int = ms.events.size()
		check(not ms.complete_science() and ms.events.size() == evidence_count, "Science cannot be repeated")
		if id == "sample_kit":
			game.go("lunar_surface")
			await process_frame
			surface = await wait_for_surface()
			check(surface.stage == surface.Stage.FLAG and not surface.sample_rock.visible, "Checkpoint recreates the flag sequence and collected model")
			surface._finish_flag()
		elif id == "retroreflector":
			var remaining: AnimationPlayer = surface.flag_player
			remaining.advance(5.3)
		else:
			surface._finish_flag()
		check(ms.lunar_flag_planted and surface.stage == surface.Stage.RETURN and surface.camera.current, "The flag restores walking and the return objective")
		var flag: Node3D = surface.flag_rig.get_node("Pole")
		check(is_equal_approx(flag.position.y, -0.1), "Flag pole is planted in the final pose")
		if id == "camera":
			ms.restore_checkpoint("lunar_surface")
			game.go("lunar_surface")
			await process_frame
			surface = await wait_for_surface()
			check(surface.stage == surface.Stage.RETURN, "A planted flag restores without replay")
		surface.player.position = surface.board_position + Vector3(0, 0.01, 1.0)
		await physics_frame
		surface.camera.look_at(surface.board_position + Vector3.UP * 0.9)
		check(surface._can_interact(), "The astronaut can board near the module")
		surface._interact()
		await process_frame
		await process_frame
		check(game.transition_id == "B" and ms.jumps.is_empty(), "Boarding opens transition B and waits before charging the jump")
	houston.clear()
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	var sound := root.get_node("Sound")
	sound.set_process(false)
	for player in sound.get_children():
		if player is AudioStreamPlayer:
			player.stop()
	await process_frame
	print("LUNAR SURFACE CHECKS: ", failures, " failures")
	quit(0 if failures == 0 else 1)
