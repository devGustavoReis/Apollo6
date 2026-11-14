class_name MissionDecisions
extends RefCounted
## Decisões operacionais e eventos da viagem.
## Cada decisão tem opções com efeito previsível e explicação educativa.
## Os eventos são controlados: nenhuma combinação torna a missão impossível.


static func midcourse_cost() -> float:
	## Percentual de propelente do CSM para corrigir agora.
	return 2.0 + 10.0 * MissionState.trajectory_error


static func get_decision(id: String) -> Dictionary:
	var ms := MissionState
	match id:
		"midcourse":
			var e := ms.trajectory_error
			var cost := midcourse_cost()
			var size := "pequeno" if e < 0.12 else ("moderado" if e < 0.5 else "grande")
			return {
				"title": "CORREÇÃO DE ROTA",
				"body": "O desvio deixado pela injeção translunar é [b]%s[/b] (%.0f%%).\nUm desvio pequeno cresce com a distância percorrida: corrigir cedo exige menos propelente do que corrigir tarde.\n\nPropelente do CSM: %.0f%%" % [size, e * 100.0, ms.sps_fuel],
				"options": [
					"Corrigir agora (gasta %.1f%% do propelente do CSM)" % cost,
					"Esperar e corrigir amanhã (custo estimado: %.1f%%)" % (cost * 2.0),
					"Não corrigir",
				],
			}
		"power":
			var over := ms.power_use() > ms.power_capacity
			var text := ""
			if over:
				text = "Os instrumentos consomem [b]%.0f W[/b], acima dos [b]%.0f W[/b] disponíveis. A tensão do barramento está caindo." % [ms.power_use(), ms.power_capacity]
			else:
				text = "Um aquecedor travou ligado e está consumindo energia extra. A margem elétrica está quase no fim."
			return {
				"title": "ALERTA DE ENERGIA",
				"body": text + "\n\nO que fazer?",
				"options": [
					"Desligar temporariamente um instrumento científico não essencial",
					"Manter todos os equipamentos ligados",
					"Desligar o suporte à vida por algumas horas",
				],
			}
		"comm_dropout":
			return {
				"title": "FALHA DE COMUNICAÇÃO",
				"body": "A antena de alto ganho perdeu o alinhamento com a Terra. Houston recebe só chiado.\n" + ("Você tem o kit de peças e ferramentas." if ms.spare_parts else "Você não trouxe o kit de peças e ferramentas."),
				"options": [
					"Trocar para as antenas omnidirecionais e realinhar a de alto ganho",
					"Esperar o sinal voltar sozinho",
					"Desligar o rádio para economizar energia",
				],
			}
		"water_leak":
			return {
				"title": "VAZAMENTO DE ÁGUA",
				"body": "Uma válvula do reservatório de água está vazando. Reserva atual: [b]%.1f dias[/b], necessários até o fim: [b]%d dias[/b]." % [ms.water_days, ms.days_still_needed() + 1],
				"options": [
					"Fechar a válvula e isolar o reservatório afetado",
					"Ignorar por enquanto e continuar as tarefas",
					"Beber o máximo possível agora para não desperdiçar",
				],
			}
		"ptc":
			return {
				"title": "CONTROLE TÉRMICO",
				"body": "Um lado da nave está recebendo Sol direto há horas e esquentando, enquanto o outro esfria demais.\nHouston pede uma solução.",
				"options": [
					"Iniciar uma rotação lenta e contínua da nave (controle térmico passivo)",
					"Manter a nave parada, apontada para o Sol",
					"Fazer giros rápidos com os propulsores",
				],
			}
	return {}


## Aplica a opção escolhida e devolve {correct, explanation}.
static func apply(id: String, option: int) -> Dictionary:
	var ms := MissionState
	var decision := get_decision(id)
	var correct := false
	var explanation := ""
	match id:
		"midcourse":
			var cost := midcourse_cost()
			var small := ms.trajectory_error < 0.12
			if option == 0:
				ms.sps_fuel -= cost
				correct = true
				explanation = "Correção feita cedo, com o menor custo possível. As missões Apollo planejavam várias janelas de correção durante a viagem."
			elif option == 1:
				ms.sps_fuel -= cost * 2.0
				explanation = "Esperar dobrou o custo: quanto mais longe, maior o desvio a corrigir. Corrigir cedo é mais barato."
			else:
				if small:
					correct = true
					explanation = "O desvio era pequeno e estava dentro da tolerância: não corrigir economizou propelente. Boa leitura dos instrumentos."
				else:
					ms.sps_fuel -= cost * 3.0
					ms.integrity -= 5.0
					explanation = "O desvio era grande demais. Houston precisou ordenar uma correção de emergência, três vezes mais cara."
		"power":
			var over := ms.power_use() > ms.power_capacity
			if option == 0:
				correct = true
				ms.science_multiplier -= 0.1
				explanation = "Correto. Suporte à vida, comunicação e navegação têm prioridade. Perder um pouco de dados é melhor do que arriscar a nave."
			elif option == 1:
				if ms.qty("battery_pack") > 0 and not ms.battery_used:
					ms.battery_used = true
					correct = true
					explanation = "A bateria auxiliar que você levou absorveu o pico de consumo. Seu planejamento evitou o problema."
				else:
					ms.integrity -= 15.0
					ms.science_multiplier -= 0.25 if over else 0.15
					explanation = "Sem energia de reserva, a subtensão danificou equipamentos e corrompeu dados. Uma bateria auxiliar teria evitado isso."
			else:
				ms.life_support -= 35.0
				ms.integrity -= 10.0
				explanation = "Errado. Sem remoção de CO₂ e controle de pressão, a tripulação corre risco. Suporte à vida nunca é o primeiro sistema a ser cortado."
		"comm_dropout":
			if option == 0:
				correct = true
				if not ms.spare_parts:
					ms.sps_fuel -= 1.0
				explanation = "Correto. As antenas omnidirecionais mantêm voz com menos dados enquanto a principal é realinhada." + ("" if ms.spare_parts else " Sem o kit de ferramentas, o reparo demorou e exigiu uma pequena manobra.")
			elif option == 1:
				ms.sps_fuel -= 3.0
				explanation = "Sem contato, Houston não pôde enviar dados de navegação a tempo. A correção atrasada gastou mais propelente."
			else:
				ms.sps_fuel -= 3.0
				ms.integrity -= 5.0
				explanation = "Errado. O rádio é essencial: é por ele que chegam dados de navegação e alertas. Economizar energia ali não compensa."
		"water_leak":
			if option == 0:
				correct = true
				ms.water_days -= 0.5 if ms.spare_parts else 1.0
				explanation = "Correto. Isolar o vazamento limitou a perda." + (" O kit de ferramentas acelerou o reparo." if ms.spare_parts else " Sem o kit de ferramentas, o reparo demorou mais.")
			elif option == 1:
				ms.water_days -= 2.0
				explanation = "O vazamento continuou e levou dois dias de água. Problemas em suprimentos devem ser tratados na hora."
			else:
				ms.water_days -= 1.5
				explanation = "Beber além do necessário não salva a água: ela ainda é consumida. O certo é isolar o vazamento."
		"ptc":
			if option == 0:
				correct = true
				explanation = "Correto. As missões Apollo usavam o controle térmico passivo: uma rotação lenta, apelidada de 'churrasco', distribui o calor do Sol."
			elif option == 1:
				ms.integrity -= 10.0
				explanation = "Um lado superaqueceu e o outro congelou, desgastando equipamentos. Girar lentamente distribui o calor."
			else:
				ms.sps_fuel -= 3.0
				explanation = "Giros rápidos gastaram propelente sem necessidade. Uma rotação lenta e contínua basta."
	ms.clamp_resources()
	var options: Array = decision.get("options", [])
	var choice: String = options[option] if option < options.size() else ""
	ms.record_decision(id, decision.get("title", id), choice, correct, explanation)
	return {"correct": correct, "explanation": explanation}
