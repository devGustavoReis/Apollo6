extends Control
## Relatório final educativo: pontuação explicada e sugestões para a próxima tentativa.

const STARFIELD := preload("res://scripts/ui/starfield.gd")


static func evaluate() -> Dictionary:
	var ms := MissionState
	var verdict := ms.verdict()
	var landed: bool = verdict["landed"]
	var parts := []
	var tips := []
	var landing := 0.0
	if landed:
		landing = maxf(10.0, 30.0 - 5.0 * (ms.landing_attempts - 1))
		if ms.landing_attempts > 1:
			tips.append("O pouso levou %d tentativas. Segure ESPAÇO mais cedo e elimine o deslizamento no alto." % ms.landing_attempts)
	parts.append(["Pouso lunar", landing, 30.0, "Pouso seguro na tentativa %d." % ms.landing_attempts if landed else "Não pousou."])
	var home := 0.0
	if ms.splashdown:
		home = maxf(5.0, 15.0 - 5.0 * ms.reentry_attempts)
	parts.append(["Retorno e amerissagem", home, 15.0, "Amerissagem confirmada." if ms.splashdown else "A cápsula não chegou à água."])
	var issues := ms.day_issues().size()
	for id: String in ms.jumps:
		if not ms.jumps[id]["ok"]:
			issues += 1
	if not ms.departure.is_empty() and not ms.departure["ok"]:
		issues += 1
	var reached := ms.sealed.size() + ms.jumps.size()
	var supplies := 0.0
	if reached > 0:
		supplies = maxf(0.0, 15.0 * reached / 8.0 - 4.0 * issues)
	if issues > 0:
		tips.append("Coma e beba uma cota por dia, não consuma além do necessário e leve margem acima das 8 cotas para perdas.")
	parts.append(["Suprimentos", supplies, 15.0, "%d de 8 etapas de consumo cumpridas, %d falha(s)." % [reached, issues]])
	var science := minf(20.0, ms.science_collected / 70.0 * 20.0)
	var sci_text := "%.0f pontos de dados científicos." % ms.science_collected
	if ms.science_multiplier < 1.0:
		sci_text += " Parte dos dados foi perdida em eventos (%.0f%% aproveitado)." % (ms.science_multiplier * 100.0)
	if landed and ms.science_collected < 50.0:
		tips.append("Pouca ciência: instrumentos passivos e leves (retrorrefletor, coletor de vento solar, kit de amostras) rendem dados sem gastar energia.")
	parts.append(["Resultados científicos", science, 20.0, sci_text])
	var correct := 0
	for d in ms.decisions:
		if d["correct"]:
			correct += 1
	var dec_score := 10.0 * correct / maxi(ms.decisions.size(), 1)
	parts.append(["Decisões operacionais", dec_score, 10.0, "%d de %d escolhas adequadas." % [correct, ms.decisions.size()]])
	if correct < ms.decisions.size():
		tips.append("Releia as explicações das escolhas arriscadas abaixo: elas mostram a opção mais segura.")
	var sps := clampf(ms.sps_fuel / 30.0, 0.0, 1.0) * 10.0
	parts.append(["Propelente do CSM", sps, 10.0, "%.0f%% restante." % ms.sps_fuel])
	if ms.integrity < 80.0 or ms.life_support < 80.0:
		tips.append("A nave terminou com sistemas desgastados (integridade %.0f%%, suporte à vida %.0f%%)." % [ms.integrity, ms.life_support])
	if ms.separation_attempts > 1:
		tips.append("A TLI precisou de %d tentativas. Espere o ponteiro entrar na faixa verde antes de apertar ESPAÇO." % ms.separation_attempts)
	var score := 0.0
	for p in parts:
		score += p[1]
	if not verdict["success"]:
		score = minf(score, 59.0)
	if tips.is_empty():
		tips.append("Missão exemplar! Tente a próxima dificuldade, com orçamento menor.")
	var grade := "A" if score >= 85 else ("B" if score >= 70 else ("C" if score >= 55 else "D"))
	return {"score": score, "grade": grade, "parts": parts, "tips": tips, "landed": landed, "verdict": verdict}


func _ready() -> void:
	Sound.enter_scene("report")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Control.new()
	bg.set_script(STARFIELD)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var result := evaluate()
	root.add_child(Game.make_label("RELATÓRIO DA MISSÃO · %s" % MissionState.settings()["name"], 28, Game.AMBER))
	var verdict: Dictionary = result["verdict"]
	root.add_child(Game.make_label("%s · PONTUAÇÃO %.0f/100 · CONCEITO %s" % [
		verdict["title"].to_upper(), result["score"], result["grade"]], 22,
		Game.GOOD if verdict["success"] else Game.BAD))
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 16)
	root.add_child(text)
	text.text = _report_text(result)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	root.add_child(buttons)
	var again := Button.new()
	again.text = "NOVA MISSÃO"
	again.custom_minimum_size = Vector2(220, 44)
	again.pressed.connect(func(): Game.go("menu"))
	buttons.add_child(again)
	var quit := Button.new()
	quit.text = "SAIR"
	quit.custom_minimum_size = Vector2(160, 44)
	quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit)
	again.grab_focus()


func _report_text(result: Dictionary) -> String:
	var ms := MissionState
	var verdict: Dictionary = result["verdict"]
	var t := "[b]%s[/b]\n" % verdict["summary"]
	if not verdict["causes"].is_empty():
		t += "\n[color=#ff8866]POR QUE A MISSÃO FALHOU[/color]\n"
		for cause in verdict["causes"]:
			t += "• %s\n" % cause
	t += "\n[color=#f5bd5c]PONTUAÇÃO POR ÁREA[/color]\n"
	for p in result["parts"]:
		var ratio: float = p[1] / p[2]
		var color := "#77ee77" if ratio >= 0.8 else ("#ffcc44" if ratio >= 0.4 else "#ff6655")
		t += "[color=%s]%5.1f / %2.0f[/color]  %s — %s\n" % [color, p[1], p[2], p[0], p[3]]
	if not verdict["success"]:
		t += "[color=#bbbbbb]Com a missão falha, a nota fica abaixo de 60.[/color]\n"
	t += "\n[color=#f5bd5c]O QUE MELHORARIA A PRÓXIMA TENTATIVA[/color]\n"
	for tip in result["tips"]:
		t += "• %s\n" % tip
	t += _landing_block() + _supplies_block() + _return_block() + _reentry_block()
	t += "\n[color=#f5bd5c]DECISÕES E DADOS CIENTÍFICOS[/color]\n"
	t += "Ciência potencial dos instrumentos: %.0f · registrada: %.0f\n" % [ms.science_potential(), ms.science_collected]
	for d in ms.decisions:
		var tag := ""
		if d.get("correct", false) and not d.get("favorable", true):
			tag = " [color=#ffcc44](complicação)[/color]"
		elif not d.get("correct", false) and d.get("favorable", false):
			tag = " [color=#ffcc44](deu sorte)[/color]"
		t += "%s [b]%s[/b]: %s%s\n   [color=#bbbbbb]%s[/color]\n" % ["[color=#77ee77]✔[/color]" if d["correct"] else "[color=#ff6655]✖[/color]", d["title"], d["choice"], tag, d["explanation"]]
	var tasks := ms.cabin_minigame_report()
	t += "\n[color=#f5bd5c]TAREFAS OPCIONAIS DA TRIPULAÇÃO · %d/%d pontos[/color]\n" % [tasks["points"], tasks["possible"]]
	for row: Dictionary in tasks["rows"]:
		t += "• %s — %s (%d pontos)\n" % [row["title"], row["status"], row["points"]]
	t += "\n[color=#f5bd5c]EVENTOS[/color]\n"
	for e in ms.events:
		t += "• %s: %s\n" % [e["title"], e["outcome"]]
	t += "\n[color=#f5bd5c]PLANEJAMENTO INICIAL[/color]\n"
	t += "Orçamento usado: US$ %.1f de %.1f mi · Massa: %.0f de %.0f kg\n" % [ms.plan_cost(), ms.settings()["budget"], ms.plan_mass(), ms.settings()["mass_limit"]]
	var carried := []
	for id in ms.cargo:
		if ms.qty(id) > 0:
			carried.append("%s ×%d" % [ms.items[id]["name"], ms.qty(id)])
	t += "Carga: " + ", ".join(PackedStringArray(carried)) + "\n"
	if ms.splashdown:
		t += "\nTempo nominal de referência da Apollo 11: %s, comprimido em %d dias jogáveis e 3 saltos." % [ms.REFERENCE_DURATION, ms.PLAY_DAYS]
	t += "\n[color=#888888]Missão fictícia inspirada no programa Apollo. Números marcados como simplificação no planejamento são valores de jogo.[/color]"
	return t


func _landing_block() -> String:
	var ms := MissionState
	var t := "\n[color=#f5bd5c]POUSO LUNAR[/color]\n"
	if ms.landing_result.get("success", false):
		var r: Dictionary = ms.landing_result
		t += "Pouso lunar confirmado na tentativa %d. V.vert %.1f m/s · V.horiz %.1f m/s · inclinação %.0f° · %.1f s de propelente sobrando · %.0f m do alvo\n" % [ms.landing_attempts, r["vy"], r["vh"], r["tilt"], r["fuel_left"], r["distance"]]
	elif ms.landing_attempts > 0:
		t += "Tentativa falhou (%d tentativas).\n" % ms.landing_attempts
	else:
		t += "Não alcançado.\n"
	if ms.landing_history.size() > 1:
		var failed := ms.landing_history.filter(func(a): return not a["success"])
		if not failed.is_empty():
			t += "[color=#bbbbbb]Última tentativa com falha: %s[/color]\n" % failed.back()["reasons"][0]
	return t


func _supplies_block() -> String:
	var ms := MissionState
	var t := "\n[color=#f5bd5c]SUPRIMENTOS[/color]\n"
	for kind: String in ms.SUPPLY_KINDS:
		var name := "Comida" if kind == "food" else "Água"
		var manual := ms.food_eaten if kind == "food" else ms.water_drunk
		var jumped := ms.jump_food if kind == "food" else ms.jump_water
		var lost := ms.lost_food if kind == "food" else ms.lost_water
		t += "%s: carga %d · consumo manual %s · saltos %s · perdas %s · saldo %s\n" % [name, ms.qty(kind + "_day"),
			ms.amount_text(manual), ms.amount_text(jumped), ms.amount_text(lost), ms.amount_text(ms.stock(kind))]
	var days := []
	for d in range(1, ms.PLAY_DAYS + 1):
		var key := str(d)
		if ms.sealed.has(key):
			var sd: Dictionary = ms.sealed[key]
			days.append("Dia %d: %d comida, %d água%s" % [d, sd["food"], sd["water"], "" if sd["missing"].is_empty() else " [color=#ff8866](faltou)[/color]"])
		elif d <= ms.day and ms.stage != "report":
			days.append("Dia %d: em aberto" % d)
		else:
			days.append("Dia %d: não alcançado" % d)
	t += "\n".join(PackedStringArray(days)) + "\n"
	for id: String in ["A", "B", "C"]:
		if ms.jumps.has(id):
			t += "Salto %s · %s: %s\n" % [id, ms.JUMPS[id]["title"], ms.jump_text(id)]
		else:
			t += "Salto %s · %s: não alcançado\n" % [id, ms.JUMPS[id]["title"]]
	for loss: Dictionary in ms.losses:
		t += "Perda: %s cota de %s · %s (dia %d)\n" % [ms.amount_text(loss["amount"]), "comida" if loss["kind"] == "food" else "água", loss["cause"], loss["day"]]
	return t


func _return_block() -> String:
	var ms := MissionState
	var t := "\n[color=#f5bd5c]RETORNO À TERRA[/color]\n"
	if ms.departure.is_empty():
		t += "Reserva verificada na partida: não alcançada.\n"
		return t
	var d := ms.departure
	t += "Reserva verificada na partida: comida %s/%d · água %s/%d\n" % [ms.amount_text(d["food"]), ms.DEPARTURE_RESERVE, ms.amount_text(d["water"]), ms.DEPARTURE_RESERVE]
	if d["ok"]:
		t += "[color=#77ee77]Partida aprovada.[/color]\n"
	else:
		t += "[color=#ff8866]Partida bloqueada. %s[/color]\n" % ms.departure_text()
	return t


func _reentry_block() -> String:
	var ms := MissionState
	var t := "\n[color=#f5bd5c]REENTRADA E AMERISSAGEM[/color]\n"
	if ms.reentry_history.is_empty():
		t += "Não alcançada.\n" if ms.departure.get("ok", false) == false or not ms.jumps.has("C") else "Em aberto.\n"
		return t
	var last: Dictionary = ms.reentry_history.back()
	if last["success"]:
		t += "Paraquedas abertos a %.0f m, %.2f s depois da abertura da janela.\n" % [last["altitude"], last["time"]]
		t += "Amerissagem confirmada.\n" if ms.splashdown else "Paraquedas abertos, toque na água não registrado.\n"
	else:
		t += "Tentativa falhou: janela de abertura dos paraquedas perdida.\n"
	if ms.reentry_history.size() > 1:
		t += "[color=#bbbbbb]%d tentativas de reentrada.[/color]\n" % ms.reentry_history.size()
	return t
