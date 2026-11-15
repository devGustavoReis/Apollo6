extends Node
## Etapa jogável da cabine: tutorial, tarefas diárias, decisões e eventos.
## A arquitetura da cabine continua em scenes/spacecraft_interior.tscn.
## Os modelos dos equipamentos podem ser instanciados como filhos dos marcadores
## de EquipmentSlots: a interação continua funcionando (ver docs/gameplay_prototype.md).

const PLAYER_SCRIPT := preload("res://scripts/player/zero_g_player.gd")
const HUD_SCRIPT := preload("res://scripts/ui/cabin_hud.gd")
const TRAJECTORY_SCENE := preload("res://scenes/minigames/trajectory_minigame.tscn")
const BRIEFINGS := preload("res://scripts/mission/cabin_briefings.gd")
const HELD_MODELS := {
	"food_odd": "res://assets/models/equipment/sugar_cookie_cubes.glb",
	"food_even": "res://assets/models/equipment/bacon_bars.glb",
	"water": "res://assets/models/equipment/water_pouch.glb",
}
const SCIENCE_SCALE := {"lunar_sample_container_open": 0.8, "lunar_sample_container_closed": 0.8, "laser_retroreflector": 0.65, "surface_camera": 1.0}
const INTERACT_LAYER := 2
const REACH := 2.3
const EAT_TIME := 1.6
const EAT_MARK := 0.9
const HAND_POS := Vector3(0.13, -0.09, -0.3)
const MOUTH_POS := Vector3(0.02, -0.05, -0.13)

## Marcador do slot -> [id da interação, etiqueta visível].
const STATIONS := {
	"MainConsole": ["console", "COMMAND CONSOLE"],
	"NavigationPanel": ["nav", "NAVIGATION"],
	"RadioPanel": ["radio", "RADIO"],
	"FoodStorage": ["food", "FOOD"],
	"WaterStorage": ["water", "WATER"],
	"GeneralStorage": ["storage", "STORAGE"],
	"LifeSupport": ["lifesupport", "LIFE SUPPORT"],
	"PowerPanel": ["power", "POWER"],
	"ToolsStorage": ["tools", "TOOLS"],
	"MedicalStorage": ["medkit", "MEDKIT"],
	"Checklist": ["checklist", "CHECKLIST"],
	"RestArea": ["rest", "REST"],
}
const LABELS := {
	"console": "COMMAND CONSOLE", "nav": "NAVIGATION", "radio": "RADIO", "food": "FOOD",
	"water": "WATER", "storage": "STORAGE", "lifesupport": "LIFE SUPPORT", "power": "POWER",
	"tools": "TOOLS", "medkit": "MEDKIT", "checklist": "CHECKLIST", "rest": "REST",
	"hatch": "LUNAR MODULE HATCH", "disposal": "DESCARTE",
}

@onready var cabin: Node3D = $ViewportContainer/SubViewport/SpacecraftInterior

var player: CharacterBody3D
var hud: CanvasLayer
var target_id := ""
var tutorial_step := -1
var _labels := {}
var _markers := {}
var _alarm_time := 0.0
var _alarm_light: OmniLight3D
var _alarm_voice: AudioStreamPlayer
var _moon: MeshInstance3D
var _earth: MeshInstance3D
var _interacted := false
var held := ""
var _held_token := 0
var _loose_objects: Dictionary = {}
var _held_node: Node3D
var _held_time := 0.0
var eating := false
var _eat_time := 0.0
var _eat_done := false

var TUTORIAL := [
	["Mova o MOUSE para olhar ao redor.",
		"Apollo, Houston. Docking confirmed, welcome to translunar coast. Take a look around.",
		"Apollo, aqui é Houston. Acoplamento confirmado, bem-vindos à viagem translunar. Deem uma olhada ao redor.", "tutorial_look"],
	["Pressione ESPAÇO para soltar o cinto e flutuar.",
		"You are clear to unstrap. Watch your step, there is no floor up there.",
		"Podem soltar os cintos. Cuidado: aí em cima não existe chão.", "tutorial_unstrap"],
	["Encostado numa superfície, ESPAÇO empurra você na direção do olhar e WASD dá impulsos curtos. No ar, você segue reto até tocar outra superfície.",
		"Move slowly. In zero g, everything keeps drifting until you stop it.",
		"Movam-se devagar. Sem gravidade, tudo continua flutuando até ser parado.", "tutorial_drift"],
	["Pressione TAB para abrir o checklist da missão.",
		"Your checklist has today's tasks. Check it any time.",
		"O checklist tem as tarefas do dia. Consultem quando quiserem.", "tutorial_checklist"],
	["Mire no painel LIFE SUPPORT (direita, embaixo) e pressione E.",
		"First item: swap the lithium hydroxide canister at LIFE SUPPORT.",
		"Primeiro item: trocar o cartucho de hidróxido de lítio no LIFE SUPPORT.", "tutorial_life_support"],
	["Consuma uma cota de comida e uma de água por dia. Cada salto também gasta suprimentos. Na partida para a Terra, guarde três de cada.",
		"One ration of food and one of water every day. Each phase change uses supplies too. Keep three of each for the trip home.",
		"Uma cota de comida e uma de água por dia. Cada salto também gasta suprimentos. Guardem três de cada para a volta.", ""],
]


func _ready() -> void:
	Sound.enter_scene("cabin")
	var preview := cabin.get_node_or_null("PreviewPlayer")
	if preview:
		cabin.remove_child(preview)
		preview.queue_free()
	_build_interaction_zones()
	_build_hatch_barrier()
	_build_backdrop()
	MissionState.changed.connect(_update_supplies)
	_update_supplies()
	player = CharacterBody3D.new()
	player.set_script(PLAYER_SCRIPT)
	cabin.add_child(player)
	player.setup(cabin)
	player.unbuckled.connect(_refresh_objective)
	hud = CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	add_child(hud)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if MissionState.day == 1 and MissionState.tasks_done.is_empty():
		_set_tutorial(0)
	else:
		_start_day_briefing()
	_refresh_objective()
	_build_science_cargo()
	_restore_supplies()


# ---------- Construção ----------

func _build_interaction_zones() -> void:
	var slots := cabin.get_node("EquipmentSlots")
	for slot_name in STATIONS:
		var marker: Node3D = slots.get_node_or_null(slot_name)
		if marker == null:
			continue
		var size: Vector3 = marker.get_meta("max_size_m", Vector3(0.5, 0.5, 0.4))
		_add_zone(marker, STATIONS[slot_name][0], STATIONS[slot_name][1], size)
	var disposal := Marker3D.new()
	disposal.name = "MealDisposal"
	cabin.add_child(disposal)
	disposal.position = Vector3(-1.17, 0.88, 1.66)
	_add_zone(disposal, "disposal", LABELS["disposal"], Vector3(0.36, 0.28, 0.30))
	_add_station_prop(disposal, Vector3(0.30, 0.20, 0.22), Vector3(0, 0.10, 0.05), Color("#405b65"))
	_add_station_prop(disposal, Vector3(0.32, 0.04, 0.23), Vector3(0, 0.22, 0.05), Color("#869da0"))
	var bench: Node3D = slots.get_node_or_null("ToolsStorage")
	if bench != null:
		_add_station_prop(bench, Vector3(0.36, 0.055, 0.24), Vector3(0, 0.38, 0), Color("#718489"))
	var restraint: Node3D = slots.get_node_or_null("RestArea")
	if restraint != null:
		_add_station_prop(restraint, Vector3(1.55, 0.16, 0.34), Vector3(0, 0.12, 0.04), Color("#38525a"))
		for x in [-0.5, 0.48]:
			_add_station_prop(restraint, Vector3(0.068, 0.025, 0.34), Vector3(x, 0.21, 0.04), Color("#9c8b69"))
	var hatch := Marker3D.new()
	hatch.name = "HatchInteraction"
	cabin.add_child(hatch)
	var anchor: Node3D = cabin.get_node("CabinStructure/HatchOpening/DockingAnchor")
	hatch.global_position = anchor.global_position - Vector3(0, 0.75, 0)
	# A zona vai até o teto (Y=2,60): encostado na escotilha, o olho fica dentro dela.
	_add_zone(hatch, "hatch", "LUNAR MODULE HATCH", Vector3(0.8, 2.6 - hatch.global_position.y, 0.9))


## O vão da escotilha fica aberto na cena para o acoplamento futuro. Em microgravidade,
## o jogador subiria por ele e sairia da nave: este tampão invisível na base do colar
## bloqueia só o jogador (camada BARRIER_LAYER), sem afetar raios de interação.
func _build_hatch_barrier() -> void:
	var barrier := StaticBody3D.new()
	barrier.name = "HatchBarrier"
	barrier.collision_layer = PLAYER_SCRIPT.BARRIER_LAYER
	barrier.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 0.1, 1.2)
	shape.shape = box
	barrier.add_child(shape)
	var anchor: Node3D = cabin.get_node("CabinStructure/HatchOpening/DockingAnchor")
	cabin.get_node("CabinStructure/HatchOpening").add_child(barrier)
	barrier.global_position = Vector3(anchor.global_position.x, 2.65, anchor.global_position.z)


func _add_zone(marker: Node3D, id: String, text: String, size: Vector3) -> void:
	size = Vector3(maxf(size.x, 0.3), maxf(size.y, 0.3), maxf(size.z, 0.25))
	marker.set_meta("interact_id", id)
	var body := StaticBody3D.new()
	body.name = "InteractionZone"
	body.collision_layer = INTERACT_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	marker.add_child(body)
	var label := Label3D.new()
	label.text = text
	var important := id in ["food", "water", "rest"]
	label.font_size = 64 if important else 40
	label.pixel_size = 0.0028 if important else 0.0024
	label.modulate = Color(1, 0.85, 0.45) if important else Color(0.85, 0.82, 0.72, 0.75)
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position = Vector3(0, size.y + 0.07, 0) if id != "hatch" else Vector3(0, -0.05, 0)
	if id == "food":
		label.position = Vector3(0, 0.56, 0)
	marker.add_child(label)
	_labels[id] = label
	var mark := Label3D.new()
	mark.text = "!"
	mark.font_size = 80
	mark.pixel_size = 0.002
	mark.outline_size = 14
	mark.modulate = Color("#ffd77b")
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.position = label.position + Vector3(0, 0.20, 0)
	marker.add_child(mark)
	_markers[id] = mark


func _add_station_prop(parent: Node3D, size: Vector3, offset: Vector3, color: Color) -> void:
	var model := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	box.material = material
	model.mesh = box
	model.position = offset
	parent.add_child(model)


func _build_backdrop() -> void:
	var backdrop: Node3D = cabin.get_node("ExteriorBackdrop")
	_moon = _sphere(Color(0.72, 0.71, 0.68), 1.0)
	_moon.position = Vector3(0, 1.29, -120)
	backdrop.add_child(_moon)
	_earth = _sphere(Color(0.25, 0.45, 0.85), 1.0)
	_earth.position = Vector3(-120, 1.29, 0)
	backdrop.add_child(_earth)
	var stars := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := BoxMesh.new()
	quad.size = Vector3(0.35, 0.35, 0.35)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	mm.mesh = quad
	mm.instance_count = 400
	var rng := RandomNumberGenerator.new()
	rng.seed = 69
	for i in mm.instance_count:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		mm.set_instance_transform(i, Transform3D(Basis(), dir * 160.0))
	stars.multimesh = mm
	backdrop.add_child(stars)
	_update_backdrop()


func _update_supplies() -> void:
	var ms := MissionState
	_show_supplies("FoodStorage/FoodRack/Packs", floorf(ms.available_supply("food") + 0.0001))
	_show_supplies("WaterStorage/WaterRack/Pouches", floorf(ms.available_supply("water") + 0.0001))
	if _labels.has("food"):
		_labels["food"].text = "FOOD · %s" % ms.amount_text(ms.food_days)
		_labels["water"].text = "WATER · %s" % ms.amount_text(ms.water_days)


func _hold(id: String, existing := 0) -> void:
	_held_token = existing if existing > 0 else MissionState.reserve_supply(id)
	if _held_token == 0:
		hud.show_note("Recolha a cota solta antes de retirar outra.")
		return
	held = id
	_eat_done = false
	eating = false
	var slot := "FoodStorage" if id == "food" else "WaterStorage"
	var marker: Node3D = cabin.get_node_or_null("EquipmentSlots/" + slot)
	if marker != null:
		Sound.play_at(id, marker)
	var key := id
	if id == "food":
		key = "food_odd" if MissionState.day % 2 == 1 else "food_even"
	if ResourceLoader.exists(HELD_MODELS[key]):
		_held_node = load(HELD_MODELS[key]).instantiate()
		player.camera.add_child(_held_node)
		_held_node.position = Vector3(0.13, -0.09, -0.3)
		_held_node.rotation = Vector3(0.1, -0.3, 0.05)
	_held_time = 0.0
	_update_supplies()


func _consume() -> void:
	if eating or held == "":
		return
	eating = true
	_eat_time = 0.0
	_eat_done = false
	Sound.play_cue(held)


func _put_back() -> void:
	if held == "" or _eat_done:
		return
	var id := held
	_drop_item()
	hud.show_note("%s devolvida ao compartimento. Nenhuma cota foi gasta." % ("Ração" if id == "food" else "Bolsa de água"))


func _drop_item() -> void:
	MissionState.supply_tokens.erase(_held_token)
	_held_token = 0
	held = ""
	eating = false
	_eat_done = false
	if _held_node != null:
		_held_node.queue_free()
		_held_node = null
	_update_supplies()


func _eat_marker() -> void:
	var ms := MissionState
	var id := held
	_eat_done = true
	if not ms.consume_supply_token(_held_token):
		_drop_item()
		hud.show_note("Não há uma cota inteira de %s. Saldo: %s." % ["comida" if id == "food" else "água", ms.amount_text(ms.stock(id))], 4.0)
		return
	_update_supplies()


func _finish_eating() -> void:
	var ms := MissionState
	var id := held
	_drop_item()
	var noun := "Ração consumida" if id == "food" else "Água consumida"
	hud.show_note("%s · hoje: %d · saldo: %s %s" % [noun, ms.intake_on(ms.day, id), ms.amount_text(ms.stock(id)), "comida" if id == "food" else "água"])


func _show_supplies(path: String, days: float) -> void:
	var group := cabin.get_node_or_null("EquipmentSlots/" + path)
	if group == null:
		return
	var total := group.get_child_count()
	var left := mini(ceili(days), total)
	for i in total:
		group.get_child(i).visible = i >= total - left


func _sphere(color: Color, radius: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _update_backdrop() -> void:
	var d := clampi(MissionState.day - 1, 0, 4)
	_moon.scale = Vector3.ONE * [2.0, 3.5, 9.0, 4.0, 2.2][d]
	_earth.scale = Vector3.ONE * [10.0, 6.0, 3.5, 6.0, 12.0][d]


# ---------- Tarefas ----------

func day_tasks() -> Array:
	var ms := MissionState
	var list := []
	match ms.day:
		1:
			list = [["lifesupport", "Trocar o cartucho de LiOH (remove o CO₂)"],
				["nav", "Verificar a trajetória de ida"],
				["rest", "Descansar e encerrar o dia"]]
		2:
			list = [["power", "Resolver o alerta de energia"],
				["radio", "Enviar o relatório diário a Houston"],
				["rest", "Descansar e encerrar o dia"]]
			if ms.random_event == "ptc":
				list.insert(1, ["console", "Resolver o controle térmico da nave"])
			if ms.random_event == "water_leak":
				list.insert(1, ["water", "Vazamento no reservatório de água"])
		3:
			list = [["console", "Checklist de aproximação lunar"],
				["hatch", "Entrar no módulo lunar"]]
		4:
			list = [["nav", "Corrigir a rota rumo à Terra"],
				["lifesupport", "Trocar o cartucho de LiOH (remove o CO₂)"],
				["rest", "Descansar e encerrar o dia"]]
		_:
			list = [["radio", "Falha no rádio: restabelecer contato" if ms.random_event == "comm_dropout" else "Enviar o status da cápsula para a reentrada"],
				["console", "Preparar reentrada"]]
	var result := []
	for entry in list:
		result.append({"id": entry[0], "station": LABELS[entry[0]], "text": entry[1], "done": _done(entry[0])})
	for id: String in MissionState.CABIN_MINIGAMES:
		var task: Dictionary = MissionState.CABIN_MINIGAMES[id]
		if task["day"] == ms.day:
			result.append({"id": id, "station": LABELS[task["station"]], "text": task["title"],
				"done": ms.minigame_completions.has(id), "optional": true})
	return result


func _key(id: String) -> String:
	return "%d:%s" % [MissionState.day, id]


func _done(id: String) -> bool:
	return MissionState.tasks_done.has(_key(id))


func _complete(id: String) -> void:
	MissionState.tasks_done[_key(id)] = true
	MissionState.changed.emit()
	if hud.checklist_visible():
		hud.show_checklist(day_tasks())
	_refresh_objective()


func _has_task(id: String) -> bool:
	for task in day_tasks():
		if task["id"] == id:
			return true
	return false


func _pending(except_id := "") -> Array:
	var missing := []
	for task in day_tasks():
		if not task["done"] and task["id"] != except_id and not task.get("optional", false):
			missing.append(task)
	return missing


func _refresh_objective() -> void:
	if hud == null:
		return
	var title := "DIA %d DE %d · %s" % [MissionState.day, MissionState.PLAY_DAYS, MissionState.phase_title()]
	if player.seated:
		hud.set_objective(title, "Solte o cinto com ESPAÇO.")
		return
	var pending := _pending()
	if pending.is_empty():
		hud.set_objective(title, "Tudo pronto.")
	else:
		hud.set_objective(title, "Próximo: %s — %s" % [pending[0]["station"], pending[0]["text"]])


func _set_tutorial(step: int) -> void:
	tutorial_step = step
	if step < 0 or step >= TUTORIAL.size():
		tutorial_step = -1
		hud.set_tutorial("")
		return
	hud.set_tutorial("TUTORIAL %d/%d · %s\n(ENTER pula a dica)" % [step + 1, TUTORIAL.size(), TUTORIAL[step][0]])
	Houston.say_recorded(TUTORIAL[step][3], TUTORIAL[step][1], TUTORIAL[step][2])


func _check_tutorial() -> void:
	if tutorial_step < 0:
		return
	var passed := false
	match tutorial_step:
		0: passed = player.look_amount > 260.0
		1: passed = not player.seated
		2: passed = player.moved_distance > 1.2
		3: passed = hud.checklist_visible()
		4: passed = _done("lifesupport")
		5: passed = MissionState.intake_on(1, "food") > 0 and MissionState.intake_on(1, "water") > 0
	if passed:
		_set_tutorial(tutorial_step + 1)
		if tutorial_step == -1:
			Houston.say_recorded("tutorial_complete", "Nice work. Follow the checklist and keep an eye on your supplies.",
				"Bom trabalho. Sigam o checklist e fiquem de olho nos suprimentos.")


func _start_day_briefing() -> void:
	match MissionState.day:
		1:
			Houston.say_recorded("day_one_checklist", "Apollo, Houston. Follow today's checklist.", "Apollo, aqui é Houston. Sigam o checklist de hoje.")
		2:
			Houston.say_recorded("day_two_power", "Good morning, Apollo. We see a power problem on your main bus. Check the POWER panel.",
				"Bom dia, Apollo. Vemos um problema de energia no barramento principal. Verifiquem o painel POWER.")
			match MissionState.random_event:
				"water_leak":
					Houston.say_recorded("day_two_water", "We also show a pressure drop in the water system. Take a look at WATER.",
						"Também vemos queda de pressão no sistema de água. Verifiquem o WATER.")
				"ptc":
					Houston.say_recorded("day_two_thermal", "Thermal readings are uneven. Check the COMMAND CONSOLE.",
						"As leituras térmicas estão desiguais. Verifiquem o COMMAND CONSOLE.")
		3:
			Houston.say_recorded("day_three_approach", "Apollo, the Moon is close. Run the approach checklist on the COMMAND CONSOLE.",
				"Apollo, a Lua está próxima. Executem o checklist de aproximação no COMMAND CONSOLE.")
		4:
			Houston.say("Columbia, Houston. Good burn, you are on your way home. Check your course at NAVIGATION.",
				"Columbia, aqui é Houston. Boa queima, vocês estão a caminho de casa. Verifiquem a rota no NAVIGATION.")
		5:
			if MissionState.random_event == "comm_dropout":
				Houston.say_recorded("day_two_radio", "Your signal is breaking up... high gain antenna... check RADIO...",
					"Seu sinal está falhando... antena de alto ganho... verifiquem o RADIO...")
			else:
				Houston.say("Columbia, Houston. Last day. Send us your status on the RADIO, then prepare for entry.",
					"Columbia, aqui é Houston. Último dia. Enviem o status pelo RADIO e preparem a reentrada.")


# ---------- Interação ----------

func _process(delta: float) -> void:
	if not hud.modal_open() and not player.frozen and tutorial_step < 0:
		MissionState.advance_survival(delta)
		hud.refresh_status()
		if MissionState.ended.get("stage", "") == "survival":
			player.frozen = true
			_drop_item()
			_modal("GAME OVER · MISSÃO FALHOU", MissionState.ended["reason"], ["VER RELATÓRIO"], func(_i): Game.finish_mission())
			return
	_update_alarm(delta)
	_update_markers()
	_save_loose_supplies()
	_check_tutorial()
	if _held_node != null and not eating:
		_held_time += delta
		_held_node.position = HAND_POS + Vector3(0, sin(_held_time * 2.0) * 0.006, 0)
	if eating:
		_eat_time += delta
		var reach := clampf(minf(_eat_time / 0.6, (EAT_TIME - _eat_time) / 0.5), 0.0, 1.0)
		if _held_node != null:
			var chew := sin(_eat_time * 14.0) * 0.008 * reach
			_held_node.position = HAND_POS.lerp(MOUTH_POS, reach) + Vector3(0, chew, 0)
			_held_node.rotation = Vector3(0.1 + reach * 0.8, -0.3, 0.05)
	player.hand_busy = _held_node != null
	if _held_node != null:
		player.right_hand.position = _held_node.position + Vector3(0.03, -0.05, 0.06)
		player.right_hand.rotation = Vector3(_held_node.rotation.x * 0.6, 0, 0)
	if eating:
		if not _eat_done and _eat_time >= EAT_MARK:
			_eat_marker()
		elif _eat_done and _eat_time >= EAT_TIME:
			_finish_eating()


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var new_target := ""
	if not player.seated and not hud.modal_open():
		var cam: Camera3D = player.camera
		var from := cam.global_position
		var query := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * REACH)
		query.collision_mask = 1 | INTERACT_LAYER
		query.exclude = [player.get_rid()]
		var space := cabin.get_world_3d().direct_space_state
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			new_target = _resolve_id(hit["collider"])
		else:
			# Olhando para o vazio com a cabeça dentro de uma zona (ex.: encostado na
			# escotilha, olhando para o vão aberto), a estação dessa zona continua alvo.
			var point := PhysicsPointQueryParameters3D.new()
			point.position = from
			point.collision_mask = INTERACT_LAYER
			for inside in space.intersect_point(point, 1):
				new_target = _resolve_id(inside["collider"])
	if new_target != target_id:
		if _labels.has(target_id):
			_labels[target_id].modulate.a = 0.75 if not target_id in ["food", "water"] else 1.0
			_labels[target_id].outline_modulate = Color.BLACK
		target_id = new_target
		if _labels.has(target_id):
			_labels[target_id].modulate.a = 1.0
			_labels[target_id].outline_modulate = Color(0.5, 0.3, 0.0)
	if player.seated:
		hud.set_prompt("[ESPAÇO] Soltar o cinto")
	elif eating:
		hud.set_prompt("Comendo..." if held == "food" else "Bebendo...")
	elif held != "":
		hud.set_prompt(("[E] Comer a ração" if held == "food" else "[E] Beber a água") + " · [Q] Devolver · [G] Soltar")
	elif target_id != "":
		var task_id := _station_minigame(target_id)
		var prompt := "[E] " + str(LABELS.get(target_id, "RECOLHER"))
		if target_id == "water" and _has_task("water") and not _done("water"):
			prompt += " · [F] Resolver vazamento"
		if not task_id.is_empty():
			var title: String = MissionState.CABIN_MINIGAMES[task_id]["title"]
			var status := " · Concluída" if MissionState.minigame_completions.has(task_id) else ""
			var station := "" if target_id == "disposal" else prompt + "\n"
			prompt = station + "[F] " + title + status
		hud.set_prompt(prompt)
	elif player.needs_help():
		hud.set_prompt("[ESPAÇO] Puxar a cinta de apoio mais próxima")
	else:
		hud.set_prompt("")


## Sobe na hierarquia até achar o marcador com "interact_id".
## Assim, colisões dos modelos futuros também respondem à interação.
func _resolve_id(node: Node) -> String:
	while node != null and node != cabin:
		if node.has_meta("interact_id"):
			return node.get_meta("interact_id")
		node = node.get_parent()
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("drop_supply") and not hud.modal_open() and not eating and held != "":
		_release_supply()
		return
	if hud.modal_open() or hud.paused():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.look(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("move_up") and player.seated:
		player.unbuckle()
	elif event.is_action_pressed("put_back") and held != "" and not eating:
		_put_back()
	elif event.is_action_pressed("checklist"):
		hud.toggle_checklist(day_tasks())
	elif event.is_action_pressed("advance") and tutorial_step >= 0 and not Houston.is_busy():
		_set_tutorial(tutorial_step + 1)
	elif event.is_action_pressed("cabin_task") and not event.is_echo() and not player.seated and held.is_empty():
		if target_id == "water" and _has_task("water") and not _done("water"):
			_decision("water_leak", "water")
			get_viewport().set_input_as_handled()
			return
		var task_id := _station_minigame(target_id)
		if not task_id.is_empty():
			_interact_minigame(task_id)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and (target_id != "" or held != ""):
		interact(target_id)


func _modal(title: String, body: String, buttons := ["OK"], callback := Callable()) -> void:
	player.frozen = true
	hud.show_modal(title, body, buttons, func(i):
		player.frozen = false
		if callback.is_valid():
			callback.call(i))


func _decision(id: String, task_id: String, after := Callable()) -> void:
	var d := MissionDecisions.get_decision(id)
	Sound.play_cue("radio" if id in ["midcourse", "return_course"] else "warning", "Voice", true)
	_modal(d["title"], d["body"], d["options"], func(choice):
		if id in ["midcourse", "return_course"] and choice == 0:
			_open_trajectory(d, task_id, after, id)
		elif id == "comm_dropout" and choice == 0 and not MissionState.minigame_completions.has("M03"):
			_open_cabin_minigame("M03", func(recovered: bool):
				_decision_result(id, task_id, d, choice, 0 if recovered else 1, after))
		else:
			_decision_result(id, task_id, d, choice, 0, after))


func _station_minigame(station: String) -> String:
	for id: String in MissionState.CABIN_MINIGAMES:
		var task: Dictionary = MissionState.CABIN_MINIGAMES[id]
		if task["day"] == MissionState.day and task["station"] == station:
			return id
	return ""


func _interact_minigame(id: String) -> void:
	if id == "M03" and MissionState.random_event == "comm_dropout" and _has_task("radio") and not _done("radio"):
		_decision("comm_dropout", "radio")
	else:
		_open_cabin_minigame(id)


func _open_cabin_minigame(id: String, after := Callable()) -> void:
	if hud.modal_open() or hud.paused() or not MissionState.CABIN_MINIGAMES.has(id):
		return
	var task: Dictionary = MissionState.CABIN_MINIGAMES[id]
	if task["day"] != MissionState.day:
		return
	var complete: Dictionary = MissionState.minigame_completions.get(id, {})
	if not complete.is_empty():
		_modal(complete["title"], complete["message"])
		return
	var texto: Dictionary = BRIEFINGS.TEXTOS[id]
	var titulo := "%s · %s" % [LABELS[task["station"]], task["title"].to_upper()]
	_modal(titulo, texto["instrucoes"], ["COMEÇAR", "AGORA NÃO"], func(choice):
		if choice == 0:
			_start_cabin_minigame(id, after)
		elif after.is_valid():
			after.call(false))
	Houston.say(texto["fala_en"], texto["fala_pt"])


func _start_cabin_minigame(id: String, after := Callable()) -> void:
	var task: Dictionary = MissionState.CABIN_MINIGAMES[id]
	var scene := load(task["scene"]) as PackedScene
	var minigame: Control = scene.instantiate()
	var attempt := MissionState.next_minigame_attempt(id)
	minigame.nivel = ["easy", "normal", "hard"].find(MissionState.difficulty)
	minigame.folga = attempt - 1
	player.frozen = true
	minigame.terminou.connect(func(played_well: bool):
		if hud.minigame != minigame:
			return
		hud.close_minigame()
		_finish_cabin_minigame(id, attempt, played_well, after), CONNECT_ONE_SHOT)
	hud.open_minigame(minigame, func(): player.frozen = false)
	Sound.play_cue("switch")


func _finish_cabin_minigame(id: String, attempt: int, played_well: bool, after: Callable) -> void:
	var result := MissionState.resolve_minigame_attempt(id, attempt, played_well)
	if hud.checklist_visible():
		hud.show_checklist(day_tasks())
	_refresh_objective()
	var completed: bool = result["completed"]
	var cue := "warning"
	if completed:
		cue = "assist" if result["assisted"] else "success"
	Sound.play_cue(cue, "Interface")
	if completed:
		_modal(result["title"], BRIEFINGS.com_licao(id, result["message"]), ["CONTINUAR"], func(_i):
			if after.is_valid():
				after.call(true))
	else:
		var exit_label := "CONTINUAR SEM RESTABELECER O SINAL" if after.is_valid() else "VOLTAR À CABINE"
		_modal(result["title"], result["message"], ["TENTAR DE NOVO", exit_label], func(choice):
			if choice == 0:
				_start_cabin_minigame(id, after)
			elif after.is_valid():
				after.call(false))


func _open_trajectory(d: Dictionary, task_id: String, after: Callable, decision_id := "return_course") -> void:
	player.frozen = true
	var minigame: Control = TRAJECTORY_SCENE.instantiate()
	minigame.tolerancia = MissionState.settings()["traj_tol"]
	minigame.destino = "terra" if decision_id == "return_course" else "lua"
	minigame.terminou.connect(func(errors):
		if hud.minigame != minigame:
			return
		hud.close_minigame()
		player.frozen = false
		_decision_result(decision_id, task_id, d, 0, errors, after), CONNECT_ONE_SHOT)
	hud.open_minigame(minigame, func(): player.frozen = false)
	Houston.say_recorded("trajectory_correction", "Apollo, Houston. Fly the correction by hand. Keep her on the line.",
		"Apollo, aqui é Houston. Façam a correção manualmente. Mantenham a nave na linha.")


func _decision_result(id: String, task_id: String, d: Dictionary, choice: int, errors: int, after: Callable) -> void:
	var result := MissionDecisions.apply(id, choice, errors)
	if not result["correct"]:
		_start_alarm()
	var verdict := "[color=#77ee77]BOA ESCOLHA[/color]" if result["correct"] else "[color=#ff8866]ESCOLHA ARRISCADA[/color]"
	if result["correct"] and not result["favorable"]:
		verdict += " · [color=#ffcc44]COMPLICAÇÃO[/color]"
	elif not result["correct"] and result["favorable"]:
		verdict += " · [color=#ffcc44]DEU SORTE[/color]"
	if id in ["midcourse", "return_course"] and choice == 0:
		verdict += " · " + ("[color=#77ee77]PILOTAGEM PRECISA[/color]" if errors <= 1 else "[color=#ff8866]PILOTAGEM IMPRECISA[/color]")
	MissionState.add_event(id, d["title"], d["options"][choice])
	_complete(task_id)
	_modal(d["title"], "%s\n\n%s" % [verdict, result["explanation"]], ["CONTINUAR"], func(_i):
		if after.is_valid():
			after.call())


func interact(id: String) -> void:
	if id.begins_with("supply_") and held == "":
		_collect_supply(int(id.trim_prefix("supply_")))
		return
	var ms := MissionState
	_interacted = true
	if held != "":
		_consume()
		return
	match id:
		"food", "water":
			if not ms.can_consume(id):
				hud.show_note("Compartimento vazio: não há uma cota inteira de %s (saldo %s)." % ["comida" if id == "food" else "água", ms.amount_text(ms.stock(id))], 4.0)
				return
			_hold(id)
		"lifesupport":
			var info := "Oxigênio da cabine: [b]%.0f%%[/b] do nominal\nPressão da cabine: cerca de 5 psi de oxigênio puro, como no módulo de comando Apollo\nRemoção de CO₂: cartuchos de hidróxido de lítio (LiOH)" % ms.life_support
			if _has_task("lifesupport") and not _done("lifesupport"):
				_open_cartridge()
			else:
				_modal("LIFE SUPPORT", info)
		"nav":
			if _has_task("nav") and not _done("nav"):
				_decision("midcourse" if ms.day == 1 else "return_course", "nav")
			else:
				var leg := "Rota de ida" if ms.phase == "outbound" else "Rota de volta"
				var err := ms.trajectory_error if ms.phase == "outbound" else ms.return_error
				_modal("NAVIGATION", "%s: desvio de [b]%.0f%%[/b] (tolerância %.0f%%)\nPropelente do CSM: [b]%.0f%%[/b]" % [leg, err * 100.0, MissionDecisions.SMALL_ERROR * 100.0, ms.sps_fuel])
		"power":
			if _has_task("power") and not _done("power"):
				_decision("power", "power")
			else:
				var list := ""
				for item_id in ms.instruments_active:
					list += "• %s: %.0f W\n" % [ms.items[item_id]["name"], ms.items[item_id]["power"]]
				_modal("POWER", "Consumo dos instrumentos: [b]%.0f W[/b] de [b]%.0f W[/b]\n%s\nBateria auxiliar: %s" % [ms.power_use(), ms.power_capacity, list, "não levada" if ms.qty("battery_pack") == 0 else ("já utilizada" if ms.battery_used else "disponível")])
		"radio":
			if _has_task("radio") and not _done("radio"):
				if ms.day == 5 and ms.random_event == "comm_dropout":
					_decision("comm_dropout", "radio")
				else:
					_complete("radio")
					Houston.say_recorded("status_received", "Thanks for the update, Apollo. Everything looks good from here.",
						"Obrigado pela atualização, Apollo. Tudo certo por aqui.")
					var report := "Relatório enviado: suprimentos, energia e estado da tripulação.\nHouston acompanha a missão em tempo real e ajuda a planejar cada manobra."
					if ms.day == 5:
						report = "Status da cápsula enviado: suprimentos, energia, ângulo de reentrada e estado da tripulação.\nHouston confirma os dados para a reentrada."
					_modal("RADIO", report)
			else:
				_modal("RADIO", "Canal com Houston aberto. A comunicação é a principal fonte de dados de navegação e alertas.")
		"console":
			if ms.day == 2 and _has_task("console") and not _done("console"):
				_decision("ptc", "console")
			elif ms.day == 3 and not _done("console"):
				_approach_checklist()
			elif ms.day == 5:
				if _has_task("radio") and not _done("radio"):
					_modal("COMMAND CONSOLE", "Antes de preparar a reentrada, envie o status da cápsula pelo RADIO.")
				else:
					Game.open_transition("C")
			else:
				_modal("COMMAND CONSOLE", "Painel principal de comando. Nenhum procedimento pendente aqui.")
		"hatch":
			if ms.phase == "return":
				_modal("LUNAR MODULE HATCH", "O túnel está fechado. O estágio de ascensão do Eagle foi descartado depois do reencontro, e a base do módulo lunar ficou na Lua.")
			elif ms.day < 3:
				_modal("LUNAR MODULE HATCH", "O túnel para o módulo lunar só é aberto na órbita da Lua (dia 3).")
			elif not _done("console"):
				_modal("LUNAR MODULE HATCH", "Complete primeiro o checklist de aproximação no COMMAND CONSOLE.")
			else:
				var missing := _pending("hatch")
				var warn := "" if missing.is_empty() else "\n\n[color=#ffcc44]Tarefas pendentes serão ignoradas: %s.[/color]" % ", ".join(PackedStringArray(missing.map(func(t): return t["station"])))
				_modal("LUNAR MODULE HATCH", "Abrir o túnel e seguir para a preparação da descida?\nNa próxima tela você vê o custo de suprimentos antes de confirmar." + warn, ["ABRIR O TÚNEL", "AINDA NÃO"], func(i):
					if i == 0:
						Sound.play_cue("hatch", "Interface")
						Game.enter_lunar_module())
		"rest":
			if not _has_task("rest"):
				_modal("REST", "Hoje não há descanso: a próxima etapa da missão começa ao fim deste dia.")
				return
			var missing := _pending("rest")
			if not missing.is_empty():
				var text := "Antes de descansar, conclua:\n"
				for t in missing:
					text += "• %s — %s\n" % [t["station"], t["text"]]
				_modal("REST", text)
				return
			var rest_note := ""
			if ms.day == 2 and not ms.minigame_completions.has("M05"):
				rest_note = "\n\nA preparação das coberturas ficará pendente. Use F na estação para fazê-la antes de descansar."
			_modal("REST", "Encerrar o dia %d e descansar?" % ms.day + rest_note, ["DESCANSAR", "AINDA NÃO"], func(i):
				if i == 0:
					_begin_rest())
		"disposal":
			var text := "Bolsa para guardar as embalagens antes de sair da cabine."
			if ms.day == 3:
				text += "\nUse F aqui para iniciar a tarefa."
			_modal("DESCARTE", text)
		"checklist":
			if not hud.checklist_visible():
				hud.toggle_checklist(day_tasks())
		"tools":
			_modal("TOOLS", "Kit de peças e ferramentas: %s.\nFerramentas permitem reparos mais rápidos em eventos." % ("a bordo" if ms.spare_parts else "não trazido no planejamento"))
		"medkit":
			_modal("MEDKIT", "Materiais médicos da tripulação. Todos estão bem.")
		"storage":
			var lines := ""
			for item_id in ms.instruments_active:
				lines += "• " + ms.items[item_id]["name"] + "\n"
			_modal("STORAGE", "Instrumentos científicos embarcados (seguem no módulo lunar):\n" + (lines if lines != "" else "nenhum"))


func _approach_checklist() -> void:
	var ms := MissionState
	var loi := 30.0
	var checks := [
		["Energia", ms.power_use() <= ms.power_capacity or ms.battery_used or ms.science_multiplier < 1.0, "%.0f/%.0f W" % [ms.power_use(), ms.power_capacity]],
		["Propelente do CSM", ms.sps_fuel >= loi + 20.0, "%.0f%% (inserção em órbita: %.0f%%)" % [ms.sps_fuel, loi]],
		["Navegação", ms.trajectory_error < MissionDecisions.SMALL_ERROR, "desvio de %.0f%% (tolerância %.0f%%)" % [ms.trajectory_error * 100.0, MissionDecisions.SMALL_ERROR * 100.0]],
		["Sistemas", ms.integrity >= 70.0, "integridade %.0f%%" % ms.integrity],
		["Módulo lunar", true, "propelente de descida: %.0f s" % ms.lm_fuel],
	]
	var text := ""
	for check in checks:
		text += "%s %s: %s\n" % ["[color=#77ee77]OK[/color]" if check[1] else "[color=#ffcc44]ATENÇÃO[/color]", check[0], check[2]]
	text += "\nConfirmar a inserção em órbita lunar? O motor do CSM vai frear a nave para que a Lua a capture."
	_modal("CHECKLIST DE APROXIMAÇÃO", text, ["CONFIRMAR INSERÇÃO EM ÓRBITA LUNAR"], func(_i):
		if _done("console"):
			return
		ms.sps_fuel -= loi
		ms.clamp_resources()
		ms.add_event("loi", "Inserção em órbita lunar", "Propelente do CSM restante: %.0f%%" % ms.sps_fuel)
		_complete("console")
		Houston.say_recorded("lunar_orbit", "Burn complete. Welcome to lunar orbit. You are go to enter the lunar module.",
			"Queima concluída. Bem-vindos à órbita lunar. Podem entrar no módulo lunar.")
		_modal("ÓRBITA LUNAR", "A nave está em órbita da Lua.\nFlutue até a escotilha no teto (LUNAR MODULE HATCH) e pressione E."))


func _begin_rest() -> void:
	if hud.modal_open() or MissionState.sealed.has(str(MissionState.day)):
		return
	Houston.clear()
	player.frozen = true
	MissionState.seal_day(MissionState.day)
	Sound.play_cue("belt")
	var bed: Node3D = cabin.get_node_or_null("EquipmentSlots/RestArea")
	if bed != null and not player.seated:
		var tween := create_tween().set_trans(Tween.TRANS_SINE)
		var spot := bed.global_position + Vector3(0, 0.4, 0)
		var away := Vector3(spot.x - player.global_position.x, 0, spot.z - player.global_position.z)
		tween.tween_property(player, "global_position", spot + away.normalized() * -0.45, 0.8)
		tween.parallel().tween_property(player.camera, "rotation:x", -0.35, 0.8)
		tween.finished.connect(func(): player.pitch = -0.35)
		player.velocity = Vector3.ZERO
		player.grabbing = true
	hud.show_night(MissionState.day + 1, player.camera, _next_day, func(): player.frozen = false)


func _next_day() -> void:
	var ms := MissionState
	if not ms.sealed.has(str(ms.day)):
		return
	ms.sleep_penalty(ms.day)
	ms.day += 1
	ms.changed.emit()
	_update_backdrop()
	_refresh_objective()
	if hud.checklist_visible():
		hud.show_checklist(day_tasks())
	_start_day_briefing()


func _update_markers() -> void:
	for id: String in _markers:
		var task := _station_minigame(id)
		var optional: bool = task != "" and not MissionState.minigame_completions.has(task)
		var required: bool = _has_task(id) and not _done(id)
		_markers[id].visible = (required or optional) and not hud.modal_open()
		_markers[id].text = "!" if required else "! +"


func _build_science_cargo() -> void:
	var slot := Node3D.new()
	slot.name = "ScienceCargo"
	cabin.add_child(slot)
	slot.position = Vector3(1.05, 0.75, 1.4)
	var model := ""
	if MissionState.objective == "sample_kit" and MissionState.science_completed and MissionState.day >= 4:
		model = "lunar_sample_container_open"
	elif MissionState.objective == "sample_kit" and MissionState.qty("sample_kit") > 0 and MissionState.day <= 3:
		model = "lunar_sample_container_closed"
	elif MissionState.objective in ["retroreflector", "camera"] and MissionState.qty(MissionState.objective) > 0 and MissionState.day <= 3:
		model = "laser_retroreflector" if MissionState.objective == "retroreflector" else "surface_camera"
	if model != "":
		var cargo: Node3D = load("res://assets/models/science/" + model + ".glb").instantiate()
		cargo.name = "Model"
		cargo.scale = Vector3.ONE * SCIENCE_SCALE[model]
		slot.add_child(cargo)


func _open_cartridge() -> void:
	player.frozen = true
	var game := Control.new()
	game.set_script(preload("res://scripts/minigames/cartridge_minigame.gd"))
	game.completed.connect(_finish_cartridge, CONNECT_ONE_SHOT)
	hud.open_minigame(game, func(): player.frozen = false)

func _finish_cartridge() -> void:
	hud.close_minigame()
	player.frozen = false
	_complete("lifesupport")
	Houston.say_recorded("canister_changed", "Copy canister change. CO2 levels coming down.", "Cartucho substituído. Nível de CO₂ diminuindo.")


func _start_alarm() -> void:
	_alarm_time = 5.0
	if _alarm_light == null:
		_alarm_light = OmniLight3D.new()
		_alarm_light.light_color = Color(1, 0.05, 0.02)
		_alarm_light.omni_range = 5.0
		cabin.add_child(_alarm_light)
		_alarm_light.position = Vector3(0, 1.9, 0.5)
	if _alarm_voice == null:
		_alarm_voice = AudioStreamPlayer.new()
		_alarm_voice.bus = "SFX"
		_alarm_voice.volume_db = -18.0
		add_child(_alarm_voice)
		var wave := AudioStreamWAV.new()
		wave.format = AudioStreamWAV.FORMAT_16_BITS
		wave.mix_rate = 22050
		var bytes := PackedByteArray()
		bytes.resize(22050 * 5 * 2)
		for i in 22050 * 5:
			var t := float(i) / 22050.0
			var gate := 0.5 - 0.5 * cos(TAU * t)
			var sample := int(sin(TAU * 660.0 * t) * gate * 6000.0)
			bytes.encode_s16(i * 2, sample)
		wave.data = bytes
		_alarm_voice.stream = wave
	_alarm_voice.play()

func _update_alarm(delta: float) -> void:
	if _alarm_time <= 0.0:
		return
	_alarm_time = maxf(0.0, _alarm_time - delta)
	_alarm_light.light_energy = 0.8 * (0.5 - 0.5 * cos(TAU * _alarm_time)) if _alarm_time > 0 else 0.0
	if _alarm_time == 0.0:
		_alarm_voice.stop()


func _release_supply() -> void:
	if _held_token == 0 or _held_node == null:
		return
	var token := _held_token
	var entry: Dictionary = MissionState.supply_tokens[token]
	entry["state"] = "loose"
	entry["position"] = player.camera.global_position - player.camera.global_basis.z * 0.45
	entry["velocity"] = player.velocity - player.camera.global_basis.z * 0.2
	_held_token = 0
	_drop_item()
	_spawn_loose_supply(token)
	hud.show_note("Objeto solto em microgravidade. Mire nele e use E para recolher.")

func _spawn_loose_supply(token: int) -> void:
	var entry: Dictionary = MissionState.supply_tokens[token]
	var body := RigidBody3D.new()
	body.gravity_scale = 0
	body.linear_damp = 0
	body.angular_damp = 0.04
	body.collision_layer = INTERACT_LAYER
	body.collision_mask = 1 | INTERACT_LAYER | PLAYER_SCRIPT.BARRIER_LAYER
	body.continuous_cd = true
	body.set_meta("interact_id", "supply_%d" % token)
	var material := PhysicsMaterial.new()
	material.bounce = 0.2
	material.friction = 0.4
	body.physics_material_override = material
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	shape.shape = sphere
	body.add_child(shape)
	var key: String = "water" if entry["kind"] == "water" else "food_odd"
	body.add_child(load(HELD_MODELS[key]).instantiate())
	cabin.add_child(body)
	body.global_position = entry["position"]
	body.linear_velocity = entry["velocity"]
	body.angular_velocity = Vector3(0.1, 0.2, 0.1)
	_loose_objects[token] = body

func _collect_supply(token: int) -> void:
	if not _loose_objects.has(token) or not MissionState.supply_tokens.has(token):
		return
	_loose_objects[token].queue_free()
	_loose_objects.erase(token)
	MissionState.supply_tokens[token]["state"] = "held"
	_hold(MissionState.supply_tokens[token]["kind"], token)

func _restore_supplies() -> void:
	for token: int in MissionState.supply_tokens.keys():
		var entry: Dictionary = MissionState.supply_tokens[token]
		if entry["state"] == "held" and held == "":
			_hold(entry["kind"], token)
		elif entry["state"] == "loose":
			_spawn_loose_supply(token)

func _save_loose_supplies() -> void:
	for token: int in _loose_objects.keys():
		var node: RigidBody3D = _loose_objects[token]
		if not MissionState.supply_tokens.has(token) or node.global_position.length() > 8.0:
			MissionState.supply_tokens.erase(token)
			node.queue_free()
			_loose_objects.erase(token)
			hud.show_note("Cota recuperada no compartimento.")
			_update_supplies()
		else:
			MissionState.supply_tokens[token]["position"] = node.global_position
			MissionState.supply_tokens[token]["velocity"] = node.linear_velocity
