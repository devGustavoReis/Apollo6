extends RefCounted

const CATALOG := "res://data/localization/%s.json"


static func register() -> void:
	var english := _read("en")
	var portuguese := _read("pt_BR")
	# Godot's default fallback is English. Explicitly retain Portuguese source
	# messages so a missing override does not display the English fallback.
	for source: String in english:
		if not portuguese.has(source):
			portuguese[source] = source
	_add("en", english)
	_add("pt_BR", portuguese)


static func _read(locale: String) -> Dictionary:
	var file := FileAccess.open(CATALOG % locale, FileAccess.READ)
	if file == null:
		push_error("Missing translation catalog: " + locale)
		return {}
	var entries: Variant = JSON.parse_string(file.get_as_text())
	if not entries is Dictionary:
		push_error("Invalid translation catalog: " + locale)
		return {}
	return entries


static func _add(locale: String, entries: Dictionary) -> void:
	var resource := Translation.new()
	resource.set_locale(locale)
	for source: String in entries:
		resource.add_message(source, entries[source])
	TranslationServer.add_translation(resource)
