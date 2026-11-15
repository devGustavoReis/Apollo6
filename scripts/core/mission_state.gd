extends Node
## Estado central da missão (autoload "MissionState").
## Todas as cenas consultam e alteram os recursos somente por aqui.

signal changed

const EQUIPMENT_PATH := "res://data/equipment/equipment.json"
## Apollo 11 durou 8 dias, 3 h e 19 min (NASA). O jogo usa 5 dias jogáveis e 3 saltos.
## Cada dia jogável pede 1 cota de comida e 1 de água; cada salto cobra mais 1 de cada.
const MISSION_DAYS := 8
const PLAY_DAYS := 5
const TRAVEL_DAYS := 3
const DEPARTURE_RESERVE := 3
const REFERENCE_DURATION := "8 dias, 3 h e 19 min"
const SUPPLY_KINDS := ["food", "water"]
const JUMPS := {
	"A": {"title": "Órbita lunar", "short": "Órbita lunar"},
	"B": {"title": "Operações lunares", "short": "Operações lunares"},
	"C": {"title": "Aproximação da Terra", "short": "Aproximação da Terra"},
}
const PHASE_TITLES := {
	"outbound": "VIAGEM À LUA", "lunar": "NA LUA", "return": "VOLTA À TERRA", "earth": "REENTRADA",
}
const MINIGAME_ASSIST_CHANCE := 0.8
const CABIN_MINIGAME_POINTS := 100
const CABIN_MINIGAMES := {
	"M01": {"day": 1, "station": "storage", "title": "Prender objetos soltos", "scene": "res://scenes/minigames/loose_objects_minigame.tscn"},
	"M02": {"day": 1, "station": "water", "title": "Abastecer a bolsa de água", "scene": "res://scenes/minigames/water_fill_minigame.tscn"},
	"M05": {"day": 2, "station": "rest", "title": "Preparar a cabine para descanso", "scene": "res://scenes/minigames/rest_prep_minigame.tscn"},
	"M06": {"day": 3, "station": "disposal", "title": "Guardar embalagens da refeição", "scene": "res://scenes/minigames/meal_stowage_minigame.tscn"},
	"M04": {"day": 4, "station": "tools", "title": "Encaixar o conector do traje", "scene": "res://scenes/minigames/suit_connector_minigame.tscn"},
	"M03": {"day": 5, "station": "radio", "title": "Recuperar o sinal da antena", "scene": "res://scenes/minigames/antenna_minigame.tscn"},
}
## Velocidade aproximada da Apollo 11 ao fim da injeção translunar: 35.545,6 ft/s (NASA SP-4029).
const TLI_TARGET_KMS := 10.83

## Diferença principal entre dificuldades: armazenamento e margem de erro.
const DIFFICULTIES := {
	"easy": {
		"name": "FÁCIL", "storage": 24, "mass_limit": 260.0, "power": 80.0,
		"land_vy": 3.0, "land_vh": 1.5, "land_tilt": 12.0, "land_alt": 110.0,
		"land_fuel": 80.0, "land_drift": 1.5, "tli_tol": 0.12, "sep_time": 40.0, "traj_tol": 50.0,
		"summary": "Armazenamento folgado, alertas claros e maior tolerância nos procedimentos.",
	},
	"normal": {
		"name": "NORMAL", "storage": 21, "mass_limit": 220.0, "power": 60.0,
		"land_vy": 2.5, "land_vh": 1.2, "land_tilt": 10.0, "land_alt": 140.0,
		"land_fuel": 70.0, "land_drift": 2.5, "tli_tol": 0.08, "sep_time": 30.0, "traj_tol": 36.0,
		"summary": "Armazenamento equilibrado. Você terá de escolher o que levar.",
	},
	"hard": {
		"name": "DIFÍCIL", "storage": 17, "mass_limit": 190.0, "power": 50.0,
		"land_vy": 2.0, "land_vh": 1.0, "land_tilt": 8.0, "land_alt": 160.0,
		"land_fuel": 64.0, "land_drift": 3.5, "tli_tol": 0.06, "sep_time": 24.0, "traj_tol": 26.0,
		"summary": "Armazenamento mínimo: só o essencial cabe na nave e há menos margem para erros.",
	},
}

const OBJECTIVES := {
	"sample_kit": {"title": "Composição das rochas e do solo", "action": "COLETAR E ARMAZENAR AMOSTRA", "evidence": "Amostra armazenada para análise na Terra."},
	"retroreflector": {"title": "Distância entre Terra e Lua", "action": "POSICIONAR O RETRORREFLETOR", "evidence": "Retrorrefletor instalado na Lua para medições por estações terrestres."},
	"camera": {"title": "Textura e relevo do regolito", "action": "REGISTRAR PAR ESTÉREO", "evidence": "Par de fotografias próximas do solo registrado."},
}
## Necessidades do astronauta (FOME e SEDE no HUD), de 0 a 100. Cheia = necessidade atendida;
## qualquer uma em 0 encerra a missão. A drenagem normal corre só na cabine, com o jogador
## no controle. Dormir depois de um dia sem comer acorda o jogador com as duas em nível
## crítico: cada uma cai até zero no tempo crítico da dificuldade, a menos que ele coma ou beba.
const NEED_MAX := 100.0
const MEAL_GAIN := 50.0
const NEED_LOW := 25.0
const CRITICAL_WAKE := 5.0
const CRITICAL_SECONDS := {"easy": 20.0, "normal": 15.0, "hard": 10.0}
## Duas barras que zeram com até este intervalo entre si encerram como "juntas".
const SIMULTANEOUS_SECONDS := 1.0
## Pontos perdidos por dia jogável acordado e a duração típica desse dia, em segundos de
## jogo ativo, por dificuldade. Ajuste aqui o balanceamento.
const HUNGER_PER_DAY := 20.0
const THIRST_PER_DAY := 30.0
const NEEDS_DAY_SECONDS := {"easy": 360.0, "normal": 300.0, "hard": 240.0}
const NEED_KINDS := ["food", "water"]

## Pede ao jogo a fala "Estou com fome" ou "Estou com sede" quando a barra cruza 25%.
signal need_warning(kind: String)
signal critical_wake_started

var objective := ""
var science_completed := false
var lunar_flag_planted := false
var nourishment := NEED_MAX
var hydration := NEED_MAX
## Queda crítica em andamento, por necessidade: {"start": valor inicial, "elapsed": segundos}.
var need_critical: Dictionary = {}
## Aviso de voz já pedido no episódio atual abaixo de 25%, por necessidade.
var need_warned: Dictionary = {}
## O próximo despertar será crítico (o dia que fechou não teve nenhuma comida).
var critical_wake_pending := false
var slept_days: Dictionary = {}
var supply_tokens: Dictionary = {}
var next_supply_token := 1

## Campos salvos nos checkpoints. Contadores de tentativas ficam de fora de propósito.
const SAVED_FIELDS := [
	"supply_tokens", "next_supply_token", "decision_seed", "objective", "science_completed", "lunar_flag_planted", "landing_result", "nourishment", "hydration", "slept_days",
	"need_critical", "need_warned", "critical_wake_pending",
	"difficulty", "cargo", "food_days", "water_days", "food_eaten", "water_drunk",
	"power_capacity", "instruments_active", "spare_parts", "battery_used",
	"sps_fuel", "lm_fuel", "lm_fuel_max", "integrity", "life_support",
	"science_multiplier", "science_collected", "trajectory_error", "stage", "day",
	"tasks_done", "events", "decisions", "random_event", "separation_mistakes",
	"minigame_attempts", "minigame_completions",
	"phase", "intake", "sealed", "losses", "jumps", "jump_food", "jump_water",
	"lost_food", "lost_water", "departure", "return_error",
]

var catalog: Array = []
var items: Dictionary = {}
var _minigame_tools: Dictionary = {}

var difficulty := "normal"
var cargo: Dictionary = {}
var food_days := 0.0
var water_days := 0.0
var food_eaten := 0.0
var water_drunk := 0.0
var power_capacity := 60.0
var instruments_active: Dictionary = {}
var spare_parts := false
var battery_used := false
## Propelente do módulo de serviço (CSM), em %. Usado em correções e na inserção em órbita lunar.
var sps_fuel := 100.0
## Propelente do módulo lunar, em segundos de motor a 100%.
var lm_fuel := 70.0
var lm_fuel_max := 70.0
var integrity := 100.0
var life_support := 100.0
var science_multiplier := 1.0
var science_collected := 0.0
var trajectory_error := 0.0
var stage := "menu"
var day := 1
var tasks_done: Dictionary = {}
var minigame_attempts: Dictionary = {}
var minigame_completions: Dictionary = {}
var events: Array = []
var decisions: Array = []
var random_event := ""
var decision_seed := 0
var separation_mistakes := 0

var phase := "outbound"
var intake: Dictionary = {}
var sealed: Dictionary = {}
var losses: Array = []
var jumps: Dictionary = {}
var jump_food := 0.0
var jump_water := 0.0
var lost_food := 0.0
var lost_water := 0.0
var departure: Dictionary = {}
var return_error := 0.0
var ended: Dictionary = {}
var landing_history: Array = []
var reentry_result: Dictionary = {}
var reentry_history: Array = []
var reentry_attempts := 0
var splashdown := false
var test_samples: Array = []

var checkpoints: Dictionary = {}
var current_checkpoint := ""
var separation_attempts := 0
var landing_attempts := 0
var landing_result: Dictionary = {}
var last_failure: Dictionary = {}
var tutorial_seen := false


func _ready() -> void:
	_load_catalog()
	reset("normal")


func refresh_catalog_language() -> void:
	_load_catalog()


func _load_catalog() -> void:
	var file := FileAccess.open(EQUIPMENT_PATH, FileAccess.READ)
	if file == null:
		push_error(str(TranslationServer.translate("Catálogo de equipamentos não encontrado: ")) + EQUIPMENT_PATH)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	catalog = data["items"]
	items.clear()
	_minigame_tools.clear()
	for item in catalog:
		for field in ["name", "description", "source"]:
			if item.has(field):
				item[field] = tr(item[field])
		items[item["id"]] = item
		for task_id: String in item.get("minigames", []):
			_minigame_tools[task_id] = item["id"]


func reset(new_difficulty: String) -> void:
	difficulty = new_difficulty if DIFFICULTIES.has(new_difficulty) else "normal"
	cargo = {"food_day": MISSION_DAYS, "water_day": MISSION_DAYS}
	objective = ""
	science_completed = false
	lunar_flag_planted = false
	nourishment = NEED_MAX
	hydration = NEED_MAX
	need_critical = {}
	need_warned = {}
	critical_wake_pending = false
	slept_days = {}
	supply_tokens = {}
	next_supply_token = 1
	phase = "outbound"
	intake = {}
	sealed = {}
	losses = []
	jumps = {}
	jump_food = 0.0
	jump_water = 0.0
	lost_food = 0.0
	lost_water = 0.0
	departure = {}
	return_error = 0.0
	ended = {}
	landing_history = []
	reentry_result = {}
	reentry_history = []
	reentry_attempts = 0
	splashdown = false
	test_samples = []
	food_days = 0.0
	water_days = 0.0
	food_eaten = 0.0
	water_drunk = 0.0
	power_capacity = settings()["power"]
	instruments_active = {}
	spare_parts = false
	battery_used = false
	sps_fuel = 100.0
	lm_fuel_max = settings()["land_fuel"]
	lm_fuel = lm_fuel_max
	integrity = 100.0
	life_support = 100.0
	science_multiplier = 1.0
	science_collected = 0.0
	trajectory_error = 0.0
	stage = "planning"
	day = 1
	tasks_done = {}
	minigame_attempts = {}
	minigame_completions = {}
	events = []
	decisions = []
	separation_mistakes = 0
	var pool := ["comm_dropout", "water_leak", "ptc"]
	random_event = pool[randi() % pool.size()]
	decision_seed = randi_range(0, 1)
	checkpoints = {}
	current_checkpoint = ""
	separation_attempts = 0
	landing_attempts = 0
	landing_result = {}
	last_failure = {}
	changed.emit()


func day_two_decision_order() -> Array[String]:
	var stations: Array[String] = ["power"]
	if random_event == "water_leak":
		stations.append("water")
	elif random_event == "ptc":
		stations.append("console")
	if decision_seed == 1:
		stations.reverse()
	return stations


func settings() -> Dictionary:
	var values: Dictionary = DIFFICULTIES[difficulty].duplicate()
	values["name"] = tr(values["name"])
	values["summary"] = tr(values["summary"])
	return values


# ---------- Planejamento ----------

func qty(id: String) -> int:
	return int(cargo.get(id, 0))


func set_qty(id: String, value: int) -> void:
	if not items.has(id):
		return
	var item: Dictionary = items[id]
	if item["category"] == "science" and id != objective:
		return
	var limit := int(item["max"])
	if value > qty(id):
		limit = mini(limit, int(settings()["storage"]) - plan_items() + qty(id))
	cargo[id] = clampi(value, 0, maxi(limit, qty(id)))
	changed.emit()


func plan_items() -> int:
	var total := 0
	for id in cargo:
		if not items.has(id):
			continue
		total += qty(id)
	return total


func plan_mass() -> float:
	var total := 0.0
	for id in cargo:
		if not items.has(id):
			continue
		total += float(items[id]["mass"]) * qty(id)
	return total


func plan_power() -> float:
	var total := 0.0
	for id in cargo:
		if not items.has(id):
			continue
		total += float(items[id]["power"]) * qty(id)
	return total


func plan_power_capacity() -> float:
	return settings()["power"] + float(items["battery_pack"]["power_bonus"]) * qty("battery_pack")


func plan_science() -> float:
	var total := 0.0
	for id in cargo:
		if not items.has(id):
			continue
		total += float(items[id]["science"]) * qty(id)
	return total


func plan_landing_fuel() -> float:
	return settings()["land_fuel"] * (1.0 + float(items["propellant_reserve"]["fuel_bonus"]) * qty("propellant_reserve"))


func validate_plan() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var s := settings()
	if plan_items() > int(s["storage"]):
		errors.append(str(TranslationServer.translate("Armazenamento excedido em %d itens.")) % (plan_items() - int(s["storage"])))
	if plan_mass() > s["mass_limit"] + 0.001:
		errors.append(str(TranslationServer.translate("Massa acima do limite do foguete em %.0f kg.")) % (plan_mass() - s["mass_limit"]))
	if qty("food_day") < MISSION_DAYS:
		errors.append(str(TranslationServer.translate("Comida insuficiente: %d de %d cotas (5 dias jogáveis + 3 saltos).")) % [qty("food_day"), MISSION_DAYS])
	if qty("water_day") < MISSION_DAYS:
		errors.append(str(TranslationServer.translate("Água insuficiente: %d de %d cotas (5 dias jogáveis + 3 saltos).")) % [qty("water_day"), MISSION_DAYS])
	if not OBJECTIVES.has(objective):
		errors.append(str(TranslationServer.translate("Escolha o objetivo científico antes de lançar.")))
	elif qty(objective) != 1:
		errors.append(str(TranslationServer.translate("Inclua o instrumento do objetivo escolhido.")))
	for id in cargo:
		if not items.has(id) or (items[id]["category"] == "science" and id != objective and qty(id) > 0):
			errors.append(str(TranslationServer.translate("Carga incompatível. Revise o planejamento.")))
	if plan_science() <= 0:
		errors.append(str(TranslationServer.translate("Leve ao menos um instrumento científico: é o objetivo da missão.")))
	if qty("food_day") == MISSION_DAYS:
		warnings.append(str(TranslationServer.translate("Comida exata: margem zero para consumo extra ou perda.")))
	if qty("water_day") == MISSION_DAYS:
		warnings.append(str(TranslationServer.translate("Água exata: margem zero. Um vazamento impediria a volta.")))
	if plan_power() > plan_power_capacity():
		errors.append(str(TranslationServer.translate("Instrumentos consomem %.0f W, acima dos %.0f W disponíveis.")) % [plan_power(), plan_power_capacity()])
	if qty("propellant_reserve") == 0:
		warnings.append(str(TranslationServer.translate("Sem reserva de propelente do LM: o pouso terá menos margem.")))
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings}


func apply_plan() -> void:
	if not validate_plan()["ok"]:
		return
	food_days = qty("food_day")
	water_days = qty("water_day")
	power_capacity = plan_power_capacity()
	lm_fuel_max = plan_landing_fuel()
	lm_fuel = lm_fuel_max
	spare_parts = qty("spare_parts") > 0
	instruments_active = {}
	for id in cargo:
		if items[id]["category"] == "science" and qty(id) > 0:
			instruments_active[id] = true
	stage = "launch"
	changed.emit()


# ---------- Minigames de cabine ----------

func next_minigame_attempt(task_id: String) -> int:
	var attempts: Dictionary = minigame_attempts.get(task_id, {})
	var attempt_id := 1
	for existing: int in attempts:
		attempt_id = maxi(attempt_id, existing + 1)
	return attempt_id


func cabin_minigame_report() -> Dictionary:
	var rows: Array[Dictionary] = []
	var total := 0
	for id: String in CABIN_MINIGAMES:
		var result: Dictionary = minigame_completions.get(id, {})
		var status := str(TranslationServer.translate("Pendente"))
		var points := 0
		if not result.is_empty():
			points = CABIN_MINIGAME_POINTS
			status = str(TranslationServer.translate("Concluída"))
			if result["assisted"]:
				status = str(TranslationServer.translate("Concluída com ajuda — %s")) % items[result["tool_id"]]["name"]
		rows.append({"title": CABIN_MINIGAMES[id]["title"], "status": status, "points": points})
		total += points
	return {"rows": rows, "points": total, "possible": rows.size() * CABIN_MINIGAME_POINTS}


## Chame ao finalizar uma tentativa. Cada tarefa usa um ID de tentativa novo e positivo
## a cada repetição legítima. O mesmo ID sempre devolve o resultado já resolvido.
func resolve_minigame_attempt(task_id: String, attempt_id: int, played_well: bool) -> Dictionary:
	if not _minigame_tools.has(task_id) or attempt_id < 1:
		push_error(str(TranslationServer.translate("Tentativa de minigame inválida: %s, tentativa %d.")) % [task_id, attempt_id])
		return {}

	var attempts: Dictionary = minigame_attempts.get(task_id, {})
	var previous: Dictionary = attempts.get(attempt_id, minigame_completions.get(task_id, {}))
	if not previous.is_empty():
		var replay := previous.duplicate()
		replay["new_attempt"] = false
		replay["new_completion"] = false
		return replay

	var tool_id: String = _minigame_tools[task_id]
	var has_tool := not played_well and qty(tool_id) > 0
	var assisted := has_tool and randf() < MINIGAME_ASSIST_CHANCE
	var completed := played_well or assisted
	var tool_name: String = items[tool_id]["name"]
	var title := str(TranslationServer.translate("Tarefa concluída"))
	var message := str(TranslationServer.translate("Você concluiu a tarefa no minigame."))
	if assisted:
		title = str(TranslationServer.translate("Tarefa concluída com ajuda"))
		message = str(TranslationServer.translate("Você errou o minigame. A tarefa foi concluída graças a: %s.")) % tool_name
	elif not played_well:
		title = str(TranslationServer.translate("Tarefa pendente"))
		message = str(TranslationServer.translate("Você errou o minigame. Tente novamente."))
		if has_tool:
			message = str(TranslationServer.translate("Você errou o minigame. A ferramenta %s não recuperou esta tentativa. Tente novamente.")) % tool_name

	var result := {
		"completed": completed, "played_well": played_well, "assisted": assisted,
		"tool_id": tool_id if has_tool else "", "title": title, "message": message,
		"new_attempt": true, "new_completion": completed,
	}
	attempts[attempt_id] = result
	minigame_attempts[task_id] = attempts
	if completed:
		minigame_completions[task_id] = result
	changed.emit()
	return result.duplicate()


# ---------- Viagem ----------

func power_use() -> float:
	var total := 0.0
	for id in instruments_active:
		if items.has(id) and instruments_active[id]:
			total += float(items[id]["power"])
	return total


func science_potential() -> float:
	var total := 0.0
	for id in instruments_active:
		if not items.has(id):
			continue
		total += float(items[id]["science"])
	return total * science_multiplier


func sample() -> float:
	if not test_samples.is_empty():
		return test_samples.pop_front()
	return randf()


func phase_title() -> String:
	return tr(PHASE_TITLES.get(phase, ""))


func stock(kind: String) -> float:
	return food_days if kind == "food" else water_days


func _set_stock(kind: String, value: float) -> void:
	if kind == "food":
		food_days = maxf(value, 0.0)
	else:
		water_days = maxf(value, 0.0)


func can_consume(kind: String) -> bool:
	return kind in SUPPLY_KINDS and ended.is_empty() and stock(kind) >= 1.0 - 0.0001


## Texto de uma quantidade de cotas. Saldos são arredondados para baixo (0,99 aparece 0,9),
## para o HUD nunca prometer uma cota inteira que can_consume() recusaria. Faltas
## (round_up = true) são arredondadas para cima, para nunca aparecer "faltou 0".
func amount_text(value: float, round_up := false) -> String:
	if absf(value - roundf(value)) < 0.0001:
		return "%d" % int(roundf(value))
	var tenths := ceilf(value * 10.0 - 0.0001) if round_up else floorf(value * 10.0 + 0.0001)
	if int(tenths) % 10 == 0:
		return "%d" % int(tenths / 10.0)
	return ("%.1f" % (tenths / 10.0)).replace(".", ",")


func kind_name(kind: String, value: float) -> String:
	if kind == "food":
		return str(TranslationServer.translate("comida")) if absf(value - 1.0) < 0.01 else str(TranslationServer.translate("comidas"))
	return str(TranslationServer.translate("água")) if absf(value - 1.0) < 0.01 else str(TranslationServer.translate("águas"))


func intake_on(day_number: int, kind: String) -> int:
	return int(intake.get(str(day_number), {}).get(kind, 0))


func consume(kind: String) -> bool:
	if not can_consume(kind) or available_supply(kind) < 1.0 - 0.0001:
		return false
	return _consume_ration(kind)


func _consume_ration(kind: String) -> bool:
	_set_stock(kind, stock(kind) - 1.0)
	_restore_need(kind)
	var key := str(day)
	var today: Dictionary = intake.get(key, {"food": 0, "water": 0})
	today[kind] = int(today.get(kind, 0)) + 1
	intake[key] = today
	if kind == "food":
		food_eaten += 1.0
	else:
		water_drunk += 1.0
	changed.emit()
	return true


func eat() -> bool:
	return consume("food")


func drink() -> bool:
	return consume("water")


func lose(kind: String, amount: float, cause: String) -> float:
	var applied := minf(amount, stock(kind))
	_set_stock(kind, stock(kind) - applied)
	if kind == "food":
		lost_food += applied
	else:
		lost_water += applied
	losses.append({"kind": kind, "amount": applied, "asked": amount, "cause": cause, "day": day})
	changed.emit()
	return applied


func seal_day(day_number: int) -> Dictionary:
	var key := str(day_number)
	if sealed.has(key):
		return sealed[key]
	var result := {"food": intake_on(day_number, "food"), "water": intake_on(day_number, "water"),
		"food_left": food_days, "water_left": water_days, "missing": [], "no_stock": []}
	for kind: String in SUPPLY_KINDS:
		if result[kind] < 1:
			result["missing"].append(kind)
			if not can_consume(kind):
				result["no_stock"].append(kind)
	sealed[key] = result
	changed.emit()
	return result


func jump_preview(id: String) -> Dictionary:
	var result := {"id": id, "food_before": food_days, "water_before": water_days, "deficits": {}, "ok": true}
	for kind: String in SUPPLY_KINDS:
		if not can_consume(kind):
			result["deficits"][kind] = 1.0 - stock(kind)
			result["ok"] = false
	result["food_after"] = maxf(food_days - 1.0, 0.0) if result["ok"] else food_days
	result["water_after"] = maxf(water_days - 1.0, 0.0) if result["ok"] else water_days
	return result


func pay_jump(id: String) -> Dictionary:
	if jumps.has(id):
		return jumps[id]
	var result := jump_preview(id)
	if result["ok"]:
		# can_consume aceita saldo até 0,0001 abaixo de 1: o estoque nunca fica negativo.
		_set_stock("food", food_days - 1.0)
		_set_stock("water", water_days - 1.0)
		jump_food += 1.0
		jump_water += 1.0
	jumps[id] = result
	add_event("jump_" + id, str(TranslationServer.translate(JUMPS[id]["title"])), jump_text(id))
	return result


func jump_text(id: String) -> String:
	var j: Dictionary = jumps[id]
	if j["ok"]:
		return str(TranslationServer.translate("1 comida e 1 água cobradas. Saldo: %s comida · %s água.")) % [amount_text(j["food_after"]), amount_text(j["water_after"])]
	var parts := []
	for kind: String in j["deficits"]:
		var missing: float = j["deficits"][kind]
		parts.append(str(TranslationServer.translate("%s cota de %s")) % [amount_text(missing, true), str(TranslationServer.translate("comida")) if kind == "food" else str(TranslationServer.translate("água"))])
	return str(TranslationServer.translate("Faltou %s para avançar.")) % str(TranslationServer.translate(" e ")).join(PackedStringArray(parts))


func check_departure() -> Dictionary:
	if not departure.is_empty():
		return departure
	var result := {"food": food_days, "water": water_days, "deficits": {}, "ok": true}
	for kind: String in SUPPLY_KINDS:
		if stock(kind) < DEPARTURE_RESERVE - 0.0001:
			result["deficits"][kind] = DEPARTURE_RESERVE - stock(kind)
			result["ok"] = false
	departure = result
	changed.emit()
	return result


func departure_text() -> String:
	var d := departure
	var text := str(TranslationServer.translate("Havia %s %s e %s %s.")) % [amount_text(d["food"]), kind_name("food", d["food"]),
		amount_text(d["water"]), kind_name("water", d["water"])]
	var parts := []
	for kind: String in d["deficits"]:
		var missing: float = d["deficits"][kind]
		parts.append("%s %s" % [amount_text(missing, true), kind_name(kind, missing)])
	if not parts.is_empty():
		text += str(TranslationServer.translate(" Faltou %s.")) % str(TranslationServer.translate(" e ")).join(PackedStringArray(parts))
	return text


func end_mission(where: String, reason: String) -> void:
	if ended.is_empty():
		ended = {"stage": where, "reason": reason}
	stage = "report"
	changed.emit()


func day_issues() -> Array:
	var issues := []
	for d in range(1, PLAY_DAYS + 1):
		var key := str(d)
		if not sealed.has(key):
			continue
		var s: Dictionary = sealed[key]
		for kind: String in s["missing"]:
			var noun := str(TranslationServer.translate("comida")) if kind == "food" else str(TranslationServer.translate("água"))
			if kind in s["no_stock"]:
				issues.append(str(TranslationServer.translate("Dia %d · Faltou %s para o consumo diário.")) % [d, noun])
			elif kind == "food":
				issues.append(str(TranslationServer.translate("Dia %d · Nenhuma ração foi consumida, apesar de haver estoque.")) % d)
			else:
				issues.append(str(TranslationServer.translate("Dia %d · Nenhuma água foi consumida, apesar de haver estoque.")) % d)
	return issues


func verdict() -> Dictionary:
	# Um dia sem comer ou beber não reprova a missão por si só: quem decide são as barras de
	# FOME e SEDE (fim por "survival"). day_issues() continua no relatório de suprimentos.
	var causes := []
	if ended.get("stage", "") == "survival":
		causes.append(ended["reason"])
	if splashdown and not science_completed:
		causes.append(str(TranslationServer.translate("Objetivo científico não concluído.")))
	for id: String in ["A", "B", "C"]:
		if jumps.has(id) and not jumps[id]["ok"]:
			causes.append("%s · %s" % [str(TranslationServer.translate(JUMPS[id]["title"])), jump_text(id)])
	if not departure.is_empty() and not departure["ok"]:
		causes.append(str(TranslationServer.translate("Partida para a Terra · ")) + departure_text())
	if ended.get("stage", "") == "reentry":
		causes.append(str(TranslationServer.translate("Reentrada · Janela de abertura dos paraquedas perdida.")))
	var landed: bool = landing_result.get("success", false)
	var all_sealed := sealed.size() == PLAY_DAYS
	var all_paid: bool = jumps.size() == 3 and jumps.values().all(func(j): return j["ok"])
	var success: bool = landed and splashdown and all_sealed and all_paid and bool(departure.get("ok", false)) and causes.is_empty()
	if not success and causes.is_empty():
		causes.append(str(TranslationServer.translate("Missão incompleta · Nem todas as etapas da missão foram cumpridas.")))
	var summary := ""
	if success:
		summary = str(TranslationServer.translate("Pouso lunar seguro e tripulação de volta à Terra."))
	elif landed and splashdown:
		summary = str(TranslationServer.translate("Amerissagem confirmada. Missão falhou: %s")) % causes[0]
	elif landed and not causes.is_empty():
		summary = str(TranslationServer.translate("Pouso lunar confirmado. %s")) % causes[0]
	elif not causes.is_empty():
		summary = causes[0]
	else:
		summary = str(TranslationServer.translate("A missão não chegou ao fim."))
	return {"success": success, "title": str(TranslationServer.translate("Missão concluída")) if success else str(TranslationServer.translate("Missão falhou")),
		"summary": summary, "causes": causes, "landed": landed}


func add_event(id: String, title: String, outcome: String) -> void:
	events.append({"id": id, "title": title, "outcome": outcome})
	changed.emit()


func record_decision(id: String, title: String, choice: String, correct: bool, explanation: String) -> void:
	decisions.append({"id": id, "title": title, "choice": choice, "correct": correct, "explanation": explanation})
	changed.emit()


func clamp_resources() -> void:
	sps_fuel = clampf(sps_fuel, 0.0, 100.0)
	integrity = clampf(integrity, 0.0, 100.0)
	life_support = clampf(life_support, 0.0, 100.0)
	science_multiplier = clampf(science_multiplier, 0.2, 1.0)
	water_days = maxf(water_days, 0.0)
	food_days = maxf(food_days, 0.0)
	return_error = clampf(return_error, 0.0, 1.0)
	trajectory_error = clampf(trajectory_error, 0.0, 1.0)
	changed.emit()


# ---------- Checkpoints ----------

func save_checkpoint(checkpoint: String) -> void:
	var snapshot := {}
	for field in SAVED_FIELDS:
		snapshot[field] = _copy(get(field))
	checkpoints[checkpoint] = snapshot
	current_checkpoint = checkpoint


func restore_checkpoint(checkpoint: String) -> bool:
	if not checkpoints.has(checkpoint):
		return false
	var snapshot: Dictionary = checkpoints[checkpoint]
	for field in snapshot:
		set(field, _copy(snapshot[field]))
	current_checkpoint = checkpoint
	changed.emit()
	return true


func _copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


func set_failure(failure_stage: String, title: String, reasons: Array, tips: Array) -> void:
	last_failure = {"stage": failure_stage, "title": title, "reasons": reasons, "tips": tips}


func select_objective(id: String) -> void:
	if not OBJECTIVES.has(id) or stage != "planning":
		return
	for old in cargo.keys():
		if not items.has(old) or items[old]["category"] == "science":
			cargo.erase(old)
	objective = id
	changed.emit()


func can_start_surface() -> bool:
	return landing_result.get("success", false) and OBJECTIVES.has(objective) and qty(objective) == 1 and ended.is_empty()


func complete_science() -> bool:
	if science_completed or not landing_result.get("success", false):
		return false
	if not OBJECTIVES.has(objective) or qty(objective) != 1:
		return false
	science_completed = true
	science_collected = science_potential()
	add_event("science", OBJECTIVES[objective]["title"], OBJECTIVES[objective]["evidence"])
	return true


func need(kind: String) -> float:
	return nourishment if kind == "food" else hydration


func _set_need(kind: String, value: float) -> void:
	value = clampf(value, 0.0, NEED_MAX)
	if kind == "food":
		nourishment = value
	else:
		hydration = value


## Pontos perdidos por segundo de jogo ativo na drenagem normal.
func need_rate(kind: String) -> float:
	var per_day := HUNGER_PER_DAY if kind == "food" else THIRST_PER_DAY
	return per_day / float(NEEDS_DAY_SECONDS.get(difficulty, 300.0))


## Segundos que faltam para a barra zerar na queda crítica (0 sem queda crítica).
func critical_left(kind: String) -> float:
	if not need_critical.has(kind):
		return 0.0
	return maxf(0.0, critical_seconds() - float(need_critical[kind]["elapsed"]))


func critical_seconds() -> float:
	return float(CRITICAL_SECONDS.get(difficulty, 15.0))


## Avança as necessidades. Chame só com o jogador no controle da cabine, sem pausa nem janela
## aberta: é o relógio de jogo ativo das barras e da queda crítica.
func advance_survival(seconds: float) -> void:
	if stage != "cabin" or not ended.is_empty() or seconds <= 0.0:
		return
	# Um quadro longo para no instante em que a primeira barra zera: a causa registrada é a
	# que zerou primeiro, como aconteceria em quadros curtos. Barras que zeram até
	# SIMULTANEOUS_SECONDS depois da primeira contam como "juntas" (regra da equipe).
	var step := seconds
	for kind: String in NEED_KINDS:
		step = minf(step, _time_to_empty(kind))
	step = maxf(step, 0.0)
	var first_zero := step < seconds or step == seconds and NEED_KINDS.any(func(k): return _time_to_empty(k) <= seconds)
	for kind: String in NEED_KINDS:
		var reaches_zero := first_zero and _time_to_empty(kind) <= minf(step + SIMULTANEOUS_SECONDS, seconds) + 1e-9
		if need_critical.has(kind):
			# Queda crítica linear: do valor inicial até zero no tempo crítico da dificuldade.
			var entry: Dictionary = need_critical[kind]
			entry["elapsed"] = minf(float(entry["elapsed"]) + step, critical_seconds())
			_set_need(kind, float(entry["start"]) * (1.0 - float(entry["elapsed"]) / critical_seconds()))
		else:
			_set_need(kind, need(kind) - need_rate(kind) * step)
		if reaches_zero:
			_set_need(kind, 0.0)
	_check_needs()


## Segundos de jogo ativo até a barra zerar no ritmo atual.
func _time_to_empty(kind: String) -> float:
	if need(kind) <= 0.0:
		return 0.0
	if need_critical.has(kind):
		return maxf(0.0, critical_seconds() - float(need_critical[kind]["elapsed"]))
	var rate := need_rate(kind)
	return need(kind) / rate if rate > 0.0 else INF


## Avisos de voz (fome antes de sede) e derrota quando alguma barra chega a zero.
func _check_needs() -> void:
	for kind: String in NEED_KINDS:
		if need(kind) < NEED_LOW:
			if not need_warned.get(kind, false):
				need_warned[kind] = true
				need_warning.emit(kind)
		else:
			need_warned[kind] = false
	var empty: Array[String] = []
	for kind: String in NEED_KINDS:
		if need(kind) <= 0.0:
			empty.append(kind)
	if empty.is_empty() or not ended.is_empty():
		return
	var what := str(TranslationServer.translate("A fome chegou a zero"))
	if empty.size() == 2:
		what = str(TranslationServer.translate("A fome e a sede chegaram a zero juntas"))
	elif empty[0] == "water":
		what = str(TranslationServer.translate("A sede chegou a zero"))
	if not need_critical.is_empty():
		what += str(TranslationServer.translate(" depois de acordar em estado crítico sem comer e beber água a tempo"))
	end_mission("survival", str(TranslationServer.translate("Dia %d · %s. Saldo: %s comida e %s água.")) % [day, what, amount_text(food_days), amount_text(water_days)])
	ended["day"] = day
	ended["needs"] = empty
	ended["nourishment"] = nourishment
	ended["hydration"] = hydration


## Uma cota consumida: +50 pontos na barra, encerra só a queda crítica dela e rearma o aviso.
func _restore_need(kind: String) -> void:
	need_critical.erase(kind)
	_set_need(kind, minf(NEED_MAX, need(kind) + MEAL_GAIN))
	if need(kind) >= NEED_LOW:
		need_warned[kind] = false


## Fecha o dia ao dormir: se nenhuma comida foi consumida, o próximo despertar é crítico.
## Chame antes de avançar o dia.
func close_day_needs(day_number: int) -> void:
	if slept_days.has(day_number) or not ended.is_empty():
		return
	slept_days[day_number] = true
	if intake_on(day_number, "food") < 1:
		critical_wake_pending = true
	changed.emit()


## Chame quando o jogador recuperar o controle depois de dormir. Num despertar crítico,
## as duas barras ficam em no máximo 5% e começam a queda crítica da dificuldade.
func begin_wake() -> void:
	if not critical_wake_pending or not ended.is_empty():
		return
	critical_wake_pending = false
	for kind: String in NEED_KINDS:
		_set_need(kind, minf(need(kind), CRITICAL_WAKE))
		need_critical[kind] = {"start": need(kind), "elapsed": 0.0}
	_check_needs()
	critical_wake_started.emit()
	changed.emit()


func available_supply(kind: String) -> float:
	var reserved := 0
	for token in supply_tokens.values():
		if token["kind"] == kind:
			reserved += 1
	return maxf(0.0, stock(kind) - reserved)

func reserve_supply(kind: String) -> int:
	if not can_consume(kind) or available_supply(kind) < 1.0 - 0.0001:
		return 0
	var token := next_supply_token
	next_supply_token += 1
	supply_tokens[token] = {"kind": kind, "state": "held", "position": Vector3.ZERO, "velocity": Vector3.ZERO}
	return token

func consume_supply_token(token: int) -> bool:
	if not supply_tokens.has(token):
		return false
	var entry: Dictionary = supply_tokens[token]
	var kind: String = entry["kind"]
	if not can_consume(kind):
		return false
	supply_tokens.erase(token)
	return _consume_ration(kind)
