extends SceneTree
## Verify locale selection and visible UI messages without changing the saved preference.

var missed := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		missed += 1
		push_error(message)


func run() -> void:
	var game := root.get_node("Game")
	var mission := root.get_node("MissionState")
	var houston := root.get_node("Houston")
	check(game.language in ["en", "pt_BR"], "A supported game locale is set on startup")
	for locale in ["en", "pt_BR"]:
		game.language = locale
		TranslationServer.set_locale(locale)
		mission.refresh_catalog_language()
		var english: bool = locale == "en"
		var start: String = TranslationServer.translate("INICIAR MISSÃO")
		check(start == ("START MISSION" if english else "INICIAR MISSÃO"), "Menu has the active language")
		check(mission.items["camera"]["name"] == ("Surface stereo camera" if english else "Câmera estéreo de superfície"), "Equipment is localized")
		check(TranslationServer.translate("Take photo") == ("Take photo" if english else "Tirar foto"), "Surface prompt is localized")
		houston.say_recorded("surface_exterior", "Surface operations", "Operações na superfície")
		check(houston._subtitle.text == ("Surface operations" if english else "Operações na superfície"), "Only the chosen subtitle is rendered")
		check(houston._current["stream"] != null, "Voice asset is available in both interface languages")
		houston.clear()
	game.language = "en"
	TranslationServer.set_locale("en")
	houston.astronaut_say("thomas_hungry", "Estou com fome")
	check(houston._subtitle.text == "I’m hungry." and houston._current["stream"] != null, "The default hunger warning is English and recorded")
	houston.clear()
	print("LOCALIZATION CHECKS: ", missed, " failures")
	quit(0 if missed == 0 else 1)
