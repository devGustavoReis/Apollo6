extends Node
## Estado central da missão (autoload "MissionState").
## Todas as cenas consultam e alteram os recursos somente por aqui.

signal changed

const EQUIPMENT_PATH := "res://data/equipment/equipment.json"
## Apollo 11 durou 8 dias, 3 h e 18 min (NASA). Arredondado para 8 dias de suprimentos.
const MISSION_DAYS := 8
## Dias jogáveis da viagem até a Lua (a Apollo 11 levou cerca de 3 dias).
const TRAVEL_DAYS := 3
## Velocidade aproximada da Apollo 11 ao fim da injeção translunar: 35.545,6 ft/s (NASA SP-4029).
const TLI_TARGET_KMS := 10.83

## Diferença principal entre dificuldades: orçamento e margem de erro.
const DIFFICULTIES := {
	"easy": {
		"name": "FÁCIL", "budget": 30.0, "mass_limit": 260.0, "power": 80.0,
		"land_vy": 3.0, "land_vh": 1.5, "land_tilt": 12.0, "land_alt": 110.0,
		"land_fuel": 80.0, "land_drift": 1.5, "tli_tol": 0.12, "sep_time": 40.0, "traj_tol": 50.0,
		"summary": "Orçamento folgado, alertas claros e maior tolerância nos procedimentos.",
	},
	"normal": {
		"name": "NORMAL", "budget": 22.0, "mass_limit": 220.0, "power": 60.0,
		"land_vy": 2.5, "land_vh": 1.2, "land_tilt": 10.0, "land_alt": 140.0,
		"land_fuel": 70.0, "land_drift": 2.5, "tli_tol": 0.08, "sep_time": 30.0, "traj_tol": 36.0,
		"summary": "Orçamento equilibrado. Você terá de fazer algumas escolhas.",
	},
	"hard": {
		"name": "DIFÍCIL", "budget": 17.0, "mass_limit": 190.0, "power": 50.0,
		"land_vy": 2.0, "land_vh": 1.0, "land_tilt": 8.0, "land_alt": 160.0,
		"land_fuel": 64.0, "land_drift": 3.5, "tli_tol": 0.06, "sep_time": 24.0, "traj_tol": 26.0,
		"summary": "Orçamento apertado e menos margem para erros. O planejamento decide.",
	},
}

## Campos salvos nos checkpoints. Contadores de tentativas ficam de fora de propósito.
const SAVED_FIELDS := [
	"difficulty", "cargo", "food_days", "water_days", "food_eaten", "water_drunk",
	"power_capacity", "instruments_active", "spare_parts", "battery_used",
	"sps_fuel", "lm_fuel", "lm_fuel_max", "integrity", "life_support",
	"science_multiplier", "science_collected", "trajectory_error", "stage", "day",
	"tasks_done", "events", "decisions", "random_event", "separation_mistakes",
]

var catalog: Array = []
var items: Dictionary = {}

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
var events: Array = []
var decisions: Array = []
var random_event := ""
var separation_mistakes := 0

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


func _load_catalog() -> void:
	var file := FileAccess.open(EQUIPMENT_PATH, FileAccess.READ)
	if file == null:
		push_error("Catálogo de equipamentos não encontrado: " + EQUIPMENT_PATH)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	catalog = data["items"]
	items.clear()
	for item in catalog:
		items[item["id"]] = item


func reset(new_difficulty: String) -> void:
	difficulty = new_difficulty if DIFFICULTIES.has(new_difficulty) else "normal"
	cargo = {"food_day": MISSION_DAYS, "water_day": MISSION_DAYS}
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
	events = []
	decisions = []
	separation_mistakes = 0
	var pool := ["comm_dropout", "water_leak", "ptc"]
	random_event = pool[randi() % pool.size()]
	checkpoints = {}
	current_checkpoint = ""
	separation_attempts = 0
	landing_attempts = 0
	landing_result = {}
	last_failure = {}
	changed.emit()


func settings() -> Dictionary:
	return DIFFICULTIES[difficulty]


# ---------- Planejamento ----------

func qty(id: String) -> int:
	return int(cargo.get(id, 0))


func set_qty(id: String, value: int) -> void:
	var item: Dictionary = items[id]
	cargo[id] = clampi(value, 0, int(item["max"]))
	changed.emit()


func plan_cost() -> float:
	var total := 0.0
	for id in cargo:
		total += float(items[id]["cost"]) * qty(id)
	return total


func plan_mass() -> float:
	var total := 0.0
	for id in cargo:
		total += float(items[id]["mass"]) * qty(id)
	return total


func plan_power() -> float:
	var total := 0.0
	for id in cargo:
		total += float(items[id]["power"]) * qty(id)
	return total


func plan_power_capacity() -> float:
	return settings()["power"] + float(items["battery_pack"]["power_bonus"]) * qty("battery_pack")


func plan_science() -> float:
	var total := 0.0
	for id in cargo:
		total += float(items[id]["science"]) * qty(id)
	return total


func plan_landing_fuel() -> float:
	return settings()["land_fuel"] * (1.0 + float(items["propellant_reserve"]["fuel_bonus"]) * qty("propellant_reserve"))


func validate_plan() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var s := settings()
	if plan_cost() > s["budget"] + 0.001:
		errors.append("Orçamento excedido em US$ %.1f mi." % (plan_cost() - s["budget"]))
	if plan_mass() > s["mass_limit"] + 0.001:
		errors.append("Massa acima do limite do foguete em %.0f kg." % (plan_mass() - s["mass_limit"]))
	if qty("food_day") < MISSION_DAYS:
		errors.append("Comida insuficiente: a missão dura %d dias." % MISSION_DAYS)
	if qty("water_day") < MISSION_DAYS:
		errors.append("Água insuficiente: a missão dura %d dias." % MISSION_DAYS)
	if plan_science() <= 0:
		errors.append("Leve ao menos um instrumento científico: é o objetivo da missão.")
	if qty("food_day") == MISSION_DAYS:
		warnings.append("Comida sem nenhuma margem de reserva.")
	if qty("water_day") == MISSION_DAYS:
		warnings.append("Água sem margem: um vazamento deixaria a tripulação racionando.")
	if plan_power() > plan_power_capacity():
		warnings.append("Instrumentos consomem %.0f W, acima dos %.0f W disponíveis. Espere alertas de energia." % [plan_power(), plan_power_capacity()])
	if qty("propellant_reserve") == 0:
		warnings.append("Sem reserva de propelente do LM: o pouso terá menos margem.")
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings}


func apply_plan() -> void:
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


# ---------- Viagem ----------

func power_use() -> float:
	var total := 0.0
	for id in instruments_active:
		if instruments_active[id]:
			total += float(items[id]["power"])
	return total


func science_potential() -> float:
	var total := 0.0
	for id in instruments_active:
		total += float(items[id]["science"])
	return total * science_multiplier


func days_still_needed() -> int:
	## Dias de suprimento necessários depois das refeições do dia atual.
	return MISSION_DAYS - day


func eat() -> void:
	food_days = maxf(0.0, food_days - 1.0)
	food_eaten += 1.0
	changed.emit()


func drink() -> void:
	water_days = maxf(0.0, water_days - 1.0)
	water_drunk += 1.0
	changed.emit()


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
