extends Control
## Relatório final educativo: pontuação explicada e sugestões para a próxima tentativa.

const STARFIELD := preload("res://scripts/ui/starfield.gd")


static func evaluate() -> Dictionary:
	var ms := MissionState
	var landed: bool = ms.landing_result.get("success", false)
	var parts := []
	var tips := []
	# Pouso: 35 pontos, -5 por tentativa extra.
	var landing := 0.0
	if landed:
		landing = maxf(15.0, 35.0 - 5.0 * (ms.landing_attempts - 1))
		if ms.landing_attempts > 1:
			tips.append("O pouso levou %d tentativas. Elimine o deslizamento no alto e chegue aos últimos 20 m já descendo devagar." % ms.landing_attempts)
	parts.append(["Pouso lunar", landing, 35.0, "Pouso seguro na tentativa %d." % ms.landing_attempts if landed else "Não pousou."])
	# Ciência: 25 pontos.
	var science := minf(25.0, ms.science_collected / 70.0 * 25.0)
	var sci_text := "%.0f pontos de dados científicos." % ms.science_collected
	if ms.science_multiplier < 1.0:
		sci_text += " Parte dos dados foi perdida em eventos (%.0f%% aproveitado)." % (ms.science_multiplier * 100.0)
	if ms.science_collected < 50.0:
		tips.append("Pouca ciência: instrumentos passivos e leves (retrorrefletor, coletor de vento solar, kit de amostras) rendem dados sem gastar energia.")
	parts.append(["Resultados científicos", science, 25.0, sci_text])
	# Suprimentos: 15 pontos.
	var needed := float(ms.MISSION_DAYS - ms.food_eaten)
	var food_margin := ms.food_days - needed
	var water_margin := ms.water_days - needed
	var supplies := 0.0
	supplies += 7.5 if food_margin >= 0.0 else maxf(0.0, 7.5 + food_margin * 4.0)
	supplies += 7.5 if water_margin >= 0.0 else maxf(0.0, 7.5 + water_margin * 4.0)
	var sup_text := "Comida: %.1f dias para %.0f necessários. Água: %.1f dias para %.0f necessários." % [ms.food_days, needed, ms.water_days, needed]
	if water_margin < 0.0 or food_margin < 0.0:
		tips.append("Os suprimentos não cobrem a volta: a tripulação teria de racionar. Leve 1 ou 2 dias de reserva de comida e água.")
	parts.append(["Suprimentos para a volta", supplies, 15.0, sup_text])
	# Propelente do CSM: 10 pontos.
	var sps := clampf((ms.sps_fuel - 10.0) / 40.0, 0.0, 1.0) * 10.0
	if ms.sps_fuel < 30.0:
		tips.append("Pouco propelente no CSM para voltar à Terra. Corte a TLI na faixa verde e corrija a rota cedo.")
	parts.append(["Propelente do CSM para o retorno", sps, 10.0, "%.0f%% restante após a inserção em órbita lunar." % ms.sps_fuel])
	# Decisões: 15 pontos.
	var correct := 0
	for d in ms.decisions:
		if d["correct"]:
			correct += 1
	var total := maxi(ms.decisions.size(), 1)
	var dec_score := 15.0 * correct / total
	parts.append(["Decisões operacionais", dec_score, 15.0, "%d de %d decisões adequadas." % [correct, ms.decisions.size()]])
	if correct < ms.decisions.size():
		tips.append("Releia as explicações das decisões ruins abaixo: elas mostram a escolha mais segura.")
	if ms.integrity < 80.0 or ms.life_support < 80.0:
		tips.append("A nave terminou com sistemas desgastados (integridade %.0f%%, suporte à vida %.0f%%)." % [ms.integrity, ms.life_support])
	var score := 0.0
	for p in parts:
		score += p[1]
	if ms.separation_attempts > 1:
		tips.append("A TLI precisou de %d tentativas. Espere o ponteiro entrar na faixa verde antes de apertar ESPAÇO." % ms.separation_attempts)
	if tips.is_empty():
		tips.append("Missão exemplar! Tente a próxima dificuldade, com orçamento menor.")
	var grade := "A" if score >= 85 else ("B" if score >= 70 else ("C" if score >= 55 else "D"))
	return {"score": score, "grade": grade, "parts": parts, "tips": tips, "landed": landed}


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
	root.add_child(Game.make_label("%s · PONTUAÇÃO %.0f/100 · CONCEITO %s" % [
		"OBJETIVO PRINCIPAL CUMPRIDO" if result["landed"] else "OBJETIVO NÃO CUMPRIDO", result["score"], result["grade"]], 22,
		Game.GOOD if result["landed"] else Game.BAD))
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
	var t := "[color=#f5bd5c]PONTUAÇÃO POR ÁREA[/color]\n"
	for p in result["parts"]:
		var ratio: float = p[1] / p[2]
		var color := "#77ee77" if ratio >= 0.8 else ("#ffcc44" if ratio >= 0.4 else "#ff6655")
		t += "[color=%s]%5.1f / %2.0f[/color]  %s — %s\n" % [color, p[1], p[2], p[0], p[3]]
	t += "\n[color=#f5bd5c]O QUE MELHORARIA A PRÓXIMA TENTATIVA[/color]\n"
	for tip in result["tips"]:
		t += "• %s\n" % tip
	t += "\n[color=#f5bd5c]PLANEJAMENTO INICIAL[/color]\n"
	t += "Orçamento usado: US$ %.1f de %.1f mi · Massa: %.0f de %.0f kg\n" % [ms.plan_cost(), ms.settings()["budget"], ms.plan_mass(), ms.settings()["mass_limit"]]
	var carried := []
	for id in ms.cargo:
		if ms.qty(id) > 0:
			carried.append("%s ×%d" % [ms.items[id]["name"], ms.qty(id)])
	t += "Carga: " + ", ".join(PackedStringArray(carried)) + "\n"
	t += "Comida consumida: %.0f dias · Água consumida: %.0f dias\n" % [ms.food_eaten, ms.water_drunk]
	if ms.landing_result.get("success", false):
		var r: Dictionary = ms.landing_result
		t += "Pouso: V.vert %.1f m/s · V.horiz %.1f m/s · inclinação %.0f° · %.0f s de propelente sobrando · %.0f m do alvo\n" % [r["vy"], r["vh"], r["tilt"], r["fuel_left"], r["distance"]]
	var tasks := ms.cabin_minigame_report()
	t += "\n[color=#f5bd5c]TAREFAS DA TRIPULAÇÃO · %d/%d pontos[/color]\n" % [tasks["points"], tasks["possible"]]
	for row: Dictionary in tasks["rows"]:
		t += "• %s — %s (%d pontos)\n" % [row["title"], row["status"], row["points"]]
	t += "\n[color=#f5bd5c]DECISÕES[/color]\n"
	for d in ms.decisions:
		t += "%s [b]%s[/b]: %s\n   [color=#bbbbbb]%s[/color]\n" % ["[color=#77ee77]✔[/color]" if d["correct"] else "[color=#ff6655]✖[/color]", d["title"], d["choice"], d["explanation"]]
	t += "\n[color=#f5bd5c]EVENTOS[/color]\n"
	for e in ms.events:
		t += "• %s: %s\n" % [e["title"], e["outcome"]]
	t += "\n[color=#888888]Missão fictícia inspirada no programa Apollo. Números marcados como simplificação no planejamento são valores de jogo.[/color]"
	return t
