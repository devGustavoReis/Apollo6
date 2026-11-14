extends Node
## Etapa jogável da cabine: tutorial, tarefas diárias, decisões e eventos.
## A arquitetura da cabine continua em scenes/spacecraft_interior.tscn.
## Os modelos dos equipamentos podem ser instanciados como filhos dos marcadores
## de EquipmentSlots: a interação continua funcionando (ver docs/gameplay_prototype.md).

const PLAYER_SCRIPT := preload("res://scripts/player/zero_g_player.gd")
const HUD_SCRIPT := preload("res://scripts/ui/cabin_hud.gd")
const INTERACT_LAYER := 2
const REACH := 2.3

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
	"hatch": "LUNAR MODULE HATCH",
}

@onready var cabin: Node3D = $ViewportContainer/SubViewport/SpacecraftInterior

var player: CharacterBody3D
var hud: CanvasLayer
var target_id := ""
var tutorial_step := -1
var _labels := {}
var _moon: MeshInstance3D
var _earth: MeshInstance3D
var _interacted := false

var TUTORIAL := [
	["Mova o MOUSE para olhar ao redor.",
		"Apollo, Houston. Docking confirmed, welcome to translunar coast. Take a look around.",
		"Apollo, aqui é Houston. Acoplamento confirmado, bem-vindos à viagem translunar. Deem uma olhada ao redor."],
	["Pressione ESPAÇO para soltar o cinto e flutuar.",
		"You are clear to unstrap. Watch your step, there is no floor up there.",
		"Podem soltar os cintos. Cuidado: aí em cima não existe chão."],
	["WASD movem na direção do olhar. ESPAÇO sobe, CTRL desce. Solte as teclas para parar.",
		"Move slowly. In zero g, everything keeps drifting until you stop it.",
		"Movam-se devagar. Sem gravidade, tudo continua flutuando até ser parado."],
	["Pressione TAB para abrir o checklist da missão.",
		"Your checklist has today's tasks. Check it any time.",
		"O checklist tem as tarefas do dia. Consultem quando quiserem."],
	["Mire no painel LIFE SUPPORT (direita, embaixo) e pressione E.",
		"First item: swap the lithium hydroxide canister at LIFE SUPPORT.",
		"Primeiro item: trocar o cartucho de hidróxido de lítio no LIFE SUPPORT."],
]


func _ready() -> void:
	var preview := cabin.get_node_or_null("PreviewPlayer")
	if preview:
		cabin.remove_child(preview)
		preview.queue_free()
	_build_interaction_zones()
	_build_backdrop()
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


# ---------- Construção ----------

func _build_interaction_zones() -> void:
	var slots := cabin.get_node("EquipmentSlots")
	for slot_name in STATIONS:
		var marker: Node3D = slots.get_node_or_null(slot_name)
		if marker == null:
			continue
		var size: Vector3 = marker.get_meta("max_size_m", Vector3(0.5, 0.5, 0.4))
		_add_zone(marker, STATIONS[slot_name][0], STATIONS[slot_name][1], size)
	var hatch := Marker3D.new()
	hatch.name = "HatchInteraction"
	cabin.add_child(hatch)
	var anchor: Node3D = cabin.get_node("CabinStructure/HatchOpening/DockingAnchor")
	hatch.global_position = anchor.global_position - Vector3(0, 0.75, 0)
	_add_zone(hatch, "hatch", "LUNAR MODULE HATCH", Vector3(0.8, 0.4, 0.9))


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
	var important := id in ["food", "water"]
	label.font_size = 64 if important else 40
	label.pixel_size = 0.0028 if important else 0.0024
	label.modulate = Color(1, 0.85, 0.45) if important else Color(0.85, 0.82, 0.72, 0.75)
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position = Vector3(0, size.y + 0.07, 0) if id != "hatch" else Vector3(0, -0.05, 0)
	marker.add_child(label)
	_labels[id] = label


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
	## A Terra encolhe e a Lua cresce a cada dia de viagem.
	var d := MissionState.day
	_moon.scale = Vector3.ONE * [2.0, 3.5, 9.0][clampi(d - 1, 0, 2)]
	_earth.scale = Vector3.ONE * [10.0, 6.0, 3.5][clampi(d - 1, 0, 2)]


# ---------- Tarefas ----------

func day_tasks() -> Array:
	var ms := MissionState
	var list := []
	match ms.day:
		1:
			list = [["lifesupport", "Trocar o cartucho de LiOH (remove o CO₂)"],
				["nav", "Verificar a trajetória"],
				["food", "Refeição do dia"], ["water", "Água do dia"],
				["rest", "Descansar e encerrar o dia"]]
		2:
			list = [["power", "Resolver o alerta de energia"],
				["radio", "Falha no rádio: restabelecer contato" if ms.random_event == "comm_dropout" else "Enviar o relatório diário a Houston"],
				["food", "Refeição do dia"],
				["water", "Vazamento! Resolver e beber a água do dia" if ms.random_event == "water_leak" else "Água do dia"],
				["rest", "Descansar e encerrar o dia"]]
			if ms.random_event == "ptc":
				list.insert(1, ["console", "Resolver o controle térmico da nave"])
		_:
			list = [["food", "Refeição do dia"], ["water", "Água do dia"],
				["console", "Checklist de aproximação lunar"],
				["hatch", "Entrar no módulo lunar"]]
	var result := []
	for entry in list:
		result.append({"id": entry[0], "station": LABELS[entry[0]], "text": entry[1], "done": _done(entry[0])})
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
		if not task["done"] and task["id"] != except_id:
			missing.append(task)
	return missing


func _refresh_objective() -> void:
	if hud == null:
		return
	var title := "DIA %d DE %d · VIAGEM À LUA" % [MissionState.day, MissionState.TRAVEL_DAYS]
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
	Houston.say(TUTORIAL[step][1], TUTORIAL[step][2])


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
	if passed:
		_set_tutorial(tutorial_step + 1)
		if tutorial_step == -1:
			Houston.say("Nice work. Follow the checklist and keep an eye on your supplies.",
				"Bom trabalho. Sigam o checklist e fiquem de olho nos suprimentos.")


func _start_day_briefing() -> void:
	match MissionState.day:
		1:
			Houston.say("Apollo, Houston. Follow today's checklist.", "Apollo, aqui é Houston. Sigam o checklist de hoje.")
		2:
			Houston.say("Good morning, Apollo. We see a power problem on your main bus. Check the POWER panel.",
				"Bom dia, Apollo. Vemos um problema de energia no barramento principal. Verifiquem o painel POWER.")
			match MissionState.random_event:
				"comm_dropout":
					Houston.say("Your signal is breaking up... high gain antenna... check RADIO...",
						"Seu sinal está falhando... antena de alto ganho... verifiquem o RADIO...")
				"water_leak":
					Houston.say("We also show a pressure drop in the water system. Take a look at WATER.",
						"Também vemos queda de pressão no sistema de água. Verifiquem o WATER.")
				"ptc":
					Houston.say("Thermal readings are uneven. Check the COMMAND CONSOLE.",
						"As leituras térmicas estão desiguais. Verifiquem o COMMAND CONSOLE.")
		3:
			Houston.say("Apollo, the Moon is close. Run the approach checklist on the COMMAND CONSOLE.",
				"Apollo, a Lua está próxima. Executem o checklist de aproximação no COMMAND CONSOLE.")


# ---------- Interação ----------

func _process(_delta: float) -> void:
	_check_tutorial()


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
		var hit := cabin.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			new_target = _resolve_id(hit["collider"])
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
	elif target_id != "":
		hud.set_prompt("[E] " + LABELS[target_id])
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
	if hud.modal_open() or hud.paused():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.look(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("move_up") and player.seated:
		player.unbuckle()
	elif event.is_action_pressed("checklist"):
		hud.toggle_checklist(day_tasks())
	elif event.is_action_pressed("advance") and tutorial_step >= 0 and not Houston.is_busy():
		_set_tutorial(tutorial_step + 1)
	elif event.is_action_pressed("interact") and target_id != "":
		interact(target_id)


func _modal(title: String, body: String, buttons := ["OK"], callback := Callable()) -> void:
	player.frozen = true
	hud.show_modal(title, body, buttons, func(i):
		player.frozen = false
		if callback.is_valid():
			callback.call(i))


func _decision(id: String, task_id: String, after := Callable()) -> void:
	var d := MissionDecisions.get_decision(id)
	_modal(d["title"], d["body"], d["options"], func(choice):
		var result := MissionDecisions.apply(id, choice)
		var verdict := "[color=#77ee77]BOA DECISÃO[/color]" if result["correct"] else "[color=#ff8866]DECISÃO RUIM[/color]"
		MissionState.add_event(id, d["title"], d["options"][choice])
		_complete(task_id)
		_modal(d["title"], "%s\n\n%s" % [verdict, result["explanation"]], ["CONTINUAR"], func(_i):
			if after.is_valid():
				after.call()))


func interact(id: String) -> void:
	var ms := MissionState
	_interacted = true
	match id:
		"food":
			if _done("food"):
				_modal("FOOD", "A refeição de hoje já foi feita.\nReserva: [b]%.1f dias[/b]. Necessários depois de hoje: [b]%d[/b]." % [ms.food_days, ms.days_still_needed()])
				return
			ms.eat()
			_complete("food")
			var ok := ms.food_days >= ms.days_still_needed()
			_modal("FOOD · REFEIÇÃO", "A tripulação reidratou e comeu as rações do dia.\n\nReserva: [b]%.1f dias[/b] · Necessários até o fim da missão: [b]%d dias[/b]\n%s" % [
				ms.food_days, ms.days_still_needed(),
				"[color=#77ee77]Suprimento suficiente.[/color]" if ok else "[color=#ff8866]Atenção: a comida não cobre o resto da missão. Será preciso racionar.[/color]"])
		"water":
			if ms.day == 2 and ms.random_event == "water_leak" and not ms.tasks_done.has("2:leak"):
				_decision("water_leak", "leak")
				return
			if _done("water"):
				_modal("WATER", "A água de hoje já foi consumida.\nReserva: [b]%.1f dias[/b]. Necessários depois de hoje: [b]%d[/b]." % [ms.water_days, ms.days_still_needed()])
				return
			ms.drink()
			_complete("water")
			var enough := ms.water_days >= ms.days_still_needed()
			_modal("WATER · ÁGUA", "Água consumida para beber e reidratar alimentos.\n\nReserva: [b]%.1f dias[/b] · Necessários até o fim: [b]%d dias[/b]\n%s" % [
				ms.water_days, ms.days_still_needed(),
				"[color=#77ee77]Suprimento suficiente.[/color]" if enough else "[color=#ff8866]A água não cobre o resto da missão. A tripulação terá de racionar.[/color]"])
		"lifesupport":
			var info := "Oxigênio da cabine: [b]%.0f%%[/b] do nominal\nPressão da cabine: cerca de 5 psi de oxigênio puro, como no módulo de comando Apollo\nRemoção de CO₂: cartuchos de hidróxido de lítio (LiOH)" % ms.life_support
			if _has_task("lifesupport") and not _done("lifesupport"):
				_modal("LIFE SUPPORT", info + "\n\nO cartucho de LiOH está saturado de CO₂. Trocar agora?", ["TROCAR CARTUCHO"], func(_i):
					_complete("lifesupport")
					Houston.say("Copy canister change. CO2 levels coming down.", "Entendido, troca do cartucho. O nível de CO₂ está caindo."))
			else:
				_modal("LIFE SUPPORT", info)
		"nav":
			if _has_task("nav") and not _done("nav"):
				_decision("midcourse", "nav")
			else:
				_modal("NAVIGATION", "Desvio de trajetória registrado após a TLI: [b]%.0f%%[/b]\nPropelente do CSM: [b]%.0f%%[/b]\nO propelente do CSM é necessário para entrar em órbita lunar e voltar para casa." % [ms.trajectory_error * 100.0, ms.sps_fuel])
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
				if ms.random_event == "comm_dropout":
					_decision("comm_dropout", "radio")
				else:
					_complete("radio")
					Houston.say("Thanks for the update, Apollo. Everything looks good from here.",
						"Obrigado pela atualização, Apollo. Tudo certo por aqui.")
					_modal("RADIO", "Relatório enviado: suprimentos, energia e estado da tripulação.\nHouston acompanha a missão em tempo real e ajuda a planejar cada manobra.")
			else:
				_modal("RADIO", "Canal com Houston aberto. A comunicação é a principal fonte de dados de navegação e alertas.")
		"console":
			if ms.day == 2 and _has_task("console") and not _done("console"):
				_decision("ptc", "console")
			elif ms.day >= 3 and not _done("console"):
				_approach_checklist()
			else:
				_modal("COMMAND CONSOLE", "Painel principal de comando. Nenhum procedimento pendente aqui.")
		"hatch":
			if ms.day < 3:
				_modal("LUNAR MODULE HATCH", "O túnel para o módulo lunar só é aberto na órbita da Lua (dia 3).")
			elif not _done("console"):
				_modal("LUNAR MODULE HATCH", "Complete primeiro o checklist de aproximação no COMMAND CONSOLE.")
			else:
				var missing := _pending("hatch")
				var warn := "" if missing.is_empty() else "\n\n[color=#ffcc44]Tarefas pendentes serão ignoradas: %s.[/color]" % ", ".join(PackedStringArray(missing.map(func(t): return t["station"])))
				_modal("LUNAR MODULE HATCH", "Entrar no módulo lunar e iniciar a descida?\nUm checkpoint será salvo: se o pouso falhar, você recomeça daqui." + warn, ["ENTRAR NO MÓDULO LUNAR", "AINDA NÃO"], func(i):
					if i == 0:
						_complete("hatch")
						Game.enter_lunar_module())
		"rest":
			if not _has_task("rest"):
				_modal("REST", "Hoje não há tempo para descanso: a Lua está logo ali.")
				return
			var missing := _pending("rest")
			if not missing.is_empty():
				var text := "Antes de descansar, conclua:\n"
				for t in missing:
					text += "• %s — %s\n" % [t["station"], t["text"]]
				_modal("REST", text)
				return
			_modal("REST", "Encerrar o dia %d e descansar?" % ms.day, ["DESCANSAR", "AINDA NÃO"], func(i):
				if i == 0:
					_next_day())
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
		["Navegação", ms.trajectory_error < 0.5 or ms.tasks_done.has("1:nav"), "desvio corrigido" if ms.tasks_done.has("1:nav") else "verificar"],
		["Sistemas", ms.integrity >= 70.0, "integridade %.0f%%" % ms.integrity],
		["Módulo lunar", true, "propelente de descida: %.0f s" % ms.lm_fuel],
	]
	var text := ""
	for check in checks:
		text += "%s %s: %s\n" % ["[color=#77ee77]OK[/color]" if check[1] else "[color=#ffcc44]ATENÇÃO[/color]", check[0], check[2]]
	text += "\nConfirmar a inserção em órbita lunar? O motor do CSM vai frear a nave para que a Lua a capture."
	_modal("CHECKLIST DE APROXIMAÇÃO", text, ["CONFIRMAR INSERÇÃO EM ÓRBITA LUNAR"], func(_i):
		ms.sps_fuel -= loi
		ms.clamp_resources()
		ms.add_event("loi", "Inserção em órbita lunar", "Propelente do CSM restante: %.0f%%" % ms.sps_fuel)
		_complete("console")
		Houston.say("Burn complete. Welcome to lunar orbit. You are go to enter the lunar module.",
			"Queima concluída. Bem-vindos à órbita lunar. Podem entrar no módulo lunar.")
		_modal("ÓRBITA LUNAR", "A nave está em órbita da Lua.\nFlutue até a escotilha no teto (LUNAR MODULE HATCH) e pressione E."))


func _next_day() -> void:
	var ms := MissionState
	ms.day += 1
	ms.changed.emit()
	_update_backdrop()
	_refresh_objective()
	if hud.checklist_visible():
		hud.show_checklist(day_tasks())
	_start_day_briefing()
