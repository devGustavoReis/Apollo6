extends SceneTree
## Verifica a apresentação 3D da reentrada: modelos do Blender carregados, efeitos ligados
## às fases reais, atitude do jogador refletida na cápsula, pausa e paraquedas nos eventos.
## Uso: godot --headless --path . --script tests/reentry_visual_test.gd

var failures: Array[String] = []


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("FALHA: " + message)


func _initialize() -> void:
	call_deferred("run")


func advance(scene: Node, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		scene.step(1.0 / 60.0)
		scene.visual.update_view(1.0 / 60.0)
		t += 1.0 / 60.0


func run() -> void:
	var scene: Node = load("res://scenes/reentry/reentry.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var v: Node = scene.visual
	check(v != null and v.world != null, "Cena 3D criada atrás do HUD")
	check(scene.get_child(0).name == "ReentryView3D", "Visual 3D é o primeiro filho (fica atrás dos indicadores)")
	check(v.capsule.get_child_count() >= 2, "Módulo de comando e escudo do Blender instanciados")
	check(v.mains.size() == 3 and v.drogues.size() == 2, "Três principais e dois estabilizadores")
	scene.start()
	advance(scene, 1.0)
	check(is_zero_approx(v.heat_level()), "Sem calor na separação")
	check(v.service_module.visible, "Módulo de serviço visível na separação")
	advance(scene, scene.SEPARATION_TIME - 1.0 + scene.ENTRY_TIME * 0.45)
	check(scene.phase == "entry" and v.heat_level() > 0.9, "Calor no pico durante a reentrada")
	check(v.trail.visible and v.envelopes[0].visible, "Rastro e envelope visíveis no pico")
	advance(scene, scene.ENTRY_TIME * 0.6)
	check(scene.phase == "drogue", "Chegou aos estabilizadores")
	check(is_zero_approx(v.heat_level()) and not v.trail.visible, "Calor desliga ao fim da reentrada")
	advance(scene, 0.8)
	check(v.drogues[0].visible and v.drogues[1].visible, "Estabilizadores abertos na fase drogue")
	check(not v.mains[0].visible, "Principais fechados antes do comando")
	# atitude do jogador -> inclinação visual
	scene.attitude = -0.8
	for i in 90:
		v.update_view(1.0 / 60.0)
	var left_x: float = v.capsule.transform.origin.x
	scene.attitude = 0.8
	for i in 90:
		v.update_view(1.0 / 60.0)
	var right_x: float = v.capsule.transform.origin.x
	check(left_x < 0.0 and right_x > 0.0, "Marca à esquerda/direita move a cápsula para o mesmo lado (%.2f / %.2f)" % [left_x, right_x])
	# pausa congela o tempo visual
	scene.set_paused(true)
	var before: float = v.vt
	v._process(0.5)
	check(is_equal_approx(before, v.vt), "Pausa congela a animação")
	scene.set_paused(false)
	while scene.phase != "window":
		advance(scene, 1.0 / 60.0)
	scene.press()
	check(scene.phase == "mains", "Toque na janela abre os principais")
	advance(scene, 1.0)
	check(v.mains[0].visible and v.mains[2].visible, "Principais visíveis após o evento")
	var guard := 0
	while scene.phase != "splash" and guard < 2000:
		advance(scene, 1.0 / 60.0)
		guard += 1
	advance(scene, 0.5)
	check(scene.phase == "splash" and v.foam.visible, "Espuma aparece no contato com a água")
	check(absf(v.earth.position.y + v.EARTH_RADIUS + 0.15) < 0.01, "Mar alinhado ao ponto de contato")
	print("REENTRY VISUAL CHECKS: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
