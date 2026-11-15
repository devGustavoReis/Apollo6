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
			tips.append(str(TranslationServer.translate("O pouso levou %d tentativas. Segure ESPAÇO mais cedo e elimine o deslizamento no alto.")) % ms.landing_attempts)
	parts.append([str(TranslationServer.translate("Pouso lunar")), landing, 30.0, str(TranslationServer.translate("Pouso seguro na tentativa %d.")) % ms.landing_attempts if landed else str(TranslationServer.translate("Não pousou."))])
	var home := 0.0
	if ms.splashdown:
		home = maxf(5.0, 15.0 - 5.0 * ms.reentry_attempts)
	parts.append([str(TranslationServer.translate("Retorno e amerissagem")), home, 15.0, str(TranslationServer.translate("Amerissagem confirmada.")) if ms.splashdown else str(TranslationServer.translate("A cápsula não chegou à água."))])
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
		tips.append(str(TranslationServer.translate("Coma e beba uma cota por dia, não consuma além do necessário e leve margem acima das 8 cotas para perdas.")))
	parts.append([str(TranslationServer.translate("Suprimentos")), supplies, 15.0, str(TranslationServer.translate("%d de 8 etapas de consumo cumpridas, %d falha(s).")) % [reached, issues]])
	var science := 20.0 * ms.science_multiplier if ms.science_completed else 0.0
	var sci_text := str(TranslationServer.translate("Objetivo pendente."))
	if ms.OBJECTIVES.has(ms.objective):
		sci_text = str(TranslationServer.translate(ms.OBJECTIVES[ms.objective]["title"])) + " · " + (str(TranslationServer.translate(ms.OBJECTIVES[ms.objective]["evidence"])) if ms.science_completed else str(TranslationServer.translate("Atividade não realizada.")))
		if ms.science_completed and ms.objective != "retroreflector":
			sci_text += str(TranslationServer.translate(" Retorno confirmado.")) if ms.splashdown else str(TranslationServer.translate("Evidência ainda não recuperada na Terra."))
	if ms.science_multiplier < 1.0:
		sci_text += str(TranslationServer.translate(" Parte dos dados foi perdida em eventos (%.0f%% aproveitado).")) % (ms.science_multiplier * 100.0)
	if landed and not ms.science_completed:
		tips.append(str(TranslationServer.translate("Conclua a atividade do instrumento escolhido depois do pouso para obter os resultados científicos.")))
	parts.append([str(TranslationServer.translate("Resultados científicos")), science, 20.0, sci_text])
	var correct := 0
	for d in ms.decisions:
		if d["correct"]:
			correct += 1
	var dec_score := 10.0 * correct / maxi(ms.decisions.size(), 1)
	parts.append([str(TranslationServer.translate("Decisões operacionais")), dec_score, 10.0, str(TranslationServer.translate("%d de %d escolhas adequadas.")) % [correct, ms.decisions.size()]])
	if correct < ms.decisions.size():
		tips.append(str(TranslationServer.translate("Releia as explicações das escolhas arriscadas abaixo: elas mostram a opção mais segura.")))
	var sps := clampf(ms.sps_fuel / 30.0, 0.0, 1.0) * 10.0
	parts.append([str(TranslationServer.translate("Propelente do CSM")), sps, 10.0, str(TranslationServer.translate("%.0f%% restante.")) % ms.sps_fuel])
	if ms.integrity < 80.0 or ms.life_support < 80.0:
		tips.append(str(TranslationServer.translate("A nave terminou com sistemas desgastados (integridade %.0f%%, suporte à vida %.0f%%).")) % [ms.integrity, ms.life_support])
	if ms.separation_attempts > 1:
		tips.append(str(TranslationServer.translate("A TLI precisou de %d tentativas. Mantenha o nariz no anel e aperte ESPAÇO quando o painel avisar ALINHAMENTO CONFIRMADO.")) % ms.separation_attempts)
	if ms.ended.get("stage", "") == "survival":
		tips.append(str(TranslationServer.translate("Fique de olho nas barras FOME e SEDE: coma antes de dormir e, se acordar em estado crítico, coma e beba nos primeiros 10 s.")))
	var score := 0.0
	for p in parts:
		score += p[1]
	if not verdict["success"]:
		score = minf(score, 59.0)
	if tips.is_empty():
		if verdict["success"]:
			tips.append(str(TranslationServer.translate("Missão exemplar! Tente a próxima dificuldade, com menos armazenamento.")))
		else:
			tips.append(str(TranslationServer.translate("Leia os motivos da falha acima e tente de novo a partir da etapa em que a missão parou.")))
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
	root.add_child(Game.make_label(str(TranslationServer.translate("RELATÓRIO DA MISSÃO · %s")) % MissionState.settings()["name"], 28, Game.AMBER))
	var verdict: Dictionary = result["verdict"]
	root.add_child(Game.make_label(str(TranslationServer.translate("%s · PONTUAÇÃO %.0f/100 · CONCEITO %s")) % [
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
	again.text = str(TranslationServer.translate("NOVA MISSÃO"))
	again.custom_minimum_size = Vector2(220, 44)
	again.pressed.connect(func(): Game.go("menu"))
	buttons.add_child(again)
	var quit := Button.new()
	quit.text = str(TranslationServer.translate("SAIR"))
	quit.custom_minimum_size = Vector2(160, 44)
	quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit)
	again.grab_focus()


func _report_text(result: Dictionary) -> String:
	var ms := MissionState
	var verdict: Dictionary = result["verdict"]
	var t := "[b]%s[/b]\n" % tr(verdict["summary"])
	if not verdict["causes"].is_empty():
		t += str(TranslationServer.translate("\n[color=#ff8866]POR QUE A MISSÃO FALHOU[/color]\n"))
		for cause in verdict["causes"]:
			t += "• %s\n" % tr(cause)
	t += str(TranslationServer.translate("\n[color=#f5bd5c]PONTUAÇÃO POR ÁREA[/color]\n"))
	for p in result["parts"]:
		var ratio: float = p[1] / p[2]
		var color := "#77ee77" if ratio >= 0.8 else ("#ffcc44" if ratio >= 0.4 else "#ff6655")
		t += "[color=%s]%5.1f / %2.0f[/color]  %s — %s\n" % [color, p[1], p[2], tr(p[0]), tr(p[3])]
	if not verdict["success"]:
		t += str(TranslationServer.translate("[color=#bbbbbb]Com a missão falha, a nota fica abaixo de 60.[/color]\n"))
	t += str(TranslationServer.translate("\n[color=#f5bd5c]O QUE MELHORARIA A PRÓXIMA TENTATIVA[/color]\n"))
	for tip in result["tips"]:
		t += "• %s\n" % tr(tip)
	t += _landing_block() + _supplies_block() + _return_block() + _reentry_block()
	t += str(TranslationServer.translate("\n[color=#f5bd5c]DECISÕES E DADOS CIENTÍFICOS[/color]\n"))
	t += str(TranslationServer.translate("Ciência potencial dos instrumentos: %.0f · registrada: %.0f\n")) % [ms.science_potential(), ms.science_collected]
	for d in ms.decisions:
		var tag := ""
		if d.get("correct", false) and not d.get("favorable", true):
			tag = str(TranslationServer.translate(" [color=#ffcc44](complicação)[/color]"))
		elif not d.get("correct", false) and d.get("favorable", false):
			tag = str(TranslationServer.translate(" [color=#ffcc44](deu sorte)[/color]"))
		t += "%s [b]%s[/b]: %s%s\n   [color=#bbbbbb]%s[/color]\n" % ["[color=#77ee77]✔[/color]" if d["correct"] else "[color=#ff6655]✖[/color]", tr(d["title"]), tr(d["choice"]), tag, tr(d["explanation"])]
	var tasks := ms.cabin_minigame_report()
	t += str(TranslationServer.translate("\n[color=#f5bd5c]TAREFAS OPCIONAIS DA TRIPULAÇÃO · %d/%d pontos[/color]\n")) % [tasks["points"], tasks["possible"]]
	for row: Dictionary in tasks["rows"]:
		t += str(TranslationServer.translate("• %s — %s (%d pontos)\n")) % [tr(row["title"]), tr(row["status"]), row["points"]]
	t += str(TranslationServer.translate("\n[color=#f5bd5c]EVENTOS[/color]\n"))
	for e in ms.events:
		t += "• %s: %s\n" % [tr(e["title"]), tr(e["outcome"])]
	t += str(TranslationServer.translate("\n[color=#f5bd5c]PLANEJAMENTO INICIAL[/color]\n"))
	t += str(TranslationServer.translate("Armazenamento usado: %d de %d itens · Massa: %.0f de %.0f kg\n")) % [ms.plan_items(), int(ms.settings()["storage"]), ms.plan_mass(), ms.settings()["mass_limit"]]
	var carried := []
	for id in ms.cargo:
		if ms.qty(id) > 0:
			carried.append("%s ×%d" % [ms.items[id]["name"], ms.qty(id)])
	t += str(TranslationServer.translate("Carga: ")) + ", ".join(PackedStringArray(carried)) + "\n"
	if ms.splashdown:
		t += str(TranslationServer.translate("\nTempo nominal de referência da Apollo 11: %s, comprimido em %d dias jogáveis e 3 saltos.")) % [str(TranslationServer.translate(ms.REFERENCE_DURATION)), ms.PLAY_DAYS]
	t += str(TranslationServer.translate("\n[color=#888888]Missão fictícia inspirada no programa Apollo. Números marcados como simplificação no planejamento são valores de jogo.[/color]"))
	return t


func _landing_block() -> String:
	var ms := MissionState
	var t := str(TranslationServer.translate("\n[color=#f5bd5c]POUSO LUNAR[/color]\n"))
	if ms.landing_result.get("success", false):
		var r: Dictionary = ms.landing_result
		t += str(TranslationServer.translate("Pouso lunar confirmado na tentativa %d. V.vert %.1f m/s · V.horiz %.1f m/s · inclinação %.0f° · %.1f s de propelente sobrando · %.0f m do alvo\n")) % [ms.landing_attempts, r["vy"], r["vh"], r["tilt"], r["fuel_left"], r["distance"]]
	elif ms.landing_attempts > 0:
		t += str(TranslationServer.translate("Tentativa falhou (%d tentativas).\n")) % ms.landing_attempts
	else:
		t += str(TranslationServer.translate("Não alcançado.\n"))
	if ms.landing_history.size() > 1:
		var failed := ms.landing_history.filter(func(a): return not a["success"])
		if not failed.is_empty():
			t += str(TranslationServer.translate("[color=#bbbbbb]Última tentativa com falha: %s[/color]\n")) % failed.back()["reasons"][0]
	return t


func _supplies_block() -> String:
	var ms := MissionState
	var t := str(TranslationServer.translate("\n[color=#f5bd5c]SUPRIMENTOS[/color]\n"))
	for kind: String in ms.SUPPLY_KINDS:
		var name := str(TranslationServer.translate("Comida")) if kind == "food" else str(TranslationServer.translate("Água"))
		var manual := ms.food_eaten if kind == "food" else ms.water_drunk
		var jumped := ms.jump_food if kind == "food" else ms.jump_water
		var lost := ms.lost_food if kind == "food" else ms.lost_water
		t += str(TranslationServer.translate("%s: carga %d · consumo manual %s · saltos %s · perdas %s · saldo %s\n")) % [name, ms.qty(kind + "_day"),
			ms.amount_text(manual), ms.amount_text(jumped), ms.amount_text(lost), ms.amount_text(ms.stock(kind))]
	var days := []
	for d in range(1, ms.PLAY_DAYS + 1):
		var key := str(d)
		if ms.sealed.has(key):
			var sd: Dictionary = ms.sealed[key]
			days.append(str(TranslationServer.translate("Dia %d: %d comida, %d água%s")) % [d, sd["food"], sd["water"], "" if sd["missing"].is_empty() else str(TranslationServer.translate(" [color=#ff8866](faltou)[/color]"))])
		elif d <= ms.day and ms.stage != "report":
			days.append(str(TranslationServer.translate("Dia %d: em aberto")) % d)
		else:
			days.append(str(TranslationServer.translate("Dia %d: não alcançado")) % d)
	t += "\n".join(PackedStringArray(days)) + "\n"
	for id: String in ["A", "B", "C"]:
		if ms.jumps.has(id):
			t += str(TranslationServer.translate("Salto %s · %s: %s\n")) % [id, str(TranslationServer.translate(ms.JUMPS[id]["title"])), ms.jump_text(id)]
		else:
			t += str(TranslationServer.translate("Salto %s · %s: não alcançado\n")) % [id, str(TranslationServer.translate(ms.JUMPS[id]["title"]))]
	for loss: Dictionary in ms.losses:
		t += str(TranslationServer.translate("Perda: %s cota de %s · %s (dia %d)\n")) % [ms.amount_text(loss["amount"]), str(TranslationServer.translate("comida")) if loss["kind"] == "food" else str(TranslationServer.translate("água")), loss["cause"], loss["day"]]
	return t


func _return_block() -> String:
	var ms := MissionState
	var t := str(TranslationServer.translate("\n[color=#f5bd5c]RETORNO À TERRA[/color]\n"))
	if ms.departure.is_empty():
		t += str(TranslationServer.translate("Reserva verificada na partida: não alcançada.\n"))
		return t
	var d := ms.departure
	t += str(TranslationServer.translate("Reserva verificada na partida: comida %s/%d · água %s/%d\n")) % [ms.amount_text(d["food"]), ms.DEPARTURE_RESERVE, ms.amount_text(d["water"]), ms.DEPARTURE_RESERVE]
	if d["ok"]:
		t += str(TranslationServer.translate("[color=#77ee77]Partida aprovada.[/color]\n"))
	else:
		t += str(TranslationServer.translate("[color=#ff8866]Partida bloqueada. %s[/color]\n")) % ms.departure_text()
	return t


func _reentry_block() -> String:
	var ms := MissionState
	var t := str(TranslationServer.translate("\n[color=#f5bd5c]REENTRADA E AMERISSAGEM[/color]\n"))
	if ms.reentry_history.is_empty():
		t += str(TranslationServer.translate("Não alcançada.\n")) if ms.departure.get("ok", false) == false or not ms.jumps.has("C") else str(TranslationServer.translate("Em aberto.\n"))
		return t
	var last: Dictionary = ms.reentry_history.back()
	if last.has("stabilization"):
		t += str(TranslationServer.translate("Estabilidade antes dos paraquedas: %d%%.\n")) % roundi(float(last["stabilization"]) * 100.0)
	if last["success"]:
		t += str(TranslationServer.translate("Paraquedas abertos a %.0f m, %.2f s depois da abertura da janela.\n")) % [last["altitude"], last["time"]]
		t += str(TranslationServer.translate("Amerissagem confirmada.\n")) if ms.splashdown else str(TranslationServer.translate("Paraquedas abertos, toque na água não registrado.\n"))
	else:
		t += str(TranslationServer.translate("Tentativa falhou: janela de abertura dos paraquedas perdida.\n"))
	if ms.reentry_history.size() > 1:
		t += str(TranslationServer.translate("[color=#bbbbbb]%d tentativas de reentrada.[/color]\n")) % ms.reentry_history.size()
	return t
