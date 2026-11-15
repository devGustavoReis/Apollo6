extends RefCounted

const MODEL := preload("res://assets/models/landing/lunar_module.glb")
const FOIL_SHADER := preload("res://assets/shaders/menu/gold_foil.gdshader")

static func create() -> Node3D:
	var lm: Node3D = MODEL.instantiate()
	var foils := {
		"Gold": _foil(Color(0.86, 0.62, 0.20), 5.0),
		"DarkFoil": _foil(Color(0.55, 0.37, 0.12), 5.0),
		"Strut": _foil(Color(0.80, 0.57, 0.19), 9.0),
	}
	# O Sol do menu é forte: o casco claro é escurecido para não estourar em branco.
	var dimmed := {"Hull": 0.66, "Silver": 0.66, "White": 0.8}
	for node in lm.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		for surface in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(surface)
			if mat == null:
				continue
			if foils.has(mat.resource_name):
				mi.set_surface_override_material(surface, foils[mat.resource_name])
			elif dimmed.has(mat.resource_name) and mat is BaseMaterial3D:
				var copy: BaseMaterial3D = mat.duplicate()
				copy.albedo_color = mat.albedo_color * dimmed[mat.resource_name]
				copy.albedo_color.a = 1.0
				mi.set_surface_override_material(surface, copy)

	return lm

static func _foil(color: Color, cells: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FOIL_SHADER
	mat.set_shader_parameter("base", color)
	mat.set_shader_parameter("cells", cells)
	return mat
