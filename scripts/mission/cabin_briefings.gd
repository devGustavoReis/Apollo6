extends RefCounted

const TEXTOS := {
	"M01": {
		"instrucoes": "A queima do motor e o acoplamento soltaram objetos pela cabine. Em microgravidade nada cai: tudo fica flutuando até bater em alguma coisa.\n\n[b]Objetivo:[/b] prender cada objeto no velcro da mesma cor antes que o tempo acabe.\n[b]Como jogar:[/b] clique no objeto, arraste até o velcro e solte.\n[b]Cuidado:[/b] cada objeto que bate no painel de interruptores conta uma batida.",
		"licao": "Nas naves Apollo, cada item solto tinha um lugar marcado e um jeito de ficar preso sem gravidade: velcro, presilhas, cintas ou elásticos. Um objeto esquecido pode flutuar para trás de um painel ou acionar um interruptor.",
		"fala_en": "Apollo, secure all loose items before the next burn.",
		"fala_pt": "Apollo, prendam todos os objetos soltos antes da próxima queima.",
	},
	"M02": {
		"instrucoes": "A bolsa de bebida precisa ser enchida no dispensador antes de beber. Sem gravidade, a bolsa não fica parada e a água que escapa vira gotas flutuando pela cabine.\n\n[b]Objetivo:[/b] encher a bolsa até a faixa verde.\n[b]Como jogar:[/b] leve o bico até a válvula da bolsa com o mouse ou as SETAS. Segure o clique ou ESPAÇO para encher e solte dentro da faixa verde.\n[b]Cuidado:[/b] encher com o bico fora da válvula desperdiça água, e passar da faixa faz a bolsa vazar.",
		"licao": "Na Apollo, comida e bebida iam desidratadas. Os astronautas encaixavam o bico de um dispensador na válvula de cada embalagem, e cada aperto do gatilho liberava cerca de 15 ml de água quente ou fria. O encaixe justo impedia que a água escapasse para a cabine.",
		"fala_en": "Take it slow on the water gun. Keep the nozzle seated.",
		"fala_pt": "Devagar com o dispensador de água. Mantenham o bico encaixado.",
	},
	"M03": {
		"instrucoes": "A antena de alto ganho perdeu a Terra e Houston só recebe chiado. O feixe dela é estreito: precisa estar apontado quase exatamente para a Terra.\n\n[b]Objetivo:[/b] encontrar a direção do sinal mais forte e manter a antena nela até travar.\n[b]Como jogar:[/b] mova a antena com WASD ou as SETAS, ou segure o clique no visor. O medidor mostra se o sinal está subindo ou caindo.\n[b]Cuidado:[/b] o tempo é curto e, nas dificuldades maiores, a nave continua girando.",
		"licao": "A antena de alto ganho do módulo de serviço Apollo podia ser apontada à mão por dois controles, um de inclinação (pitch) e um de giro (yaw), enquanto a tripulação acompanhava a intensidade do sinal. Na Apollo 11, Houston chegou a pedir o modo manual e passou os ângulos pelo rádio.",
		"fala_en": "Apollo... weak signal... go to manual on the high gain...",
		"fala_pt": "Apollo... sinal fraco... passem a antena de alto ganho para manual...",
	},
	"M04": {
		"instrucoes": "Antes de passar para o módulo lunar, Thomas veste o traje pressurizado e liga as mangueiras de oxigênio. Cada conector só entra quando as travas estão alinhadas com os encaixes.\n\n[b]Objetivo:[/b] encaixar as duas mangueiras: a azul (entrada de oxigênio) e a vermelha (saída de gás).\n[b]Como jogar:[/b] gire o conector com A/D, as SETAS ou a roda do mouse. Com as três travas sobre os encaixes, empurre com ESPAÇO ou clique.\n[b]Cuidado:[/b] o conector flutua e gira sozinho. Empurrar desalinhado conta um erro.",
		"licao": "Os trajes espaciais da época usavam conectores coloridos para ninguém trocar as mangueiras: azul para o gás que entra no traje e vermelho para o que sai. Cada conector tinha uma trava que só fechava com o encaixe completo, porque um engate frouxo significa perder oxigênio.",
		"fala_en": "Suit up and verify your oxygen hoses are locked.",
		"fala_pt": "Vistam os trajes e confirmem as mangueiras de oxigênio travadas.",
	},
	"M05": {
		"instrucoes": "No espaço não anoitece: o Sol entra pelas cinco janelas o tempo todo. Para dormir, a tripulação precisa escurecer a cabine.\n\n[b]Objetivo:[/b] fechar as cortinas das cinco janelas e apagar as três lâmpadas.\n[b]Como jogar:[/b] clique em cada ponto de velcro que brilha em volta das janelas e depois nas lâmpadas.\n[b]Cuidado:[/b] nas dificuldades maiores, uma ponta do velcro pode soltar e deixar a luz entrar de novo.",
		"licao": "O módulo de comando Apollo tinha cinco janelas e cortinas removíveis presas com velcro. Os astronautas dormiam em sacos presos sob os assentos. Na Apollo 11, a luz que vazava em volta das cortinas do módulo lunar foi um dos motivos da noite mal dormida na superfície da Lua.",
		"fala_en": "Time to get some rest. Shades up and lights out.",
		"fala_pt": "Hora de descansar. Cortinas nas janelas e luzes apagadas.",
	},
	"M06": {
		"instrucoes": "A refeição acabou, mas as embalagens vazias não podem ficar soltas: restos de comida estragam e sujam o ar da cabine.\n\n[b]Objetivo:[/b] guardar todas as embalagens na bolsa de lixo.\n[b]Como jogar:[/b] arraste cada embalagem para um espaço livre da bolsa. Dá para tirar uma embalagem já guardada e mudar de lugar.\n[b]Cuidado:[/b] o espaço é contado. Se o tempo acabar com embalagens de fora, a bolsa não fecha.",
		"licao": "Depois de comer, os astronautas da Apollo colocavam uma pastilha germicida dentro de cada embalagem vazia, enrolavam e guardavam no compartimento de lixo. A pastilha impedia que os restos fermentassem e produzissem gás. Em uma cabine pequena e fechada, espaço e ar limpo são recursos da missão.",
		"fala_en": "Stow those empty food bags when you are done.",
		"fala_pt": "Guardem as embalagens vazias quando terminarem.",
	},
}


static func com_licao(id: String, texto: String) -> String:
	return "%s\n\n[color=#f5bd5c]POR QUE ISSO IMPORTA[/color]\n%s" % [texto, TEXTOS[id]["licao"]]
