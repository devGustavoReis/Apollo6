class_name MissionDecisions
extends RefCounted
## Decisões operacionais e eventos da viagem.
## Qualidade da escolha, execução do jogador e resultado operacional são separados.
## Escolha boa: 95% de desfecho favorável. Escolha ruim: 5%. Ver docs/gameplay_prototype.md.

const GOOD_CHANCE := 0.95
const BAD_CHANCE := 0.05
const SMALL_ERROR := 0.12


static func midcourse_cost() -> float:
	return 2.0 + 10.0 * MissionState.trajectory_error


static func return_cost() -> float:
	return 2.0 + 10.0 * MissionState.return_error


static func error_size(e: float) -> String:
	if e < SMALL_ERROR:
		return "pequeno"
	if e < 0.5:
		return "moderado"
	return "grande"


static func get_decision(id: String) -> Dictionary:
	var ms := MissionState
	match id:
		"midcourse":
			var e := ms.trajectory_error
			var cost := midcourse_cost()
			return {
				"title": str(TranslationServer.translate("CORREÇÃO DE ROTA · IDA")),
				"body": str(TranslationServer.translate("O desvio deixado pela injeção translunar é [b]%s[/b] (%.0f%%). A tolerância é de %.0f%%.\nUm desvio pequeno cresce com a distância: corrigir cedo custa menos.\nO computador de navegação calcula a queima e o motor a executa.\n\nPropelente do CSM: %.0f%%")) % [error_size(e), e * 100.0, SMALL_ERROR * 100.0, ms.sps_fuel],
				"options": [
					str(TranslationServer.translate("Corrigir agora com o computador (custo previsto: %.1f%%)")) % cost,
					str(TranslationServer.translate("Esperar e corrigir amanhã (custo estimado: %.1f%%)")) % (cost * 2.0),
					str(TranslationServer.translate("Manter o rumo sem corrigir")),
				],
			}
		"return_course":
			var e := ms.return_error
			var cost := return_cost()
			return {
				"title": str(TranslationServer.translate("CORREÇÃO DE ROTA · VOLTA")),
				"body": str(TranslationServer.translate("A queima de partida da Lua deixou um desvio [b]%s[/b] (%.0f%%). A tolerância é de %.0f%%.\nA cápsula precisa chegar à Terra num corredor estreito de reentrada.\nA Apollo 11 fez uma pequena correção de rota na volta.\n\nPropelente do CSM: %.0f%%")) % [error_size(e), e * 100.0, SMALL_ERROR * 100.0, ms.sps_fuel],
				"options": [
					str(TranslationServer.translate("Corrigir pilotando a nave (custo mínimo: %.1f%%)")) % cost,
					str(TranslationServer.translate("Manter o rumo sem corrigir")),
				],
			}
		"power":
			var over := ms.power_use() > ms.power_capacity
			var text := ""
			if over:
				text = str(TranslationServer.translate("Os instrumentos consomem [b]%.0f W[/b], acima dos [b]%.0f W[/b] disponíveis. A tensão do barramento está caindo.")) % [ms.power_use(), ms.power_capacity]
			else:
				text = str(TranslationServer.translate("Um aquecedor travou ligado e está consumindo energia extra. A margem elétrica está quase no fim."))
			var battery := ms.qty("battery_pack") > 0 and not ms.battery_used
			return {
				"title": str(TranslationServer.translate("ALERTA DE ENERGIA")),
				"body": text + "\nBateria auxiliar: [b]%s[/b].\n\nO que fazer?" % (str(TranslationServer.translate("disponível")) if battery else str(TranslationServer.translate("não disponível"))),
				"options": [
					str(TranslationServer.translate("Desligar temporariamente um instrumento científico não essencial")),
					"Manter todos os equipamentos ligados",
					str(TranslationServer.translate("Desligar o suporte à vida por algumas horas")),
				],
			}
		"comm_dropout":
			return {
				"title": str(TranslationServer.translate("FALHA DE COMUNICAÇÃO")),
				"body": str(TranslationServer.translate("A antena de alto ganho perdeu o alinhamento com a Terra. Houston recebe só chiado, e a reentrada se aproxima.")),
				"options": [
					str(TranslationServer.translate("Trocar para as antenas omnidirecionais e realinhar a de alto ganho")),
					str(TranslationServer.translate("Esperar o sinal voltar sozinho")),
					str(TranslationServer.translate("Desligar o rádio para economizar energia")),
				],
			}
		"water_leak":
			return {
				"title": str(TranslationServer.translate("VAZAMENTO DE ÁGUA")),
				"body": str(TranslationServer.translate("Uma válvula do reservatório de água está vazando. Reserva atual: [b]%s cotas[/b].")) % ms.amount_text(ms.water_days),
				"options": [
					str(TranslationServer.translate("Fechar a válvula e isolar o reservatório afetado")),
					str(TranslationServer.translate("Ignorar por enquanto e continuar as tarefas")),
					str(TranslationServer.translate("Beber o máximo possível agora para não desperdiçar")),
				],
			}
		"ptc":
			return {
				"title": str(TranslationServer.translate("CONTROLE TÉRMICO")),
				"body": str(TranslationServer.translate("Um lado da nave está recebendo Sol direto há horas e esquentando, enquanto o outro esfria demais.\nHouston pede uma solução.")),
				"options": [
					str(TranslationServer.translate("Iniciar uma rotação lenta e contínua da nave (controle térmico passivo)")),
					str(TranslationServer.translate("Manter a nave parada, apontada para o Sol")),
					str(TranslationServer.translate("Fazer giros rápidos com os propulsores")),
				],
			}
	return {}


static func is_good(id: String, option: int) -> bool:
	var ms := MissionState
	match id:
		"midcourse":
			return option == 0 or (option == 2 and ms.trajectory_error < SMALL_ERROR)
		"return_course":
			return option == 0 or ms.return_error < SMALL_ERROR
		"power":
			return option == 0 or (option == 1 and ms.qty("battery_pack") > 0 and not ms.battery_used)
		"comm_dropout", "water_leak", "ptc":
			return option == 0
	return false


static func find(id: String) -> Dictionary:
	for d: Dictionary in MissionState.decisions:
		if d["id"] == id:
			return d
	return {}


## Resolve a decisão uma única vez. Uma segunda chamada devolve o registro já gravado.
static func apply(id: String, option: int, errors := 0) -> Dictionary:
	var previous := find(id)
	if not previous.is_empty():
		return previous
	var ms := MissionState
	var decision := get_decision(id)
	var good := is_good(id, option)
	var chance := GOOD_CHANCE if good else BAD_CHANCE
	var roll := ms.sample()
	var favorable := roll < chance
	var text := _effects(id, option, good, favorable, errors)
	ms.clamp_resources()
	var options: Array = decision.get("options", [])
	var record := {
		"id": id, "title": decision.get("title", id), "choice": options[option] if option < options.size() else "",
		"option": option, "correct": good, "favorable": favorable, "chance": chance, "sample": roll,
		"errors": errors, "explanation": text,
	}
	ms.decisions.append(record)
	ms.changed.emit()
	return record


static func _effects(id: String, option: int, good: bool, favorable: bool, errors: int) -> String:
	var ms := MissionState
	match id:
		"midcourse":
			var cost := midcourse_cost()
			if option == 0:
				var deviation_cost := 1.0 * mini(maxi(errors, 0), 6)
				if favorable:
					ms.sps_fuel -= cost + deviation_cost
					ms.trajectory_error = 0.0
					return str(TranslationServer.translate("Correção executada cedo por %.1f%% de propelente. Desvios de pilotagem acrescentaram %.1f%%.")) % [cost + deviation_cost, deviation_cost]
				ms.sps_fuel -= cost + deviation_cost + 1.5
				ms.trajectory_error *= 0.3
				return str(TranslationServer.translate("Boa escolha, mas a queima ficou um pouco curta e exigiu um ajuste: gastou %.1f%% e ficou um desvio pequeno. Complicações acontecem mesmo com a decisão certa.")) % (cost + deviation_cost + 1.5)
			if option == 1:
				if favorable:
					ms.sps_fuel -= cost * 1.2
					ms.trajectory_error = 0.0
					return str(TranslationServer.translate("Esperar era arriscado. Por sorte o desvio cresceu pouco e a correção custou %.1f%%. Em geral, corrigir cedo é mais barato.")) % (cost * 1.2)
				ms.sps_fuel -= cost * 2.0
				ms.trajectory_error = 0.0
				return str(TranslationServer.translate("Esperar dobrou o custo (%.1f%%): quanto mais longe, maior o desvio a corrigir.")) % (cost * 2.0)
			if good:
				if favorable:
					return str(TranslationServer.translate("O desvio estava dentro da tolerância: manter o rumo economizou propelente. Boa leitura dos instrumentos."))
				ms.sps_fuel -= 1.0
				ms.trajectory_error = 0.0
				return str(TranslationServer.translate("Manter o rumo era razoável, mas o desvio cresceu e Houston pediu um pequeno ajuste de 1%."))
			if favorable:
				ms.sps_fuel -= cost * 1.5
				ms.trajectory_error = 0.0
				return str(TranslationServer.translate("O desvio era grande demais para ignorar. Houston conseguiu uma correção barata por sorte (%.1f%%).")) % (cost * 1.5)
			ms.sps_fuel -= cost * 3.0
			ms.integrity -= 5.0
			ms.trajectory_error = 0.0
			return str(TranslationServer.translate("O desvio era grande demais. Houston ordenou uma correção de emergência, três vezes mais cara (%.1f%%).")) % (cost * 3.0)
		"return_course":
			var cost := return_cost()
			if option == 0:
				var extra := 1.5 * mini(errors, 6)
				ms.sps_fuel -= cost + extra
				ms.return_error *= minf(errors * 0.25, 1.0)
				var flown := str(TranslationServer.translate("Pilotagem limpa: o motor gastou só os %.1f%% previstos.")) % cost
				if errors > 0:
					flown = str(TranslationServer.translate("A nave saiu da rota %d vez(es): cada desvio pediu um ajuste extra, total de %.1f%%.")) % [errors, cost + extra]
				if favorable:
					return str(TranslationServer.translate("Corrigir a volta era a escolha segura. ")) + flown
				ms.sps_fuel -= 1.0
				return str(TranslationServer.translate("Corrigir a volta era a escolha segura. %s Uma válvula do RCS demorou a fechar e custou mais 1%%.")) % flown
			if good:
				if favorable:
					return str(TranslationServer.translate("O desvio estava dentro do corredor de reentrada: manter o rumo economizou propelente."))
				ms.sps_fuel -= 1.0
				ms.return_error = 0.0
				return str(TranslationServer.translate("Manter o rumo era razoável, mas Houston pediu um pequeno ajuste de 1% antes da reentrada."))
			if favorable:
				ms.sps_fuel -= cost * 1.5
				ms.return_error = 0.0
				return str(TranslationServer.translate("O desvio estava fora do corredor de reentrada. Por sorte, uma correção tardia e barata resolveu (%.1f%%).")) % (cost * 1.5)
			ms.sps_fuel -= cost * 3.0
			ms.integrity -= 5.0
			ms.return_error = 0.0
			return str(TranslationServer.translate("O desvio estava fora do corredor de reentrada. A correção de emergência custou %.1f%% e forçou os sistemas.")) % (cost * 3.0)
		"power":
			var over := ms.power_use() > ms.power_capacity
			if option == 0:
				if favorable:
					ms.science_multiplier -= 0.1
					return str(TranslationServer.translate("Correto. Suporte à vida, comunicação e navegação têm prioridade. Perder um pouco de dados é melhor do que arriscar a nave."))
				ms.science_multiplier -= 0.15
				return str(TranslationServer.translate("Decisão correta, mas o instrumento demorou a reaquecer ao ser religado e perdeu um pouco mais de dados."))
			if option == 1 and good:
				ms.battery_used = true
				if favorable:
					return str(TranslationServer.translate("A bateria auxiliar que você levou absorveu o pico de consumo. Seu planejamento evitou o problema."))
				ms.science_multiplier -= 0.05
				return str(TranslationServer.translate("A bateria auxiliar absorveu o pico, mas houve uma breve queda de tensão que corrompeu alguns dados."))
			if option == 1:
				if favorable:
					ms.science_multiplier -= 0.05
					return str(TranslationServer.translate("Sem energia de reserva, era arriscado manter tudo ligado. Por sorte a tensão se manteve, com perda pequena de dados."))
				ms.integrity -= 15.0
				ms.science_multiplier -= 0.25 if over else 0.15
				return str(TranslationServer.translate("Sem energia de reserva, a subtensão danificou equipamentos e corrompeu dados. Uma bateria auxiliar teria evitado isso."))
			if favorable:
				ms.life_support -= 10.0
				return str(TranslationServer.translate("Errado: suporte à vida nunca é o primeiro sistema a ser cortado. Houston mandou religar a tempo, mas o CO₂ subiu."))
			ms.life_support -= 35.0
			ms.integrity -= 10.0
			return str(TranslationServer.translate("Errado. Sem remoção de CO₂ e controle de pressão, a tripulação correu risco. Suporte à vida nunca é o primeiro sistema a ser cortado."))
		"comm_dropout":
			if option == 0:
				var recovered := errors == 0
				if recovered and favorable:
					return str(TranslationServer.translate("Correto. As antenas omnidirecionais mantiveram a voz enquanto a principal foi realinhada."))
				if recovered:
					ms.sps_fuel -= 1.0
					return str(TranslationServer.translate("Correto, e a antena foi realinhada. Ainda assim, Houston precisou de uma pequena manobra para refinar o apontamento (1%)."))
				if favorable:
					ms.sps_fuel -= 1.0
					return str(TranslationServer.translate("As antenas omnidirecionais mantiveram um canal de emergência e Houston enviou os dados de reentrada pela voz. Custo pequeno de 1%."))
				ms.sps_fuel -= 3.0
				return str(TranslationServer.translate("O canal de emergência funcionou, mas os dados chegaram atrasados e a correção gastou 3% do propelente."))
			if option == 1:
				if favorable:
					return str(TranslationServer.translate("Esperar era arriscado. Por sorte a nave girou e o sinal voltou sozinho. O rádio é essencial antes da reentrada."))
				ms.sps_fuel -= 3.0
				return str(TranslationServer.translate("Sem contato, Houston não pôde enviar dados a tempo. A correção atrasada gastou 3% do propelente."))
			if favorable:
				ms.sps_fuel -= 1.0
				return str(TranslationServer.translate("Desligar o rádio era errado. Houston restabeleceu contato pela rede de solo, mas a manobra custou 1%."))
			ms.sps_fuel -= 3.0
			ms.integrity -= 5.0
			return str(TranslationServer.translate("Errado. É pelo rádio que chegam dados de navegação e alertas. Economizar energia ali não compensa."))
		"water_leak":
			if option == 0:
				var loss := 0.5 if ms.spare_parts else 1.0
				if not favorable:
					loss += 0.5
				var lost := ms.lose("water", loss, str(TranslationServer.translate("Vazamento no reservatório")))
				var text := str(TranslationServer.translate("Correto. Isolar o vazamento limitou a perda a %s cota de água.")) % ms.amount_text(lost)
				if ms.spare_parts:
					text += " O kit de ferramentas acelerou o reparo."
				if not favorable:
					text += str(TranslationServer.translate(" A válvula demorou a vedar e vazou um pouco mais."))
				return text
			if option == 1:
				var lost := ms.lose("water", 0.5 if favorable else 2.0, str(TranslationServer.translate("Vazamento no reservatório")))
				if favorable:
					return str(TranslationServer.translate("Ignorar era arriscado. Por sorte a válvula travou sozinha e só %s cota vazou.")) % ms.amount_text(lost)
				return str(TranslationServer.translate("O vazamento continuou e levou %s cotas de água. Problemas em suprimentos devem ser tratados na hora.")) % ms.amount_text(lost)
			var drained := ms.lose("water", 0.5 if favorable else 1.5, str(TranslationServer.translate("Vazamento no reservatório")))
			return str(TranslationServer.translate("Beber além do necessário não fecha a válvula: a água continuou vazando e %s cota se perdeu. O certo é isolar o vazamento.")) % ms.amount_text(drained)
		"ptc":
			if option == 0:
				if favorable:
					return str(TranslationServer.translate("Correto. As missões Apollo usavam o controle térmico passivo: uma rotação lenta, apelidada de 'churrasco', distribui o calor do Sol."))
				ms.sps_fuel -= 1.0
				return str(TranslationServer.translate("Correto, mas a rotação precisou ser reiniciada uma vez e gastou 1% de propelente."))
			if option == 1:
				if favorable:
					ms.integrity -= 3.0
					return str(TranslationServer.translate("Arriscado: por sorte Houston logo pediu a rotação e o desgaste foi pequeno. Girar lentamente distribui o calor."))
				ms.integrity -= 10.0
				return str(TranslationServer.translate("Um lado superaqueceu e o outro congelou, desgastando equipamentos. Girar lentamente distribui o calor."))
			if favorable:
				ms.sps_fuel -= 1.0
				return str(TranslationServer.translate("Giros rápidos eram desnecessários; por sorte foram poucos e custaram só 1%."))
			ms.sps_fuel -= 3.0
			return str(TranslationServer.translate("Giros rápidos gastaram 3% de propelente sem necessidade. Uma rotação lenta e contínua basta."))
	return ""
